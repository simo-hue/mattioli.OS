import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../kit/evolve_button.dart';
import '../../i18n/translations.g.dart';

/// Whether the user has satisfied the biometric lock for the *current
/// foreground session*. Owned by [BiometricLockGate], which resets it whenever
/// the app is backgrounded and sets it after a successful prompt. Other flows
/// may set it to `true` when they have just performed an equivalent
/// authentication (e.g. enabling the lock from Privacy settings, which already
/// requires Face ID) so the gate does not immediately prompt again.
class BiometricUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final biometricUnlockedProvider =
    NotifierProvider<BiometricUnlockedNotifier, bool>(
      BiometricUnlockedNotifier.new,
    );

/// Whether the biometric lock is enabled *and* the user is inside the app
/// (past login/consent). Login and consent screens are never gated.
final biometricLockEnabledForUserProvider = Provider<bool>((ref) {
  final enabled = ref.watch(settingsProvider.select((s) => s.biometricLock));
  final canAccess = ref.watch(authProvider.select((s) => s.canAccessApp));
  return enabled && canAccess;
});

/// `true` while the app must be covered by the biometric lock — i.e. the lock
/// is enabled, the user can access the app, and they have not yet authenticated
/// this foreground session. Screens can watch this to defer work that must not
/// run behind the lock (e.g. the onboarding/tutorial overlays in `HomeScreen`).
final biometricLockActiveProvider = Provider<bool>((ref) {
  final enabledForUser = ref.watch(biometricLockEnabledForUserProvider);
  final unlocked = ref.watch(biometricUnlockedProvider);
  return enabledForUser && !unlocked;
});

/// App-wide biometric (Face ID / Touch ID) lock.
///
/// Installed in `MaterialApp.router`'s `builder`, so it wraps every route. When
/// [AppSettings.biometricLock] is enabled it covers the app with an opaque lock
/// screen and requires a successful biometric authentication before revealing
/// the content. The lock re-arms whenever the app is backgrounded, so returning
/// to the foreground prompts again, and it covers the content while the app is
/// not in the foreground so the app-switcher snapshot never leaks data.
///
/// The covered app stays mounted beneath the overlay, so navigation and screen
/// state survive a lock/unlock cycle.
class BiometricLockGate extends ConsumerStatefulWidget {
  const BiometricLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends ConsumerState<BiometricLockGate>
    with WidgetsBindingObserver {
  /// Guards against overlapping [authenticate] calls — the system prompt itself
  /// briefly moves the app to `inactive`, which must not spawn a second prompt.
  bool _authInProgress = false;

  /// Last observed lifecycle state; drives the app-switcher privacy cover.
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start: if the lock is already enabled the overlay renders on the
    // first frame (the unlock flag defaults to false ⇒ fail-closed). Prompt
    // once that frame is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(biometricLockActiveProvider)) {
        _authenticate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setUnlocked(bool value) {
    ref.read(biometricUnlockedProvider.notifier).set(value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _lifecycle == AppLifecycleState.resumed;
    _lifecycle = state;

    if (state == AppLifecycleState.paused) {
      // Backgrounded: re-arm the lock so returning requires a fresh auth.
      if (ref.read(biometricLockEnabledForUserProvider)) {
        _setUnlocked(false);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Returned to the foreground while locked ⇒ prompt again.
      if (ref.read(biometricLockActiveProvider)) {
        _authenticate();
      }
    }

    // Keep the privacy cover in sync with the (local) lifecycle state.
    if (mounted && (wasResumed || state == AppLifecycleState.resumed)) {
      setState(() {});
    }
  }

  Future<void> _authenticate() async {
    if (_authInProgress) return;
    if (mounted) {
      setState(() => _authInProgress = true);
    } else {
      _authInProgress = true;
    }

    final auth = LocalAuthentication();
    final reason = context.t.privacy.biometricUnlockReason;
    try {
      final canCheck = await auth.canCheckBiometrics;
      final enrolled =
          canCheck && (await auth.getAvailableBiometrics()).isNotEmpty;

      // No usable biometrics on this device (not enrolled / hardware absent).
      // A biometric-only prompt could never succeed, so requiring it would lock
      // the user out of their own data with no recourse — treat as unlocked.
      // (Changing enrollment requires the device passcode, so this does not
      // meaningfully weaken the lock against someone who lacks the passcode.)
      if (!enrolled) {
        if (mounted) _setUnlocked(true);
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate && mounted) {
        _setUnlocked(true);
      }
      // On failure/cancel we deliberately stay locked (fail-closed); the lock
      // screen keeps its Retry button.
    } catch (e, stack) {
      // Errors (lockout, user cancel, plugin missing) leave the app locked so
      // the user can retry. We never fail open on an *error* — only on a
      // genuine absence of enrolled biometrics (handled above).
      AppLogger.error('[BiometricLock] authentication error', e, stack);
    } finally {
      if (mounted) {
        setState(() => _authInProgress = false);
      } else {
        _authInProgress = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(biometricLockActiveProvider);
    final enabledForUser = ref.watch(biometricLockEnabledForUserProvider);

    // React to the lock arming while the app is already in the foreground —
    // the user toggling it on, or the value resolving `true` after an async
    // settings load (private mode). Prompt immediately.
    ref.listen<bool>(biometricLockActiveProvider, (prev, next) {
      if (next &&
          prev != true &&
          _lifecycle == AppLifecycleState.resumed &&
          !_authInProgress) {
        _authenticate();
      }
    });

    // Cover the content when the user must authenticate, or whenever the app is
    // not in the foreground (so the app-switcher snapshot never shows data).
    final coverForSwitcher =
        enabledForUser && _lifecycle != AppLifecycleState.resumed;

    if (!locked && !coverForSwitcher) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: _LockOverlay(
            interactive: locked,
            authenticating: _authInProgress,
            onUnlock: _authenticate,
          ),
        ),
      ],
    );
  }
}

/// The opaque lock screen drawn over the app. When [interactive] it offers a
/// Retry button that re-triggers the prompt; otherwise it is a passive privacy
/// cover (used for the app-switcher snapshot while already authenticated).
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.interactive,
    required this.authenticating,
    required this.onUnlock,
  });

  final bool interactive;
  final bool authenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  context.t.habits.appLocked,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t.habits.unlockWithBiometricsToContinue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: colors.mutedForeground,
                  ),
                ),
                if (interactive) ...[
                  const SizedBox(height: 32),
                  EvolveButton(
                    label: context.t.habits.retry,
                    expand: false,
                    loading: authenticating,
                    onPressed: onUnlock,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
