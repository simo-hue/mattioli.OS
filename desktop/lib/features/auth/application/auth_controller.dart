import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:evolve_desktop/core/desktop_supabase_config.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopAuthState {
  const DesktopAuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final User? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isLoggedIn => user != null;

  DesktopAuthState copyWith({
    User? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DesktopAuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final desktopAuthControllerProvider =
    NotifierProvider<DesktopAuthController, DesktopAuthState>(
      DesktopAuthController.new,
    );

class DesktopAuthController extends Notifier<DesktopAuthState> {
  static const _oauthCallbackTimeout = Duration(minutes: 5);

  @override
  DesktopAuthState build() {
    final client = ref.watch(supabaseClientProvider);
    if (client == null) return const DesktopAuthState();

    final subscription = client.auth.onAuthStateChange.listen((event) {
      state = DesktopAuthState(user: event.session?.user);
      if (event.session?.user != null) {
        unawaited(
          ref.read(desktopConsentControllerProvider.notifier).syncToProfile(),
        );
      }
    });
    ref.onDispose(subscription.cancel);
    return DesktopAuthState(user: client.auth.currentUser);
  }

  Future<void> signIn({required String email, required String password}) async {
    await _execute(() async {
      await _client.auth.signInWithPassword(email: email, password: password);
      await ref.read(desktopConsentControllerProvider.notifier).syncToProfile();
    });
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    var requiresEmailConfirmation = false;
    await _execute(() async {
      final consent = ref.read(desktopConsentControllerProvider);
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (fullName?.trim().isNotEmpty ?? false)
            'full_name': fullName!.trim(),
          'terms_accepted_at': DateTime.now().toIso8601String(),
          'sentry_consent': consent.hasSentryConsent,
        },
      );
      requiresEmailConfirmation = response.session == null;
      if (response.session != null) {
        await ref
            .read(desktopConsentControllerProvider.notifier)
            .syncToProfile();
      }
    });
    return requiresEmailConfirmation;
  }

  Future<void> sendPasswordReset(String email) async {
    await _execute(() => _client.auth.resetPasswordForEmail(email));
  }

  Future<void> signInWithGoogle() async {
    await _signInWithDesktopOAuth(OAuthProvider.google);
  }

  Future<void> signInWithApple() async {
    if (DesktopSupabaseConfig.useNativeAppleSignIn &&
        Platform.isMacOS &&
        await SignInWithApple.isAvailable()) {
      await _signInWithNativeApple();
      return;
    }

    await _signInWithDesktopOAuth(OAuthProvider.apple);
  }

  Future<void> signOut() async {
    final userId = state.user?.id;
    try {
      await _execute(_client.auth.signOut);
    } finally {
      if (userId != null) {
        try {
          await SecureStorageUtils.delete('desktop_dashboard_cache_$userId');
          await SecureStorageUtils.delete('desktop_dashboard_pending_$userId');
        } catch (error, stack) {
          AppLogger.error(
            'Unable to clear the dashboard local data',
            error,
            stack,
          );
        }
      }
    }
  }

  Future<void> updatePersonalInfo({
    required String fullName,
    String? dateOfBirth,
  }) async {
    await _execute(() async {
      final normalizedBirthDate = dateOfBirth?.trim();
      final profile = {
        'full_name': fullName.trim(),
        'date_of_birth': normalizedBirthDate?.isEmpty ?? true
            ? null
            : normalizedBirthDate,
      };
      final response = await _client.auth.updateUser(
        UserAttributes(data: profile),
      );
      final user = response.user;
      if (user == null) {
        throw StateError('The updated Supabase user is missing.');
      }
      await _client.from('profiles').upsert({'id': user.id, ...profile});
      state = state.copyWith(user: user, clearError: true);
    });
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _execute(() async {
      final email = state.user?.email;
      if (email == null) {
        throw StateError('The authenticated user email is missing.');
      }
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    });
  }

  Future<void> deleteAccount() async {
    final userId = state.user?.id;
    if (userId == null) {
      throw StateError('The authenticated user is missing.');
    }
    await _execute(() async {
      await _client.rpc('delete_user_account');
      await _client.auth.signOut();
    });
    await SecureStorageUtils.delete('desktop_dashboard_cache_$userId');
    await SecureStorageUtils.delete('desktop_dashboard_pending_$userId');
  }

  Future<void> clearError() async {
    state = state.copyWith(clearError: true);
  }

  /// Enter Private mode — no Supabase session required.
  Future<void> enterPrivateMode() async {
    // Ensure the encrypted DB actually OPENS before flipping the mode, so a
    // failed open (e.g. the fail-closed key guard firing when the SQLCipher key
    // is missing but the DB file exists) leaves us in Supabase mode with an
    // error instead of stranding the app in Private mode — persisted across
    // restarts — on an empty dashboard. Mirrors mobile's `startPrivateMode`.
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await DesktopPrivateDb.instance.database;
      await ref.read(activeDesktopDataModeProvider.notifier).enterPrivateMode();
      state = state.copyWith(isLoading: false);
    } catch (error, stack) {
      AppLogger.error('[Auth] Private mode startup error', error, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.operationFailed,
      );
    }
  }

  /// Exit Private mode without deleting private data.
  Future<void> goToLogin() async {
    await ref.read(activeDesktopDataModeProvider.notifier).enterSupabaseMode();
  }

  SupabaseClient get _client {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured for this desktop build.');
    }
    return client;
  }

  Future<void> _signInWithNativeApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rawNonce = _client.auth.generateRawNonce();
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
        throw AuthException(t.authCtrl.appleNoToken);
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final fullName =
          '${credential.givenName ?? ''} '
                  '${credential.familyName ?? ''}'
              .trim();
      if (fullName.isNotEmpty) {
        try {
          await _client.auth.updateUser(
            UserAttributes(data: {'full_name': fullName}),
          );
        } catch (error, stack) {
          AppLogger.error(
            'Desktop Apple profile name update failed',
            error,
            stack,
          );
        }
      }

      await ref.read(desktopConsentControllerProvider.notifier).syncToProfile();
      state = state.copyWith(isLoading: false, clearError: true);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false, clearError: true);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.appleAuthFailed,
      );
      rethrow;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (error, stack) {
      AppLogger.error('Desktop Apple auth failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.appleAuthFailed,
      );
      rethrow;
    }
  }

  Future<void> _signInWithDesktopOAuth(OAuthProvider provider) async {
    state = state.copyWith(isLoading: true, clearError: true);
    HttpServer? callbackServer;

    try {
      final redirectUri = _validatedOAuthRedirectUri();
      callbackServer = await HttpServer.bind(
        redirectUri.host,
        redirectUri.port,
        shared: false,
      );

      final callbackFuture = _waitForOAuthCallback(
        callbackServer,
        redirectUri.path,
      );
      final oauthResponse = await _client.auth.getOAuthSignInUrl(
        provider: provider,
        redirectTo: redirectUri.toString(),
      );
      final opened = await launchUrl(
        Uri.parse(oauthResponse.url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw StateError(t.authCtrl.cantOpenBrowser);
      }

      final callbackUri = await callbackFuture.timeout(_oauthCallbackTimeout);
      await _client.auth.getSessionFromUrl(callbackUri);
      await ref.read(desktopConsentControllerProvider.notifier).syncToProfile();
      state = state.copyWith(isLoading: false, clearError: true);
    } on TimeoutException {
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.accessNotCompleted(
          provider: _providerName(provider),
        ),
      );
      rethrow;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (error, stack) {
      AppLogger.error(
        'Desktop ${_providerName(provider)} OAuth failed',
        error,
        stack,
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.providerAuthFailed(
          provider: _providerName(provider),
        ),
      );
      rethrow;
    } finally {
      await callbackServer?.close(force: true);
    }
  }

  Future<Uri> _waitForOAuthCallback(HttpServer server, String expectedPath) {
    final completer = Completer<Uri>();
    late final StreamSubscription<HttpRequest> subscription;

    subscription = server.listen(
      (request) async {
        if (request.uri.path != expectedPath) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        await _writeOAuthCallbackResponse(request);
        if (!completer.isCompleted) {
          completer.complete(request.uri);
        }
        await subscription.cancel();
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      },
    );

    return completer.future.whenComplete(() => subscription.cancel());
  }

  Future<void> _writeOAuthCallbackResponse(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write('''
<!doctype html>
<html lang="it">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Evolve Desktop</title>
    <style>
      body {
        margin: 0;
        min-height: 100vh;
        display: grid;
        place-items: center;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        background: #090a0f;
        color: #fafafa;
      }
      main {
        max-width: 420px;
        padding: 32px;
        text-align: center;
      }
      p { color: #a1a1aa; line-height: 1.5; }
    </style>
  </head>
  <body>
    <main>
      <h1>Accesso completato</h1>
      <p>Puoi chiudere questa finestra e tornare a Evolve Desktop.</p>
    </main>
  </body>
</html>
''');
    await request.response.close();
  }

  Uri _validatedOAuthRedirectUri() {
    final uri = DesktopSupabaseConfig.oauthRedirectUri;
    final isLoopbackHost = uri.host == '127.0.0.1' || uri.host == 'localhost';
    if (uri.scheme != 'http' ||
        !isLoopbackHost ||
        !uri.hasPort ||
        uri.path.isEmpty) {
      throw StateError(
        'EVOLVE_DESKTOP_OAUTH_REDIRECT_URL deve essere un URL loopback '
        'http://127.0.0.1:<porta>/<callback>.',
      );
    }
    return uri;
  }

  String _providerName(OAuthProvider provider) {
    if (provider == OAuthProvider.apple) return 'Apple';
    if (provider == OAuthProvider.google) return 'Google';
    return provider.name;
  }

  Future<void> _execute(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false, clearError: true);
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (error, stack) {
      AppLogger.error('Desktop auth operation failed', error, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: t.authCtrl.operationFailed,
      );
      rethrow;
    }
  }
}
