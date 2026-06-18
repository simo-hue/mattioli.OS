import 'package:flutter_test/flutter_test.dart';
import 'package:mattioli_os/core/data_mode.dart';
import 'package:mattioli_os/providers/auth_provider.dart';
import 'package:mattioli_os/providers/user_provider.dart';

void main() {
  group('UserProfile.requiresNameSetup', () {
    test('requires setup when no name is available', () {
      const profile = UserProfile.empty();

      expect(profile.requiresNameSetup(isPrivateMode: true), isTrue);
      expect(profile.requiresNameSetup(isPrivateMode: false), isTrue);
    });

    test('treats the private-mode placeholder as incomplete setup', () {
      const profile = UserProfile(firstName: 'Private', lastName: 'User');

      expect(profile.requiresNameSetup(isPrivateMode: true), isTrue);
      expect(profile.requiresNameSetup(isPrivateMode: false), isFalse);
    });

    test('accepts a real private-mode name', () {
      const profile = UserProfile(firstName: 'Simo', lastName: 'Mattioli');

      expect(profile.requiresNameSetup(isPrivateMode: true), isFalse);
    });
  });

  group('shouldPromptForStartupName', () {
    test('does not prompt before the user has access to the app', () {
      expect(
        shouldPromptForStartupName(
          authState: const AuthState(isLoggedIn: false),
          userProfile: const UserProfile.empty(),
        ),
        isFalse,
      );
    });

    test('does not prompt in Supabase mode even when the profile is empty', () {
      expect(
        shouldPromptForStartupName(
          authState: const AuthState(isLoggedIn: true),
          userProfile: const UserProfile.empty(),
        ),
        isFalse,
      );
    });

    test('prompts only for incomplete Private mode profile setup', () {
      expect(
        shouldPromptForStartupName(
          authState: const AuthState(
            isLoggedIn: false,
            dataMode: AppDataMode.private,
          ),
          userProfile: const UserProfile.empty(),
        ),
        isTrue,
      );

      expect(
        shouldPromptForStartupName(
          authState: const AuthState(
            isLoggedIn: false,
            dataMode: AppDataMode.private,
          ),
          userProfile: const UserProfile(firstName: 'Simo'),
        ),
        isFalse,
      );
    });
  });
}
