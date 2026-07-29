import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The Settings sidebar destinations, in rail order.
///
/// Eight panes, each answering one question a Mac user would actually ask.
/// The six they replace were named after nothing in particular: `Application`
/// is a container word rather than a domain, and `Privacy` had accumulated
/// seven unrelated concerns — iCloud transport health, the device lock, account
/// credentials, crash-report consent, data portability, an OS deep link and
/// account deletion. A pane's name has to predict its contents.
///
/// Public — and deliberately so. Tests used to reach a destination with
/// `find.text(t.settingsPage.sectionApplication)`, which couples every
/// navigation in the suite to a localized string: the label is a rendering
/// detail that this redesign rewrites, while the destination it opens is the
/// thing the test actually means. Nine test files navigated that way, so a
/// single rename broke them all while proving nothing.
///
/// Navigate by [key] instead. The identity is [name], which is stable across
/// copy changes and locales.
enum SettingsSection {
  account,
  subscription,
  general,
  notifications,
  aiCoach,
  dataBackup,
  privacy,
  advanced,
}

/// The rail's visual grouping. The sidebar draws a small caption above the
/// first destination of each group; [SettingsSectionGroup.none] draws a plain
/// separator instead, which is where the expert-level destination sits — the
/// bottom of the list, where Mac users expect it.
enum SettingsSectionGroup { you, app, data, none }

extension SettingsSectionX on SettingsSection {
  /// Stable widget key — see the class doc on [SettingsSection].
  Key get key => ValueKey('settings.section.$name');

  /// One string per pane, used for BOTH the rail entry and the pane heading.
  ///
  /// Four of the old six had two different names for one destination —
  /// "Application" opened "Appearance and application", "Privacy" opened
  /// "Privacy and security", "Subscription" opened "Evolve Pro" — so the label
  /// you clicked was never the title you landed on.
  String get label => switch (this) {
    SettingsSection.account => t.settingsPage.sectionAccount,
    SettingsSection.subscription => t.settingsPage.subscription,
    SettingsSection.general => t.settingsPage.sectionGeneral,
    SettingsSection.notifications => t.settingsPage.notifications,
    SettingsSection.aiCoach => t.coachSettings.settingsSectionLabel,
    SettingsSection.dataBackup => t.settingsPage.sectionDataBackup,
    SettingsSection.privacy => t.settingsPage.sectionPrivacySecurity,
    SettingsSection.advanced => t.settingsPage.sectionAdvanced,
  };

  /// One sentence on what the pane is for. Descriptive, not a restatement of
  /// [label] — two of the six it replaces restated the rail entry, and two more
  /// were factually wrong about their own contents.
  String get purpose => switch (this) {
    SettingsSection.account => t.settingsPage.accountPaneSubtitle,
    SettingsSection.subscription => t.settingsPage.proSubtitle,
    SettingsSection.general => t.settingsPage.generalPaneSubtitle,
    SettingsSection.notifications => t.settingsPage.notificationsPaneSubtitle,
    SettingsSection.aiCoach => t.coachSettings.settingsSubtitle,
    SettingsSection.dataBackup => t.settingsPage.dataBackupPaneSubtitle,
    SettingsSection.privacy => t.settingsPage.privacyPaneSubtitle,
    SettingsSection.advanced => t.settingsPage.advancedPaneSubtitle,
  };

  IconData get icon => switch (this) {
    SettingsSection.account => LucideIcons.userRound,
    SettingsSection.subscription => LucideIcons.sparkles,
    SettingsSection.general => LucideIcons.slidersHorizontal,
    SettingsSection.notifications => LucideIcons.bell,
    SettingsSection.aiCoach => LucideIcons.bot,
    SettingsSection.dataBackup => LucideIcons.cloud,
    SettingsSection.privacy => LucideIcons.shield,
    SettingsSection.advanced => LucideIcons.wrench,
  };

  SettingsSectionGroup get group => switch (this) {
    SettingsSection.account ||
    SettingsSection.subscription => SettingsSectionGroup.you,
    SettingsSection.general ||
    SettingsSection.notifications ||
    SettingsSection.aiCoach => SettingsSectionGroup.app,
    SettingsSection.dataBackup ||
    SettingsSection.privacy => SettingsSectionGroup.data,
    SettingsSection.advanced => SettingsSectionGroup.none,
  };
}

extension SettingsSectionGroupX on SettingsSectionGroup {
  /// Null for [SettingsSectionGroup.none] — the rail draws a plain separator
  /// rather than a caption, because "Advanced" is one destination and a caption
  /// above a single item is just a second label for it.
  String? get caption => switch (this) {
    SettingsSectionGroup.you => t.settingsPage.railGroupYou,
    SettingsSectionGroup.app => t.settingsPage.railGroupApp,
    SettingsSectionGroup.data => t.settingsPage.railGroupData,
    SettingsSectionGroup.none => null,
  };
}

/// Stable widget keys for the rows and group cards inside a pane.
///
/// Same rationale as [SettingsSection.key]: a row's label is about to change,
/// its identity is not. [id] is a dotted path — `'general.theme'`,
/// `'notifications.morningBrief'` — which is also the address a future sidebar
/// search and the command palette will jump to.
abstract final class SettingsKeys {
  static Key row(String id) => ValueKey('settings.row.$id');
  static Key group(String id) => ValueKey('settings.group.$id');
}
