import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
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

  /// Re-arms the lock (e.g. when the app leaves the foreground) so the next
  /// foreground requires a fresh authentication — the walk-away protection that
  /// is the feature's whole point. Mirrors mobile's re-arm-on-background.
  void rearm() {
    if (state.enabled && state.unlocked) {
      state = state.copyWith(unlocked: false, clearError: true);
    }
  }

  Future<bool> unlock({String? reason}) async {
    if (!isSupportedPlatform) {
      state = state.copyWith(errorMessage: t.biometricGate.notSupportedLinux);
      return false;
    }

    state = state.copyWith(isAuthenticating: true, clearError: true);
    try {
      // Fail OPEN when a biometric-only prompt is required (macOS) but this
      // device has no usable biometrics enrolled — a Mac with no Touch ID
      // (Mac mini/Studio, clamshell, hardware fault) or a biometric_lock synced
      // from the iPhone. Requiring an impossible prompt would lock the user out
      // of their own data with no recourse. Mirrors mobile's gate. (Enrolling
      // Touch ID needs the account password, so this doesn't meaningfully weaken
      // the lock against someone who lacks it.)
      if (!Platform.isWindows) {
        final canCheck = await _authentication.canCheckBiometrics;
        final enrolled =
            canCheck &&
            (await _authentication.getAvailableBiometrics()).isNotEmpty;
        if (!enrolled) {
          state = state.copyWith(
            unlocked: true,
            isAuthenticating: false,
            clearError: true,
          );
          return true;
        }
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

class DesktopBiometricGate extends ConsumerStatefulWidget {
  const DesktopBiometricGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DesktopBiometricGate> createState() =>
      _DesktopBiometricGateState();
}

class _DesktopBiometricGateState extends ConsumerState<DesktopBiometricGate> {
  AppLifecycleListener? _lifecycle;

  /// Guards overlapping prompts — the system sheet itself briefly moves the app
  /// out of `resumed`, which must not spawn a second prompt.
  bool _promptInFlight = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    // Cold start: auto-prompt once the first frame is on screen if locked
    // (mobile prompts immediately; desktop previously required a manual click).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onLifecycle(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      // Left the foreground (hidden/blurred/Mission Control/sleep) → re-arm so
      // returning requires a fresh auth. Mirrors mobile's re-arm-on-paused.
      ref.read(desktopBiometricControllerProvider.notifier).rearm();
    } else if (state == AppLifecycleState.resumed) {
      _maybePrompt();
    }
  }

  Future<void> _maybePrompt() async {
    if (!mounted || _promptInFlight) return;
    final biometric = ref.read(desktopBiometricControllerProvider);
    if (!biometric.enabled || biometric.unlocked) return;
    _promptInFlight = true;
    try {
      await ref.read(desktopBiometricControllerProvider.notifier).unlock();
    } finally {
      _promptInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometric = ref.watch(desktopBiometricControllerProvider);

    // React to the lock arming while already foregrounded — the user toggling
    // it on, or the enabled flag resolving `true` after the async secure-prefs
    // load (private mode). Prompt immediately, matching mobile.
    ref.listen<DesktopBiometricState>(desktopBiometricControllerProvider, (
      prev,
      next,
    ) {
      final nowLocked = next.enabled && !next.unlocked;
      final wasLocked = (prev?.enabled ?? false) && !(prev?.unlocked ?? true);
      if (nowLocked && !wasLocked && !next.isAuthenticating) {
        unawaited(_maybePrompt());
      }
    });

    if (!biometric.enabled || biometric.unlocked) return widget.child;

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
                style: const TextStyle(color: EvolveColors.destructive),
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
