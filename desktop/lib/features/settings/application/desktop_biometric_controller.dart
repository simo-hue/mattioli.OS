import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/core/app_bootstrap.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/secure_storage_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DesktopBiometricState {
  const DesktopBiometricState({
    required this.enabled,
    required this.unlocked,
    this.isAuthenticating = false,
    this.errorMessage,
  });

  final bool enabled;
  final bool unlocked;
  final bool isAuthenticating;
  final String? errorMessage;

  DesktopBiometricState copyWith({
    bool? enabled,
    bool? unlocked,
    bool? isAuthenticating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DesktopBiometricState(
      enabled: enabled ?? this.enabled,
      unlocked: unlocked ?? this.unlocked,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final desktopBiometricControllerProvider =
    NotifierProvider<DesktopBiometricController, DesktopBiometricState>(
      DesktopBiometricController.new,
    );

class DesktopBiometricController extends Notifier<DesktopBiometricState> {
  static const _preferenceKey = 'pref_biometric_lock';

  final _authentication = LocalAuthentication();

  @override
  DesktopBiometricState build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final enabled =
        preferences?.getBool(_preferenceKey) ??
        preferences?.getBool('biometric_lock') ??
        false;
    unawaited(_loadSecurePreference());
    return DesktopBiometricState(enabled: enabled, unlocked: !enabled);
  }

  bool get isSupportedPlatform => Platform.isMacOS || Platform.isWindows;

  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      final authenticated = await unlock(reason: t.privacy.biometricAuthReason);
      if (!authenticated) return false;
    }

    state = state.copyWith(
      enabled: enabled,
      unlocked: !enabled || state.unlocked,
      clearError: true,
    );
    await _persist(enabled);
    await _syncProfile(enabled);
    return true;
  }

  Future<void> applyProfile(bool enabled) async {
    state = state.copyWith(enabled: enabled, unlocked: !enabled);
    await _persist(enabled);
  }

  Future<bool> unlock({String? reason}) async {
    if (!isSupportedPlatform) {
      state = state.copyWith(errorMessage: t.biometricGate.notSupportedLinux);
      return false;
    }

    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      final supported =
          await _authentication.canCheckBiometrics ||
          await _authentication.isDeviceSupported();
      if (!supported) {
        state = state.copyWith(
          isAuthenticating: false,
          errorMessage: t.biometricGate.noLocalAuth,
        );
        return false;
      }
      final authenticated = await _authentication.authenticate(
        localizedReason: reason ?? t.privacy.biometricUnlockReason,
        biometricOnly: !Platform.isWindows,
        persistAcrossBackgrounding: true,
      );
      state = state.copyWith(
        unlocked: authenticated,
        isAuthenticating: false,
        errorMessage: authenticated ? null : t.biometricGate.authFailed,
        clearError: authenticated,
      );
      return authenticated;
    } catch (error, stack) {
      AppLogger.error('Desktop biometric authentication failed', error, stack);
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: t.biometricGate.authUnavailable,
      );
      return false;
    }
  }

  Future<void> _loadSecurePreference() async {
    try {
      final value = await SecureStorageUtils.read(_preferenceKey);
      if (value == null) return;
      final enabled = value == 'true';
      state = state.copyWith(enabled: enabled, unlocked: !enabled);
    } catch (error, stack) {
      AppLogger.error('Unable to load biometric preference', error, stack);
    }
  }

  Future<void> _persist(bool enabled) async {
    final preferences = ref.read(sharedPreferencesProvider);
    await Future.wait([
      if (preferences != null) preferences.setBool(_preferenceKey, enabled),
      if (preferences != null) preferences.remove('biometric_lock'),
      SecureStorageUtils.write(_preferenceKey, enabled.toString()),
    ]);
  }

  Future<void> _syncProfile(bool enabled) async {
    final client = ref.read(supabaseClientProvider);
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client.from('profiles').upsert({
        'id': user.id,
        'biometric_lock': enabled,
      });
    } catch (error, stack) {
      AppLogger.error('Unable to sync biometric preference', error, stack);
    }
  }
}

class DesktopBiometricGate extends ConsumerWidget {
  const DesktopBiometricGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometric = ref.watch(desktopBiometricControllerProvider);
    if (!biometric.enabled || biometric.unlocked) return child;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.lock, size: 62),
            const SizedBox(height: 18),
            Text(
              t.biometricGate.appLocked,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 7),
            Text(t.biometricGate.unlockPrompt),
            if (biometric.errorMessage != null) ...[
              const SizedBox(height: 9),
              Text(
                biometric.errorMessage!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: biometric.isAuthenticating
                  ? null
                  : () => ref
                        .read(desktopBiometricControllerProvider.notifier)
                        .unlock(),
              icon: const Icon(LucideIcons.fingerprint),
              label: Text(
                biometric.isAuthenticating
                    ? t.biometricGate.verifying
                    : t.biometricGate.unlock,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
