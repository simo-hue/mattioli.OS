import 'dart:async';
import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/features/auth/application/consent_controller.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/change_password_dialog.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_pane_scaffold.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Who you are: the profile card, the personal details, credentials, and the
/// way out.
///
/// [profileImage] and [onPickAvatar] stay owned by the page — the picked file
/// is page-lifetime state and the picker is a flow, not a control.
class SettingsAccountPane extends ConsumerWidget {
  const SettingsAccountPane({
    super.key,
    required this.profileImage,
    required this.onPickAvatar,
  });

  final File? profileImage;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(desktopAuthControllerProvider);
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsHeading(section: SettingsSection.account),
        const SizedBox(height: 20),
        _ProfileCard(
          user: auth.user,
          image: profileImage,
          isPro: ref.watch(desktopIsProProvider),
          onPickAvatar: onPickAvatar,
          isPrivateMode: isPrivateMode,
          privateProfile: isPrivateMode
              ? ref.watch(privateProfileProvider).value
              : null,
        ),
        const SizedBox(height: 24),
        SettingsColumn(
          groups: [
            // Editable in BOTH modes. The dialog these replace was gated
            // behind `if (!isPrivateMode)`, so a Private-mode user could never
            // change their own name or birthday — while
            // `privateProfileProvider.updateProfile` sat fully implemented and
            // unreachable.
            SettingsGroup(
              title: t.settingsPage.personalInfo,
              children: const [_PersonalInfoRows()],
            ),
            if (!isPrivateMode)
              SettingsGroup(
                title: t.settingsPage.groupSignIn,
                children: [
                  SettingsInfoRow(
                    id: 'account.email',
                    label: t.settingsPage.email,
                    value:
                        auth.user?.email ?? t.settingsPage.sessionUnavailable,
                  ),
                  // Moved here from Privacy › "Access protection". Credential
                  // management is account lifecycle, and scattering it across
                  // two panes is what made "Privacy" mean nothing in
                  // particular.
                  SettingsActionRow(
                    id: 'account.changePassword',
                    title: t.settingsPage.changePassword,
                    detail: t.settingsPage.changePasswordDetail,
                    state: auth.isLoggedIn
                        ? const SettingsRowState.enabled()
                        : SettingsRowState.disabled(
                            t.settingsPage.gateRequiresActiveSession,
                          ),
                    onTap: () => showEvolveDialog<void>(
                      context: context,
                      builder: (context) => const ChangePasswordDialog(),
                    ),
                  ),
                  SettingsActionRow(
                    id: 'account.resetConsent',
                    title: t.settingsPage.reviewInitialConsent,
                    detail: t.settingsPage.reviewInitialConsentDetail,
                    onTap: () => unawaited(_reviewConsent(ref)),
                  ),
                ],
              ),
            // One row where there were two. "Account" and "Data repository" sat
            // consecutively encoding the same fact — which data mode you are in
            // — and the second said it in vendor language ("Supabase with
            // encrypted cache"), duplicating the profile card directly above.
            // Untitled: the card holds one row, and a group heading that reads
            // identically to the row inside it is noise.
            SettingsGroup(
              children: [
                SettingsInfoRow(
                  id: 'account.dataStorage',
                  label: t.settingsPage.dataStorage,
                  value: isPrivateMode
                      ? t.settingsPage.dataStorageThisMac
                      : t.settingsPage.dataStorageAccount,
                ),
              ],
            ),
            // "Update avatar" is gone, and the avatar in the card above is
            // tappable in Private mode only — in account mode the picker
            // persists nothing. See TO_SIMO_DO.md for the missing upload path.
          ],
        ),
        const SizedBox(height: 18),
        if (!isPrivateMode)
          SettingsDestructiveButton(
            label: t.settingsPage.signOut,
            caption: auth.isLoggedIn
                ? t.settingsPage.signOutDetailActive
                : t.settingsPage.availableWithActiveSession,
            onTap: auth.isLoggedIn
                ? () => unawaited(_confirmSignOut(context, ref))
                : () => showSettingsGate(
                    context,
                    t.settingsPage.gateLogout,
                    t.settingsPage.gateRequiresActiveSession,
                  ),
          )
        else
          SettingsDestructiveButton(
            label: t.settingsPage.goToLogin,
            caption: t.settingsPage.goToLoginDetail,
            onTap: () {
              ref.read(desktopAuthControllerProvider.notifier).goToLogin();
            },
          ),
      ],
    );
  }

  Future<void> _reviewConsent(WidgetRef ref) async {
    final consent = ref.read(desktopConsentControllerProvider);
    await ref
        .read(desktopConsentControllerProvider.notifier)
        .setConsent(
          acceptedTerms: false,
          sentryConsent: consent.hasSentryConsent,
          completed: false,
        );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmSettingsAction(
      context,
      title: t.settingsPage.confirmSignOutTitle,
      message: t.settingsPage.confirmSignOutMessage,
      destructive: true,
    );
    if (confirmed) await _signOut(ref);
  }

  Future<void> _signOut(WidgetRef ref) async {
    try {
      await ref.read(desktopAuthControllerProvider.notifier).signOut();
    } catch (_) {}
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.user,
    required this.image,
    required this.isPro,
    required this.onPickAvatar,
    this.isPrivateMode = false,
    this.privateProfile,
  });

  final User? user;
  final File? image;
  final bool isPro;
  final VoidCallback onPickAvatar;
  final bool isPrivateMode;
  final PrivateProfileState? privateProfile;

  @override
  Widget build(BuildContext context) {
    final metadata = user?.userMetadata;
    final fullName = isPrivateMode
        ? privateProfile?.fullName
        : (metadata?['full_name'] as String?)?.trim();
    final avatarUrl = isPrivateMode
        ? privateProfile?.avatarPath
        : metadata?['avatar_url'] as String?;
    return EvolvePanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          InkWell(
            // Private mode ONLY. There is the whole of the account-mode avatar
            // problem in one line: `_pickAvatar` writes through
            // `updateAvatar()` in Private mode, but in account mode it only
            // sets a page-local File that is never uploaded — no Supabase
            // Storage call exists anywhere in desktop/lib — so the picture
            // reverted on the next rebuild. The "Update avatar" ROW was deleted
            // for this; the picture stayed tappable and kept the dead
            // affordance alive. See TO_SIMO_DO.md for the missing upload path.
            onTap: isPrivateMode ? onPickAvatar : null,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPro
                      ? EvolveColors.amber
                      : context.evolveAccent.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: context.evolveColors.panel,
                backgroundImage: image != null
                    ? FileImage(image!)
                    : avatarUrl != null
                    ? (isPrivateMode
                              ? FileImage(File(avatarUrl))
                              : NetworkImage(avatarUrl))
                          as ImageProvider
                    : null,
                child: image == null && avatarUrl == null
                    ? Icon(
                        LucideIcons.user,
                        size: 20,
                        color: context.evolveAccent,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateMode
                      : fullName?.isNotEmpty ?? false
                      ? fullName!
                      : user?.email?.split('@').first ??
                            t.settingsPage.profileFallback,
                  style: TextStyle(
                    color: context.evolveColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPrivateMode
                      ? t.settingsPage.privateModeDataProtected
                      : user?.email ?? t.settingsPage.sessionUnavailable,
                  style: TextStyle(
                    color: context.evolveColors.muted.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (isPro)
            const StatusPill(
              label: 'PRO',
              color: EvolveColors.amber,
              icon: LucideIcons.sparkles,
            )
          else
            StatusPill(
              label: user == null
                  ? t.settingsPage.notAuthenticated
                  : t.settingsPage.verified,
              color: user == null ? EvolveColors.amber : context.evolveAccent,
              icon: user == null ? LucideIcons.lock : LucideIcons.shieldCheck,
            ),
        ],
      ),
    );
  }
}

/// Full name and date of birth, editable inline in the Account pane.
///
/// This was `_PersonalInfoDialog`. Two things were wrong with it beyond being a
/// modal for a routine edit. It was gated behind `if (!isPrivateMode)`, so a
/// Private-mode user could never change their own name or birthday — even
/// though `privateProfileProvider.updateProfile` was fully implemented and
/// simply unreachable. And its Email field was a labelled `hintText` with no
/// controller, which renders as an empty focusable box: the address was
/// invisible until you clicked into it. Email is now a read-only value row in
/// the pane, where it belongs.
///
/// Commits on blur, not per keystroke — the profile is synced, and writing on
/// every character would push a partial name to the iPhone.
class _PersonalInfoRows extends ConsumerStatefulWidget {
  const _PersonalInfoRows();

  @override
  ConsumerState<_PersonalInfoRows> createState() => _PersonalInfoRowsState();
}

class _PersonalInfoRowsState extends ConsumerState<_PersonalInfoRows> {
  final TextEditingController _name = TextEditingController();
  DateTime? _birthDate;

  /// What the store last confirmed, so a rejected edit can be put back. The
  /// dialog swallowed write failures whole (`catch (_)`), leaving the field
  /// showing a name nothing had stored — the same class of silent lie the rest
  /// of this page was fixed for.
  String _storedName = '';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _hydrate() {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    final String? storedBirthDate;
    if (isPrivate) {
      final profile = ref.read(privateProfileProvider).value;
      _storedName = profile?.fullName ?? '';
      storedBirthDate = profile?.dateOfBirth;
    } else {
      final user = ref.read(desktopAuthControllerProvider).user;
      _storedName = user?.userMetadata?['full_name'] as String? ?? '';
      storedBirthDate = user?.userMetadata?['date_of_birth'] as String?;
    }
    _name.text = _storedName;
    // The profile stores an ISO `yyyy-MM-dd` string (or empty).
    _birthDate = storedBirthDate == null || storedBirthDate.trim().isEmpty
        ? null
        : DateTime.tryParse(storedBirthDate.trim());
  }

  /// The ISO `yyyy-MM-dd` shape the free-text field used to produce (empty
  /// string when unset), so profiles round-trip unchanged.
  String get _isoBirthDate {
    final date = _birthDate;
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persist({
    required String name,
    required String birthDate,
  }) async {
    try {
      final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivate) {
        await ref
            .read(privateProfileProvider.notifier)
            .updateProfile(fullName: name, dateOfBirth: birthDate);
      } else {
        await ref
            .read(desktopAuthControllerProvider.notifier)
            .updatePersonalInfo(fullName: name, dateOfBirth: birthDate);
      }
      _storedName = name;
    } catch (error, stack) {
      AppLogger.error('Unable to save personal information', error, stack);
      if (!mounted) return;
      setState(() {
        _name.text = _storedName;
        _hydrateBirthDateFromStore();
      });
      showEvolveToast(
        context,
        message: t.settingsPage.settingSaveFailed,
        kind: EvolveToastKind.error,
      );
    }
  }

  void _hydrateBirthDateFromStore() {
    final isPrivate = ref.read(activeDesktopDataModeProvider).isPrivate;
    final stored = isPrivate
        ? ref.read(privateProfileProvider).value?.dateOfBirth
        : ref
                  .read(desktopAuthControllerProvider)
                  .user
                  ?.userMetadata?['date_of_birth']
              as String?;
    _birthDate = stored == null || stored.trim().isEmpty
        ? null
        : DateTime.tryParse(stored.trim());
  }

  void _commitName(String value) {
    final name = value.trim();
    // An empty name is not a change, it is a mistake — the dialog's Save button
    // refused it too. Put the stored one back so the row does not sit there
    // blank, implying it saved.
    if (name.isEmpty) {
      setState(() => _name.text = _storedName);
      return;
    }
    if (name == _storedName) return;
    unawaited(_persist(name: name, birthDate: _isoBirthDate));
  }

  void _commitBirthDate(DateTime? date) {
    setState(() => _birthDate = date);
    final name = _name.text.trim();
    // Both fields go in one write, so a birthday change must not blank a name
    // the user has not filled in yet.
    if (name.isEmpty) return;
    unawaited(_persist(name: name, birthDate: _isoBirthDate));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsTextRow(
          id: 'account.fullName',
          label: t.settingsPage.fullName,
          controller: _name,
          onCommit: _commitName,
        ),
        const SettingsRowHairline(),
        SettingsDateRow(
          id: 'account.dateOfBirth',
          label: t.settingsPage.dateOfBirth,
          value: _birthDate,
          hint: t.settingsPage.dateOfBirthHint,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
          onChanged: _commitBirthDate,
        ),
      ],
    );
  }
}
