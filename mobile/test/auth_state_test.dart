import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Pure gating logic on [AuthState]. No Supabase client, no Riverpod — just the
/// plain data class: its constructor, computed getters and copyWith semantics.
/// [User] is gotrue's data class with a const constructor, so it can be built
/// without initializing Supabase.
void main() {
  const sampleUser = User(
    id: 'user-123',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    email: 'simo@example.com',
    createdAt: '2026-06-23T00:00:00.000Z',
  );

  group('AuthState gating', () {
    test('Private mode grants access even when logged out', () {
      const state = AuthState(
        isLoggedIn: false,
        dataMode: AppDataMode.private,
      );

      expect(state.canAccessApp, isTrue);
      expect(state.isPrivateMode, isTrue);
    });

    test('Supabase mode grants access when logged in', () {
      const state = AuthState(
        isLoggedIn: true,
        dataMode: AppDataMode.supabase,
      );

      expect(state.canAccessApp, isTrue);
      expect(state.isPrivateMode, isFalse);
    });

    test('Supabase mode denies access when logged out', () {
      const state = AuthState(
        isLoggedIn: false,
        dataMode: AppDataMode.supabase,
      );

      expect(state.canAccessApp, isFalse);
      expect(state.isPrivateMode, isFalse);
    });

    test('dataMode defaults to Supabase', () {
      const state = AuthState(isLoggedIn: false);

      expect(state.dataMode, AppDataMode.supabase);
      expect(state.isPrivateMode, isFalse);
    });

    test('email and userId read through to the attached user', () {
      const state = AuthState(isLoggedIn: true, user: sampleUser);

      expect(state.email, 'simo@example.com');
      expect(state.userId, 'user-123');
    });

    test('email and userId are null without a user', () {
      const state = AuthState(isLoggedIn: false);

      expect(state.email, isNull);
      expect(state.userId, isNull);
    });
  });

  group('AuthState.copyWith', () {
    test('overrides dataMode and isLoggedIn when provided', () {
      const base = AuthState(isLoggedIn: false);

      final updated = base.copyWith(
        isLoggedIn: true,
        dataMode: AppDataMode.private,
      );

      expect(updated.isLoggedIn, isTrue);
      expect(updated.dataMode, AppDataMode.private);
    });

    test('preserves dataMode and isLoggedIn when omitted', () {
      const base = AuthState(
        isLoggedIn: true,
        dataMode: AppDataMode.private,
      );

      final updated = base.copyWith(isLoading: true);

      expect(updated.isLoggedIn, isTrue);
      expect(updated.dataMode, AppDataMode.private);
      expect(updated.isLoading, isTrue);
    });

    test('clearUser drops the attached user; otherwise it is preserved', () {
      const base = AuthState(isLoggedIn: true, user: sampleUser);

      // Unrelated copyWith keeps the user...
      expect(base.copyWith(isLoading: true).user, isNotNull);
      // ...clearUser removes it...
      expect(base.copyWith(clearUser: true).user, isNull);
      // ...and clearUser wins even if a replacement user is also supplied.
      expect(base.copyWith(clearUser: true, user: sampleUser).user, isNull);
    });

    test('clearError wipes the error message', () {
      const base = AuthState(isLoggedIn: true, error: 'boom');

      // A plain copyWith preserves the existing error...
      expect(base.copyWith().error, 'boom');
      // ...while clearError drops it.
      expect(base.copyWith(clearError: true).error, isNull);
    });

    test('error preserved across an unrelated copyWith', () {
      const base = AuthState(isLoggedIn: true, error: 'boom');

      final updated = base.copyWith(isLoading: true);

      expect(updated.error, 'boom');
    });
  });
}
