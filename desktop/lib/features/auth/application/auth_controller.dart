import 'dart:async';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> clearError() async {
    state = state.copyWith(clearError: true);
  }

  SupabaseClient get _client {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError('Supabase is not configured for this desktop build.');
    }
    return client;
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
        errorMessage: 'Operazione non riuscita. Riprova tra poco.',
      );
      rethrow;
    }
  }
}
