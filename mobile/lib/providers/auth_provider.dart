import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'consent_provider.dart';
import 'package:google_sign_in/google_sign_in.dart' as google_auth;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import '../core/supabase_config.dart';
import '../core/app_logger.dart';
import '../core/data_mode.dart';
import '../core/secure_local_storage.dart';
import '../i18n/translations.g.dart';

// Accesso globale al client Supabase. Keep this as a getter so Private-mode
// cold starts can skip Supabase.initialize until the user explicitly returns
// to the account/login path.
SupabaseClient get supabase => Supabase.instance.client;

/// Whether `Supabase.initialize` has already run in this isolate.
///
/// `Supabase.instance.isInitialized` exists but is unreachable for this
/// question: the `Supabase.instance` getter asserts initialisation before you
/// can read the flag off it. So the probe has to be a try/catch. Reading it is not the
/// same question as "is the user signed in": before consent there may be a
/// perfectly good session sitting in the Keychain that we have deliberately not
/// picked up yet.
bool get isSupabaseInitialized {
  try {
    Supabase.instance.client;
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> ensureSupabaseInitialized() async {
  if (isSupabaseInitialized) return;
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: FlutterAuthClientOptions(localStorage: SecureLocalStorage()),
  );
}

/// Whether a cold start may initialise Supabase before the app has a UI.
///
/// Gated on the consent question having been ANSWERED, not on the answer —
/// exactly like [SentryService.shouldRun], and for the same reason.
///
/// The failure this closes is a REINSTALL. iOS Keychain items survive app
/// deletion; `NSUserDefaults` does not. So a user who deletes the app and
/// installs it again arrives with `has_completed_consent` gone (the router
/// correctly sends them to `/consent`) but their Supabase session still on the
/// device — and `Supabase.initialize` would restore it and refresh the token
/// over the network before they had answered anything. A third-party request
/// carrying a user's credentials, made on a screen that exists to ask whether
/// that is allowed.
///
/// Deferring costs nothing: `ensureSupabaseInitialized` already exists and every
/// auth entry point calls it, so the SDK comes up on the first action that
/// genuinely needs it — and [AuthNotifier.adoptSessionAfterConsent] brings the
/// session in the moment consent is given.
bool shouldInitialiseSupabaseAtStartup({
  required bool hasCompletedConsent,
  required bool isPrivateMode,
}) =>
    !isPrivateMode && hasCompletedConsent;

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final User? user; // oggetto utente Supabase completo
  final AppDataMode dataMode;
  final bool isLoading;
  final String? error;

  const AuthState({
    required this.isLoggedIn,
    this.user,
    this.dataMode = AppDataMode.supabase,
    this.isLoading = false,
    this.error,
  });

  bool get isPrivateMode => dataMode == AppDataMode.private;
  bool get canAccessApp => isLoggedIn || isPrivateMode;
  String? get email => user?.email;
  String? get userId => user?.id;

  AuthState copyWith({
    bool? isLoggedIn,
    User? user,
    bool clearUser = false,
    AppDataMode? dataMode,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: clearUser ? null : (user ?? this.user),
      dataMode: dataMode ?? this.dataMode,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
// Implementa ChangeNotifier per essere usato come refreshListenable
// da GoRouter → la navigazione reagisce istantaneamente ai cambi di sessione.

class AuthNotifier extends Notifier<AuthState> with ChangeNotifier {
  StreamSubscription<dynamic>? _authSubscription;

  @override
  AuthState build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _authSubscription?.cancel();
      _authSubscription = null;
      return const AuthState(isLoggedIn: false, dataMode: AppDataMode.private);
    }

    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    // Account mode, but the SDK is not up: a PRE-CONSENT cold start, where
    // `main()` deliberately skipped `Supabase.initialize` so a reinstall cannot
    // reach the network before the user has answered
    // (`shouldInitialiseSupabaseAtStartup`). Touching `supabase` here would
    // throw, and the honest state is "not signed in" — there may well be a
    // session in the Keychain, but we have not looked, and must not until the
    // consent screen says we may. [adoptSessionAfterConsent] is what looks.
    if (!isSupabaseInitialized) {
      _authSubscription?.cancel();
      _authSubscription = null;
      return AuthState(isLoggedIn: false, dataMode: dataMode);
    }

    // Legge la sessione corrente (già in memoria grazie a Supabase.initialize)
    final session = supabase.auth.currentSession;
    final initialState = AuthState(
      isLoggedIn: dataMode == AppDataMode.supabase && session != null,
      user: dataMode == AppDataMode.supabase ? session?.user : null,
      dataMode: dataMode,
    );

    _subscribeToAuthChanges();

    return initialState;
  }

  /// Ascolta i cambi di sessione in real-time (login/logout/token refresh).
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthStreamError,
    );
  }

  /// Brings up Supabase and adopts whatever session the device already holds,
  /// once the user has answered the consent screen.
  ///
  /// The counterpart to the `!isSupabaseInitialized` branch in [build]. Called
  /// by the consent screen rather than by a provider invalidation on purpose:
  /// `routerProvider` watches this notifier, so invalidating the provider would
  /// tear down and rebuild the GoRouter — and with it the whole Navigator —
  /// underneath the screen that is mid-transition. Mutating state in place lets
  /// the existing router redirect normally, and `goalsProvider`'s auth listener
  /// picks the session up from there.
  Future<void> adoptSessionAfterConsent() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
    if (isSupabaseInitialized && _authSubscription != null) return;
    try {
      // NOT `_ensureAuthReady` — that subscribes, and the mode has to be
      // re-checked first (below). Subscribing before the check is precisely the
      // "cloud auth subscription in Private mode" this method guards against.
      await ensureSupabaseInitialized();
    } catch (e, stack) {
      // Nothing to adopt and nothing to break: the user continues signed out,
      // and every auth entry point goes through `_ensureAuthReady`, which brings
      // the SDK up AND subscribes.
      AppLogger.error('[Auth] Post-consent Supabase init failed', e, stack);
      return;
    }
    // RE-CHECK the mode. `ensureSupabaseInitialized` awaits a Keychain read and
    // a possible token refresh, and the user is on a live screen throughout —
    // they can reach the chooser and pick "continue without an account" inside
    // that window. Writing `dataMode: supabase` over a private state would then
    // hand a Private-mode user a cloud auth subscription AND fire
    // `settingsProvider`'s auth listener, which reads `profiles` and configures
    // RevenueCat with the Supabase uid. `_handleAuthStateChange` already guards
    // this way; this path is the one that did not.
    final mode = ref.read(activeDataModeProvider);
    if (mode == AppDataMode.private) {
      AppLogger.info(
        '[Auth] Session adoption abandoned — Private mode was chosen while '
        'Supabase was starting',
      );
      return;
    }
    _subscribeToAuthChanges();
    final session = supabase.auth.currentSession;
    state = AuthState(
      isLoggedIn: session != null,
      user: session?.user,
      dataMode: mode,
    );
    notifyListeners();
  }

  /// Brings the SDK up AND makes sure this notifier is listening to it.
  ///
  /// The subscription half matters because `build()` no longer always creates
  /// one: a pre-consent cold start returns early with `_authSubscription` null,
  /// and nothing re-runs `build()` afterwards. Without this, a sign-in would
  /// succeed on the server while `onAuthStateChange` — the only thing that sets
  /// `isLoggedIn` on that path — had nobody listening, leaving the user staring
  /// at the login screen after a successful login.
  Future<void> _ensureAuthReady() async {
    await ensureSupabaseInitialized();
    if (_authSubscription == null) _subscribeToAuthChanges();
  }

  void _handleAuthStateChange(dynamic data) {
    final event = data.event;
    final session = data.session;
    final dataMode = ref.read(activeDataModeProvider);

    debugPrint('[Auth] Event: $event');

    if (dataMode == AppDataMode.private) {
      state = const AuthState(isLoggedIn: false, dataMode: AppDataMode.private);
      notifyListeners();
      return;
    }

    final isLoggedIn =
        session != null &&
        (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated);

    final isLoggedOut = event == AuthChangeEvent.signedOut;

    if (isLoggedIn) {
      state = AuthState(
        isLoggedIn: true,
        user: session.user,
        dataMode: AppDataMode.supabase,
      );
      notifyListeners(); // aggiorna GoRouter
    } else if (isLoggedOut) {
      state = const AuthState(
        isLoggedIn: false,
        dataMode: AppDataMode.supabase,
      );
      notifyListeners();
    }
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    AppLogger.warning('[Auth] Auth state stream error', error, stackTrace);

    if (_isInvalidPersistedSession(error)) {
      state = state.copyWith(isLoggedIn: false, clearUser: true);
      notifyListeners();

      unawaited(
        supabase.auth.signOut().catchError((signOutError, signOutStack) {
          AppLogger.warning(
            '[Auth] Local sign-out after invalid persisted session failed',
            signOutError,
            signOutStack is StackTrace ? signOutStack : null,
          );
        }),
      );
    }
  }

  bool _isInvalidPersistedSession(Object error) {
    if (error is! AuthException) return false;

    final message = error.message.toLowerCase();
    final code = error is AuthApiException ? error.code?.toLowerCase() : null;

    return code == 'refresh_token_not_found' ||
        message.contains('invalid refresh token') ||
        message.contains('refresh token not found') ||
        message.contains('session expired') ||
        message.contains('current session is missing data');
  }

  // ── Email + Password Login ────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        state = state.copyWith(
          isLoading: false,
          error: t.auth.errors.accessFailed,
        );
        return false;
      }
      await ref.read(activeDataModeProvider.notifier).enterSupabaseMode();
      // onAuthStateChange gestirà il cambio di state
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Auth] Login network error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.network,
      );
      return false;
    }
  }

  // ── Email + Password Sign Up ──────────────────────────────────────────────

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      final consentState = ref.read(consentProvider);

      final response = await supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'terms_accepted_at': DateTime.now().toIso8601String(),
          'sentry_consent': consentState.hasSentryConsent,
        },
      );
      state = state.copyWith(isLoading: false, clearError: true);
      if (response.session != null) {
        await ref.read(activeDataModeProvider.notifier).enterSupabaseMode();
      }

      // Se Supabase ha la email confirmation abilitata, la sessione è null
      // e l'utente riceve un'email. Restituiamo true comunque.
      if (response.user == null) {
        state = state.copyWith(
          error: t.auth.errors.confirmRegistration,
        );
      }
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Auth] Sign up network error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.network,
      );
      return false;
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      await supabase.auth.resetPasswordForEmail(email.trim());
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Auth] Reset password network error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.network,
      );
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _ensureAuthReady();
      await supabase.auth.signOut();
      // onAuthStateChange emette signedOut → state si aggiorna automaticamente
    } catch (e, stack) {
      AppLogger.error('[Auth] Logout error', e, stack);
      // Forziamo il logout locale anche in caso di errore di rete
      state = const AuthState(isLoggedIn: false);
      notifyListeners();
    }
  }

  Future<void> startPrivateMode() async {
    AppLogger.setExternalReportingDisabled(true);
    // Flip to Private mode; AuthNotifier.build() rebuilds to a private AuthState
    // (canAccessApp ⇒ routes to '/'), where PrivateModeGate opens the encrypted
    // DB and runs the locked-DB recovery flow — auto re-pull from iCloud when
    // safe, else an explicit recovery choice — instead of dead-ending here on a
    // missing SQLCipher key. Mirrors desktop's `enterPrivateMode`.
    await ref.read(activeDataModeProvider.notifier).enterPrivateMode();
    state = const AuthState(isLoggedIn: false, dataMode: AppDataMode.private);
    notifyListeners();
  }

  Future<void> returnToLoginFromPrivateMode() async {
    await _ensureAuthReady();

    try {
      // Force sign-out so the user actually lands on the login screen,
      // as requested by the "Go to login" action, instead of being
      // auto-redirected to the dashboard if a cached session exists.
      await supabase.auth.signOut();
    } catch (e, stack) {
      AppLogger.warning(
        '[Auth] Error signing out when returning from private mode',
        e,
        stack,
      );
    }

    await ref.read(activeDataModeProvider.notifier).enterSupabaseMode();
    state = const AuthState(
      isLoggedIn: false,
      user: null,
      dataMode: AppDataMode.supabase,
    );
    notifyListeners();
  }

  // ── Native Google Sign In ────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      final googleSignIn = google_auth.GoogleSignIn(
        clientId: SupabaseConfig.googleIosClientId,
        serverClientId: SupabaseConfig.googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false; // L'utente ha annullato
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null || accessToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: t.auth.errors.googleToken,
        );
        return false;
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      await ref.read(activeDataModeProvider.notifier).enterSupabaseMode();
      // onAuthStateChange gestirà il nuovo state
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Google Auth] Error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.googleAuth,
      );
      return false;
    }
  }

  // ── Native Apple Sign In ──────────────────────────────────────────────────

  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      final rawNonce = supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: t.auth.errors.appleToken,
        );
        return false;
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      await ref.read(activeDataModeProvider.notifier).enterSupabaseMode();
      // If Apple returned a full name, save it to user metadata immediately!
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      if (givenName != null || familyName != null) {
        final fullName = '${givenName ?? ''} ${familyName ?? ''}'.trim();
        if (fullName.isNotEmpty) {
          try {
            await supabase.auth.updateUser(
              UserAttributes(data: {'full_name': fullName}),
            );
          } catch (e, stack) {
            AppLogger.error(
              '[Apple Auth] Error updating profile name',
              e,
              stack,
            );
          }
        }
      }

      // onAuthStateChange gestirà il nuovo state
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false, clearError: true);
        return false;
      }
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.appleAuth,
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Apple Auth] Error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.appleAuth,
      );
      return false;
    }
  }

  // ── Update Profile Name ──────────────────────────────────────────────────

  Future<bool> updateProfileName(String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      final response = await supabase.auth.updateUser(
        UserAttributes(data: {'full_name': fullName.trim()}),
      );
      if (response.user != null) {
        state = state.copyWith(
          isLoading: false,
          user: response.user,
          clearError: true,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.updateProfileFailed,
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Auth] Update profile name network error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.network,
      );
      return false;
    }
  }

  // ── Update Consent in DB ──────────────────────────────────────────────────

  Future<bool> updateConsentInDb(bool acceptedTerms, bool sentryConsent) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ensureAuthReady();
      await supabase
          .from('profiles')
          .update({
            'terms_accepted_at': acceptedTerms
                ? DateTime.now().toIso8601String()
                : null,
            'sentry_consent': sentryConsent,
          })
          .eq('id', state.userId!);

      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } catch (e, stack) {
      AppLogger.error('[Auth] Update consent in DB error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: t.auth.errors.network,
      );
      return false;
    }
  }

  // ── Helper: error message localization ───────────────────────────────────

  String _mapAuthError(String supabaseMessage) {
    final msg = supabaseMessage.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return t.auth.errors.invalidCredentials;
    }
    if (msg.contains('email not confirmed')) {
      return t.auth.errors.emailNotConfirmed;
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return t.auth.errors.accountExists;
    }
    if (msg.contains('password should be at least')) {
      return t.auth.errors.passwordMinSix;
    }
    if (msg.contains('rate limit')) {
      return t.auth.errors.rateLimited;
    }
    if (msg.contains('signups not allowed for this instance')) {
      return t.auth.errors.signupsDisabled;
    }
    return t.auth.errors.generic(message: supabaseMessage);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
