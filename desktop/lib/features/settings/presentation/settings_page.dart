import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/features/settings/application/settings_form_controller.dart';
import 'package:evolve_desktop/features/settings/application/sync_settings_controller.dart';
import 'package:evolve_desktop/features/settings/presentation/dialogs/settings_dialogs.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/account_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/advanced_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/ai_coach_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/data_backup_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/general_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/notifications_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/privacy_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/panes/subscription_pane.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_section.dart';
import 'package:evolve_desktop/features/settings/presentation/settings_search.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_about_footer.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_row_kit.dart';
import 'package:evolve_desktop/features/settings/presentation/widgets/settings_search_widgets.dart';
import 'package:evolve_desktop/features/shell/application/navigation_controller.dart';
import 'package:evolve_desktop/shared/widgets/desktop_page.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:evolve_desktop/shared/widgets/evolve_image_crop_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:evolve_desktop/features/auth/application/desktop_profile_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

export 'package:evolve_desktop/features/settings/presentation/dialogs/import_mode_dialog.dart'
    show showImportModeDialog;
export 'package:evolve_desktop/features/settings/presentation/panes/subscription_pane.dart'
    show annualSavingPercent, showPaywallDialog;
// The export paging moved out with the flow that uses it. Re-exported because
// it is a public, separately-tested contract and the page is where every caller
// already looks for it.
export 'package:evolve_desktop/features/settings/application/settings_data_controller.dart'
    show ExportPageFetcher, fetchAllRowsPaginated, kExportPageSize;

/// Longest edge, in pixels, of a stored avatar. The image is encrypted here and
/// decrypted on every device that pulls it by synchronous pure-Dart AES-GCM on
/// the UI isolate (~1.9 MB/s), so a multi-MB camera original freezes both this
/// app and the paired iPhone. Mirrors mobile's picker cap.
const int kAvatarMaxDimension = 512;

/// Re-encodes [bytes] so the longest edge is at most [maxDimension]. Returns
/// the original bytes unchanged when they already fit, when the re-encode would
/// be larger, or when the image cannot be decoded — so this never returns more
/// bytes than it was handed.
///
/// image_picker's `maxWidth`/`maxHeight`/`imageQuality` cannot do this here:
/// image_picker_macos routes gallery picks to file_selector and silently
/// ignores all three, so the downscale has to happen in Dart.
Future<Uint8List> downscaleAvatarBytes(
  Uint8List bytes, {
  int maxDimension = kAvatarMaxDimension,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longestEdge = math.max(descriptor.width, descriptor.height);
    if (longestEdge <= maxDimension) return bytes;

    final scale = maxDimension / longestEdge;
    codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round().clamp(1, maxDimension),
      targetHeight: (descriptor.height * scale).round().clamp(1, maxDimension),
    );
    image = (await codec.getNextFrame()).image;
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    if (encoded == null) return bytes;
    // PNG is lossless, so re-encoding a small, heavily compressed photo can
    // come out BIGGER than the source. What costs the sync path is bytes, not
    // pixels, so keep whichever payload is smaller.
    if (encoded.lengthInBytes >= bytes.length) return bytes;
    return encoded.buffer.asUint8List();
  } catch (error, stack) {
    // The downscale is an optimisation, never a gate: an undecodable or exotic
    // format still has to be usable as an avatar.
    AppLogger.error('Unable to downscale desktop avatar', error, stack);
    return bytes;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    // The buffer has to outlive instantiateCodec — dart:ui's own
    // instantiateImageCodecWithSize holds it until the codec exists — so it is
    // released here rather than right after ImageDescriptor.encoded.
    buffer?.dispose();
  }
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  SettingsSection _section = SettingsSection.account;

  /// The detail pane's own scroll position, separate from the page-level
  /// PrimaryScrollController the whole page used to share.
  final ScrollController _paneScroll = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  /// The row the search just jumped to, tinted until the user does anything
  /// else. Cleared on a timer so the page does not stay permanently marked.
  String? _highlightedRow;
  Timer? _highlightTimer;
  final GlobalKey _highlightTarget = GlobalKey();

  File? _profileImage;

  /// Everything the panes render and write lives in
  /// [settingsFormControllerProvider], not here: seventeen mutable fields on
  /// this class were the reason every pane had to be one of its methods. Each
  /// pane watches it for itself, so the page no longer needs to.
  ///
  /// Captured once, at init, so `dispose` can detach without reaching for `ref`
  /// on a widget that is on its way out.
  late final SettingsFormController _formController = ref.read(
    settingsFormControllerProvider.notifier,
  );

  /// As [_formController]: the iCloud sync card's state and the work behind it
  /// live in a kept-alive controller, so `dispose` needs the notifier it was
  /// handed at init rather than a fresh `ref.read` on a dying widget.
  late final SyncSettingsController _syncController = ref.read(
    syncSettingsControllerProvider.notifier,
  );

  /// This visit's identity in the two controllers, handed back on dispose.
  ///
  /// The shell cross-fades sections, so leaving Settings and coming straight
  /// back mounts a SECOND page before this one disposes; detaching by token
  /// means an outgoing page can only ever shut off its own visit.
  ///
  /// `late final` is safe: both `hydrate` calls in `initState` are
  /// unconditional and run before any early return.
  late final int _formToken;
  late final int _syncToken;

  @override
  void dispose() {
    // The controllers outlive this page; tell them the page is gone so they
    // stop applying pulls and rolling writes back into a UI nobody is looking
    // at. This is what `!mounted` used to do for the same code.
    _formController.detach(_formToken);
    _syncController.detach(_syncToken);
    _highlightTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _paneScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Deep-link: one request provider, one consumer. This used to be two
    // ad-hoc booleans handled asymmetrically — the privacy one here, the
    // subscription one in a build-time listener — and the subscription flag had
    // no producer left anywhere in lib/ or test/.
    final requested = ref.read(settingsSectionRequestProvider);
    if (requested != null) {
      _section = requested.section;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // The highlight has to wait for first build — there is no row to tint
        // or scroll to before the pane exists.
        if (requested.rowId != null) {
          _jumpToRow(requested.section, rowId: requested.rowId);
        }
        ref.read(settingsSectionRequestProvider.notifier).consume();
      });
    }
    // Forgets the previous visit's status and re-reads it. This used to be an
    // `unawaited(_refreshSyncStatus())` straight into `setState`.
    _syncToken = _syncController.hydrate();
    // Reads SharedPreferences and the appearance controller into the form's
    // initial state, then kicks the synced read-back off UNAWAITED — even when
    // there are no preferences to read, otherwise a fresh install never
    // hydrates. `hydrate` is deliberately a step after the controller's own
    // build: the store is often already cached, in which case the read-back
    // resolves synchronously and a notifier may not assign `state` mid-build.
    _formToken = _formController.hydrate();
  }

  @override
  Widget build(BuildContext context) {
    // A request that arrives while Settings is already open (the chat header's
    // engine chip, the coach page's banners) still has to land.
    ref.listen(settingsSectionRequestProvider, (_, target) {
      if (target != null) {
        _jumpToRow(target.section, rowId: target.rowId);
        ref.read(settingsSectionRequestProvider.notifier).consume();
      }
    });

    // The failure toast lives here rather than in the form controller: it needs
    // an Overlay and this page's own `mounted`, neither of which a provider has.
    // The controller raises a counter; every increment is one failed write.
    ref.listen(
      settingsFormControllerProvider.select((form) => form.saveFailures),
      (previous, next) {
        if (next <= (previous ?? 0)) return;
        showEvolveToast(
          context,
          message: t.settingsPage.settingSaveFailed,
          kind: EvolveToastKind.error,
        );
      },
    );

    final dataMode = ref.watch(activeDesktopDataModeProvider);
    final isPrivateMode = dataMode.isPrivate;

    // Filter available sections based on mode
    final availableSections = SettingsSection.values.where((section) {
      if (isPrivateMode && section == SettingsSection.subscription) {
        return false;
      }
      return true;
    }).toList();

    return SettingsHighlight(
      rowId: _highlightedRow,
      targetKey: _highlightTarget,
      child: CallbackShortcuts(
        bindings: {
          // ⌘F is the macOS convention for "find in this window", and the rail
          // is where the field lives.
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _searchFocus.requestFocus,
        },
        // autofocus so CallbackShortcuts actually receives key events: it only
        // hears them when something in its subtree holds focus, and with
        // `autofocus: false` the binding was dead until the user happened to
        // click a control first. Key events still bubble UP from here, so the
        // shell's own ⌘1–⌘5 / ⌘K bindings keep working.
        child: Focus(autofocus: true, child: _shell(availableSections)),
      ),
    );
  }

  Widget _shell(List<SettingsSection> availableSections) {
    return DesktopPage(
      title: t.settingsPage.pageTitle,
      // `pinned` is what makes the rail a rail. Without it the page header, the
      // sidebar and the pane all lived in one SingleChildScrollView, so on the
      // taller panes the destinations scrolled off the top — a sidebar that
      // scrolls away is not a sidebar. Now the page fills the viewport and the
      // pane owns the only scrollable.
      //
      // The page subtitle is gone with it: it listed the panes, directly above
      // the rail that lists them.
      pinned: true,
      child: EvolvePanel(
        padding: EdgeInsets.zero,
        child: Row(
          // `stretch`, not `start`. Under `start` the rail was only as tall as
          // its destinations and `const VerticalDivider(width: 1)` resolved to
          // 1x0 logical pixels — it had never painted anything.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 236, child: _rail(availableSections)),
            Container(
              width: 1,
              color: context.evolveColors.border.withValues(alpha: 0.6),
            ),
            Expanded(child: _paneBody()),
          ],
        ),
      ),
    );
  }

  /// The fixed source list: destinations grouped You / App / Data, with the
  /// expert pane separated at the bottom.
  Widget _rail(List<SettingsSection> sections) {
    final query = _searchQuery.trim();
    if (query.isNotEmpty) {
      return _searchRail(query);
    }

    final children = <Widget>[];
    SettingsSectionGroup? previous;

    for (final section in sections) {
      if (section.group != previous) {
        if (previous != null) children.add(const SizedBox(height: 10));
        final caption = section.group.caption;
        children.add(
          caption != null
              ? Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(11, 4, 11, 6),
                  child: Text(
                    caption,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.9,
                      color: context.evolveColors.muted.withValues(alpha: 0.65),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(11, 2, 11, 8),
                  child: Container(
                    height: 1,
                    color: context.evolveColors.border.withValues(alpha: 0.5),
                  ),
                ),
        );
        previous = section.group;
      }
      children.add(
        _SettingsDestination(
          key: section.key,
          section: section,
          selected: section == _section,
          onTap: () => _selectSection(section),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        // Docked below the destinations, outside the scrollable — the build
        // number should be readable without scrolling to find it.
        const SettingsAboutFooter(),
      ],
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
      child: EvolveSearchField(
        controller: _searchController,
        focusNode: _searchFocus,
        hintText: t.settingsPage.searchPlaceholder,
        clearTooltip: t.settingsPage.searchClear,
        // The ⌘F binding below has always been invisible; the badge is the
        // only thing that tells anyone it exists.
        shortcutHint: '⌘ F',
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// The rail while a query is active: matching ROWS across every pane, not
  /// just the panes themselves. Searching only pane names would answer
  /// "language" with "General" and leave the user to hunt.
  Widget _searchRail(String query) {
    final isPrivateMode = ref.watch(activeDesktopDataModeProvider).isPrivate;
    final results = searchSettings(query, isPrivateMode: isPrivateMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _searchField(),
        Expanded(
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 0),
                  child: Text(
                    t.settingsPage.searchNoResults,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.evolveColors.muted,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    return SettingsSearchResult(
                      key: ValueKey('settings.result.${entry.id}'),
                      entry: entry,
                      onTap: () => _jumpToRow(entry.section, rowId: entry.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Opens [section] and, when [rowId] is given, tints that row so the eye
  /// lands on it.
  ///
  /// Shared by the sidebar's own result list and by the ⌘K palette, which
  /// deep-links through `settingsSectionRequestProvider`. Both are searching
  /// the same index for the same query, so "found it" has to mean the same
  /// thing in both — a palette hit that dumped the user at the top of General
  /// while the sidebar scrolled and highlighted was the tell that one of them
  /// was wrong.
  ///
  /// When called from the sidebar the query is deliberately left in the field:
  /// the user may want the next match, and clearing it would throw the result
  /// list away the instant they used it.
  void _jumpToRow(SettingsSection section, {String? rowId}) {
    _highlightTimer?.cancel();
    setState(() {
      _section = section;
      _highlightedRow = rowId;
    });
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);

    // Scroll the row into view once it exists. Two frames: the pane rebuilds on
    // the first, and the row's RenderObject is only attached after that.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _highlightTarget.currentContext;
      if (target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            alignment: 0.15,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      }
    });

    if (rowId == null) return;
    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _highlightedRow = null);
    });
  }

  /// The detail pane. Owns its own scroll position, which is reset on every
  /// pane change: the offset used to belong to the shared page-level
  /// PrimaryScrollController, so switching from a tall pane to a short one left
  /// the viewport parked past the end of the new content.
  Widget _paneBody() {
    return Scrollbar(
      controller: _paneScroll,
      child: SingleChildScrollView(
        controller: _paneScroll,
        padding: const EdgeInsets.all(22),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Capped rather than fluid. One column of full-width cards on a
            // 27-inch display gives 1,600px-wide rows whose label and control
            // are a screen apart.
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (_section) {
              SettingsSection.account => SettingsAccountPane(
                profileImage: _profileImage,
                onPickAvatar: _pickAvatar,
              ),
              SettingsSection.general => const SettingsGeneralPane(),
              SettingsSection.notifications =>
                const SettingsNotificationsPane(),
              SettingsSection.aiCoach => const SettingsAiCoachPane(),
              SettingsSection.dataBackup => const SettingsDataBackupPane(),
              SettingsSection.privacy => const SettingsPrivacyPane(),
              SettingsSection.advanced => const SettingsAdvancedPane(),
              SettingsSection.subscription => const SettingsSubscriptionPane(),
            },
          ),
        ),
      ),
    );
  }

  void _selectSection(SettingsSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    // Jump, not animate: changing panes is navigation, and a new document
    // should appear at its top immediately.
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      final selectedFile = File(image.path);

      final Uint8List? croppedBytes = await showEvolveDialog<Uint8List>(
        context: context,
        builder: (context) =>
            EvolveImageCropDialog(image: FileImage(selectedFile)),
      );

      if (croppedBytes == null) return;
      await selectedFile.writeAsBytes(croppedBytes, flush: true);

      final isPrivateMode = ref.read(activeDesktopDataModeProvider).isPrivate;
      if (isPrivateMode) {
        final original = croppedBytes;
        final resized = await downscaleAvatarBytes(original);
        // Keep the source extension when the bytes were passed through, since
        // the downscale re-encodes to PNG whenever it does any work.
        final extension = identical(resized, original)
            ? p.extension(image.path)
            : '.png';
        final supportDir = await getApplicationSupportDirectory();
        final avatarDir = Directory(p.join(supportDir.path, 'private_profile'));
        await avatarDir.create(recursive: true);
        final selectedFile = File(p.join(avatarDir.path, 'avatar$extension'));
        await selectedFile.writeAsBytes(resized, flush: true);
        // Evict the (path-keyed) cached decode so the UI re-reads the new bytes.
        // The avatar is written to a STABLE path (avatar.<ext>), so an in-place
        // overwrite otherwise keeps showing the previous photo (settings avatar
        // + shell header) until cache pressure or restart. Mirrors mobile.
        await FileImage(selectedFile).evict();
        await ref
            .read(privateProfileProvider.notifier)
            .updateAvatar(selectedFile.path);
        setState(() => _profileImage = selectedFile);
      } else {
        setState(() => _profileImage = File(image.path));
      }
    } catch (error, stack) {
      AppLogger.error('Unable to pick desktop avatar', error, stack);
      if (mounted) {
        showSettingsGate(
          context,
          t.settingsPage.avatarGateTitle,
          t.settingsPage.avatarPickFailed,
        );
      }
    }
  }
}

class _SettingsDestination extends StatelessWidget {
  const _SettingsDestination({
    super.key,
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contentColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : context.evolveColors.muted;
    // `selected` was conveyed by accent fill and FontWeight.w800 alone, which
    // VoiceOver cannot see: the rail read as six identical buttons with no
    // indication of where you were. `button` is explicit because the InkWell
    // sits under a Material of type transparency, which does not imply it.
    return Semantics(
      selected: selected,
      button: true,
      label: section.label,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? context.evolveAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              hoverColor: selected
                  ? Colors.transparent
                  : context.evolveColors.panel.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(section.icon, color: contentColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      // German and Arabic overflow the 171px text box; without a
                      // tooltip an ellipsised destination is unreadable and
                      // unidentifiable.
                      child: Tooltip(
                        message: section.label,
                        waitDuration: const Duration(milliseconds: 600),
                        child: Text(
                          section.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            letterSpacing: -0.2,
                            color: contentColor,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
