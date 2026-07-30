import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../i18n/translations.g.dart';
import '../../providers/auth_provider.dart';

/// The first screen after consent: use Evolve with no account, or sign in.
///
/// **This screen exists for Guideline 5.1.1(v).** iOS 1.1.2 was rejected
/// because App Review concluded the app "requires users to register with
/// personal information to purchase In-App Purchase products that are not
/// account based". That conclusion was wrong on the facts — Private mode has
/// always unlocked every on-device Pro feature for free, with no account — but
/// it was entirely reasonable given what the app showed them.
///
/// The old first screen was a login wall. Email field, password field, a
/// primary "Create Account" button, then Apple, then Google, and only fifth,
/// in the same muted chrome as the Google button, a row labelled "Continue
/// privately on this iPhone". That label reads as a *sync preference*, not as
/// "skip registration", and reviewers scan for "Skip", "Guest" or "without an
/// account". On a short screen it fell below the fold.
///
/// So the fix is not a new capability, it is making an existing one legible:
///
///  * Two equal choices, no-account first, before any credential field exists.
///  * A label that says the compliance thing ("without an account") before the
///    privacy thing ("stays on this iPhone").
///  * [t.auth.chooserFootnote] states Apple's own suggested remedy — that
///    signing in is optional and exists so a subscription works across devices.
///
/// Choosing Private mode is cheap and reversible: it flips a preference and
/// skips Supabase initialisation. Nothing here is destructive, and Settings can
/// switch back.
class DataModeChoiceScreen extends ConsumerStatefulWidget {
  const DataModeChoiceScreen({super.key});

  @override
  ConsumerState<DataModeChoiceScreen> createState() =>
      _DataModeChoiceScreenState();
}

class _DataModeChoiceScreenState extends ConsumerState<DataModeChoiceScreen> {
  /// Guards the no-account tap. `startPrivateMode` awaits a preference write
  /// and a provider rebuild; without this a double tap runs it twice.
  bool _isStartingPrivateMode = false;

  Future<void> _continueWithoutAccount() async {
    if (_isStartingPrivateMode) return;
    setState(() => _isStartingPrivateMode = true);
    ref.hapticMedium();
    try {
      // The router redirects to '/' as soon as this lands, because
      // `canAccessApp` becomes true — see the redirect in main.dart.
      await ref.read(authProvider.notifier).startPrivateMode();
    } finally {
      if (mounted) setState(() => _isStartingPrivateMode = false);
    }
  }

  void _signIn() {
    ref.hapticLight();
    // push, not go: the auth screen keeps its own no-account affordance, and a
    // pushed route leaves the system back gesture returning here. Choosing to
    // look at sign-in must never become a commitment to sign in.
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isCompact = MediaQuery.sizeOf(context).height < 780;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          PositionedDirectional(
            top: -100,
            end: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            // Scrollable, like AuthScreen. A fixed Column with Spacers
            // overflowed by 16px on a 375x667 iPhone SE at DEFAULT text size,
            // and by ~170px at 1.3x Dynamic Type on a current iPhone — and the
            // first thing clipped was the footnote, i.e. the one sentence
            // stating that signing in is optional. Losing that sentence
            // silently undoes the reason this screen exists.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isCompact ? 12 : 24,
                ),
                child: ConstrainedBox(
                  // Fill the viewport when there is room, so the Spacers still
                  // centre the cards on a large screen; scroll when there is
                  // not. minHeight subtracts the vertical padding this
                  // ConstrainedBox sits inside.
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (isCompact ? 24 : 48),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isCompact ? 16 : 48),
                        Text(
                          context.t.auth.chooserTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: colors.foreground,
                            fontSize: isCompact ? 24 : 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.t.auth.chooserSubtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: colors.mutedForeground,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),

                        // Listed FIRST, and drawn as the primary card. The
                        // ordering is the point of the screen — see class doc.
                        _ModeCard(
                          key: const Key('mode_choice_without_account'),
                          icon: LucideIcons.smartphone,
                          title: context.t.auth.continueWithoutAccount,
                          subtitle:
                              context.t.auth.continueWithoutAccountSubtitle,
                          isPrimary: true,
                          isBusy: _isStartingPrivateMode,
                          onTap: _continueWithoutAccount,
                        ),
                        const SizedBox(height: 16),
                        _ModeCard(
                          key: const Key('mode_choice_sign_in'),
                          icon: LucideIcons.refreshCw,
                          title: context.t.auth.signInToSync,
                          subtitle: context.t.auth.signInToSyncSubtitle,
                          isPrimary: false,
                          isBusy: false,
                          onTap: _isStartingPrivateMode ? null : _signIn,
                        ),

                        const Spacer(),

                        // Apple's own suggested wording for this guideline:
                        // tell the user what registering buys them, rather
                        // than requiring it.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            context.t.auth.chooserFootnote,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: colors.mutedForeground,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.isBusy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final borderColor = isPrimary
        ? primaryColor.withValues(alpha: 0.8)
        : colors.border;

    return Semantics(
      button: true,
      // One announcement for the whole card. Without this a screen reader
      // reads the title and the subtitle as two unrelated nodes, and the
      // subtitle is where the "no sign-up, no limits" promise lives.
      label: '$title. $subtitle',
      excludeSemantics: true,
      // onTap is NOT redundant with the InkWell below. `excludeSemantics`
      // drops the whole child subtree from the semantics tree, tap action
      // included, so without this the node announces as a button that cannot
      // be activated: on iOS, accessibilityActivate returns NO when the node
      // carries no tap action and UIKit does not synthesise a touch. Since
      // this is the first screen after consent and offers no other control,
      // omitting it makes the app unenterable under VoiceOver.
      onTap: isBusy ? null : onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: isPrimary ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: colors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: colors.mutedForeground,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isBusy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                else
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.chevronLeft
                        : LucideIcons.chevronRight,
                    size: 20,
                    color: colors.mutedForeground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
