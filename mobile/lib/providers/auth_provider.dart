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

// Accesso globale al client Supabase
final supabase = Supabase.instance.client;

// ── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final User? user; // oggetto utente Supabase completo
  final bool isLoading;
  final String? error;

  const AuthState({
    required this.isLoggedIn,
    this.user,
    this.isLoading = false,
    this.error,
  });

  String? get email => user?.email;
  String? get userId => user?.id;

  AuthState copyWith({
    bool? isLoggedIn,
    User? user,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: clearUser ? null : (user ?? this.user),
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
    // Legge la sessione corrente (già in memoria grazie a Supabase.initialize)
    final session = supabase.auth.currentSession;
    final initialState = AuthState(
      isLoggedIn: session != null,
      user: session?.user,
    );

    // Ascolta i cambi di sessione in real-time (login/logout/token refresh)
    _authSubscription?.cancel();
    _authSubscription = supabase.auth.onAuthStateChange.listen(
      _handleAuthStateChange,
      onError: _handleAuthStreamError,
    );
    ref.onDispose(() {
      _authSubscription?.cancel();
      _authSubscription = null;
    });

    return initialState;
  }

  void _handleAuthStateChange(dynamic data) {
    final event = data.event;
    final session = data.session;

    debugPrint('[Auth] Event: $event');

    final isLoggedIn =
        session != null &&
        (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated);

    final isLoggedOut = event == AuthChangeEvent.signedOut;

    if (isLoggedIn) {
      state = AuthState(isLoggedIn: true, user: session.user);
      notifyListeners(); // aggiorna GoRouter
    } else if (isLoggedOut) {
      state = const AuthState(isLoggedIn: false);
      notifyListeners();
    }
  }

  void _handleAuthStreamError(Object error, StackTrace stackTrace) {
    AppLogger.warning('[Auth] Auth state stream error', error, stackTrace);

    if (_isInvalidPersistedSession(error)) {
      state = const AuthState(isLoggedIn: false);
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
      final response = await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Accesso non riuscito. Controlla email e password.',
        );
        return false;
      }
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
        error: 'Errore di rete. Riprova.',
      );
      return false;
    }
  }

  // ── Email + Password Sign Up ──────────────────────────────────────────────

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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

      // Se Supabase ha la email confirmation abilitata, la sessione è null
      // e l'utente riceve un'email. Restituiamo true comunque.
      if (response.user == null) {
        state = state.copyWith(
          error: 'Controlla la tua email per confermare la registrazione.',
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
        error: 'Errore di rete. Riprova.',
      );
      return false;
    }
  }

  // ── Password Reset ────────────────────────────────────────────────────────

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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
        error: 'Errore di rete. Riprova.',
      );
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await supabase.auth.signOut();
      // onAuthStateChange emette signedOut → state si aggiorna automaticamente
    } catch (e, stack) {
      AppLogger.error('[Auth] Logout error', e, stack);
      // Forziamo il logout locale anche in caso di errore di rete
      state = const AuthState(isLoggedIn: false);
      notifyListeners();
    }
  }

  // ── Native Google Sign In ────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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
          error: 'Errore nel recupero dei token di Google.',
        );
        return false;
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

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
        error: 'Errore di autenticazione con Google.',
      );
      return false;
    }
  }

  // ── Native Apple Sign In ──────────────────────────────────────────────────

  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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
          error: 'Errore nel recupero del token di Apple.',
        );
        return false;
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

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
        error: 'Errore di autenticazione con Apple.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Apple Auth] Error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Errore di autenticazione con Apple.',
      );
      return false;
    }
  }

  // ── Update Profile Name ──────────────────────────────────────────────────

  Future<bool> updateProfileName(String fullName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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
        error: 'Impossibile aggiornare il profilo.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _mapAuthError(e.message));
      return false;
    } catch (e, stack) {
      AppLogger.error('[Auth] Update profile name network error', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Errore di rete. Riprova.',
      );
      return false;
    }
  }

  // ── Update Consent in DB ──────────────────────────────────────────────────

  Future<bool> updateConsentInDb(bool acceptedTerms, bool sentryConsent) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
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
        error: 'Errore di rete. Riprova.',
      );
      return false;
    }
  }

  // ── Helper: error message localization ───────────────────────────────────

  String _mapAuthError(String supabaseMessage) {
    final msg = supabaseMessage.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials')) {
      return 'Email o password errata.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Controlla la tua email e clicca il link di conferma.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'Esiste già un account con questa email. Prova ad accedere.';
    }
    if (msg.contains('password should be at least')) {
      return 'La password deve essere di almeno 6 caratteri.';
    }
    if (msg.contains('rate limit')) {
      return 'Troppi tentativi. Attendi qualche minuto e riprova.';
    }
    if (msg.contains('signups not allowed for this instance')) {
      return 'Le registrazioni sono disabilitate per questa istanza. Abilita "Enable Signups" nella dashboard di Supabase.';
    }
    return 'Si è verificato un errore: $supabaseMessage';
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
