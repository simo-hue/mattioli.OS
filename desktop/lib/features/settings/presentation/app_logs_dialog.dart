import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_controls.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:evolve_desktop/shared/widgets/evolve_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';


// Severity accents mapped onto the shared StatusPill palette
// (destructive / amber / muted). Info resolves from the active palette so it
// stays readable on the light theme (the dark muted gray washes out on white).
const _errorColor = EvolveColors.destructive;
const _warnColor = EvolveColors.amber;

const _monoFont = 'monospace';

Color _levelColor(EvolvePalette colors, AppLogLevel level) => switch (level) {
  AppLogLevel.error => _errorColor,
  AppLogLevel.warning => _warnColor,
  AppLogLevel.info => colors.muted,
};

/// Opens the in-app diagnostic log viewer (Settings → System → App Logs).
Future<void> showAppLogsDialog(BuildContext context) {
  return showEvolveDialog<void>(
    context: context,
    builder: (_) => const _AppLogsDialog(),
  );
}

class _AppLogsDialog extends StatefulWidget {
  const _AppLogsDialog();

  @override
  State<_AppLogsDialog> createState() => _AppLogsDialogState();
}

class _AppLogsDialogState extends State<_AppLogsDialog> {
  AppLogLevel? _filter;
  String _query = '';
  bool _searchVisible = false;
  final _searchController = TextEditingController();
  // Expanded cards, keyed by entry identity (indices would shift as new logs
  // arrive newest-first or the filter changes).
  final _expanded = <LogEntry>{};

  @override
  void initState() {
    super.initState();
    AppLogger.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    AppLogger.removeListener(_onLogsChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) setState(() {});
  }

  List<LogEntry> get _filteredLogs {
    var logs = AppLogger.logs;
    if (_filter != null) {
      logs = logs.where((e) => e.level == _filter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      logs = logs
          .where(
            (e) =>
                e.message.toLowerCase().contains(q) ||
                (e.error?.toLowerCase().contains(q) ?? false) ||
                (e.stackTrace?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return logs;
  }

  String _formatLogs(List<LogEntry> logs) {
    if (logs.isEmpty) return 'No logs available.';
    final buffer = StringBuffer()
      ..writeln('=== App Logs Export ===')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Total entries: ${logs.length}')
      ..writeln('');
    for (final e in logs) {
      buffer.writeln(
        '[${e.formattedTimestamp}] [${e.levelLabel}] ${e.message}',
      );
      if (e.error != null) buffer.writeln('  Error: ${e.error}');
      if (e.extras != null && e.extras!.isNotEmpty) {
        buffer.writeln('  Extras: ${e.extras}');
      }
      if (e.stackTrace != null) {
        buffer.writeln('  Stack Trace:');
        for (final line in e.stackTrace!.split('\n').take(12)) {
          buffer.writeln('    $line');
        }
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _formatLogs(AppLogger.logs)));
    _toast(t.appLogs.copiedToClipboard);
  }

  Future<void> _shareLogs() async {
    final text = _formatLogs(AppLogger.logs);
    
    final location = await getSaveLocation(
      suggestedName: 'evolve_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    
    if (location == null) {
      return;
    }
    
    final file = File(location.path);
    await file.writeAsString(text);
    
    if (mounted) _toast(t.appLogs.exportDone);
  }

  void _toast(String message) {
    if (!mounted) return;
    showEvolveToast(context, message: message);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showEvolveDialog<bool>(
      context: context,
      builder: (ctx) => EvolveAlertDialog(
        icon: LucideIcons.trash2,
        title: Text(t.appLogs.clearLogsTitle),
        subtitle: t.appLogs.clearLogsConfirm,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.actions.cancel),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.appLogs.clearLogsAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      AppLogger.clearLogs();
      if (mounted) setState(() => _expanded.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.evolveColors;
    final logs = _filteredLogs;

    return EvolveDialog(
      maxWidth: 760,
      child: SizedBox(
        height: 580,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(colors),
            const Divider(height: 1),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: colors.foreground, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t.appLogs.searchPlaceholder,
                    prefixIcon: const Icon(LucideIcons.search, size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              crossFadeState: _searchVisible
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    colors,
                    label: t.appLogs.filterAll,
                    count: AppLogger.logs.length,
                    active: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  _chip(
                    colors,
                    label: t.appLogs.filterErrors,
                    count: AppLogger.errorCount,
                    color: _errorColor,
                    active: _filter == AppLogLevel.error,
                    onTap: () => _toggleFilter(AppLogLevel.error),
                  ),
                  _chip(
                    colors,
                    label: t.appLogs.filterWarnings,
                    count: AppLogger.warningCount,
                    color: _warnColor,
                    active: _filter == AppLogLevel.warning,
                    onTap: () => _toggleFilter(AppLogLevel.warning),
                  ),
                  _chip(
                    colors,
                    label: t.appLogs.filterInfo,
                    count: AppLogger.infoCount,
                    color: colors.muted,
                    active: _filter == AppLogLevel.info,
                    onTap: () => _toggleFilter(AppLogLevel.info),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? _emptyState(colors)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: logs.length,
                      itemBuilder: (context, index) =>
                          _logCard(colors, logs[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFilter(AppLogLevel level) =>
      setState(() => _filter = _filter == level ? null : level);

  Widget _header(EvolvePalette colors) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 16, 16),
      child: Row(
        children: [
          EvolveIconChip(
            icon: LucideIcons.scrollText,
            color: context.evolveAccent,
            size: 36,
            iconSize: 18,
            outlined: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.appLogs.title,
              style: TextStyle(
                color: colors.foreground,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            tooltip: t.appLogs.searchPlaceholder,
            icon: Icon(_searchVisible ? LucideIcons.x : LucideIcons.search),
            iconSize: 18,
            onPressed: () => setState(() {
              _searchVisible = !_searchVisible;
              if (!_searchVisible) {
                _query = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            tooltip: t.appLogs.copyAll,
            icon: const Icon(LucideIcons.copy),
            iconSize: 18,
            onPressed: _copyAll,
          ),
          IconButton(
            tooltip: t.appLogs.shareLogs,
            icon: const Icon(LucideIcons.share),
            iconSize: 18,
            onPressed: _shareLogs,
          ),
          IconButton(
            tooltip: t.appLogs.clearLogsAction,
            icon: const Icon(LucideIcons.trash2),
            iconSize: 18,
            color: _errorColor,
            onPressed: _confirmClear,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    EvolvePalette colors, {
    required String label,
    required int count,
    required bool active,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? colors.foreground;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? chipColor.withValues(alpha: 0.12)
              : colors.panel.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: active
                ? chipColor.withValues(alpha: 0.4)
                : colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? chipColor : colors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: active ? chipColor : colors.muted.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(EvolvePalette colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.fileCheck,
            size: 30,
            color: colors.muted.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 14),
          Text(
            t.appLogs.emptyTitle,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.appLogs.emptySubtitle,
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _logCard(EvolvePalette colors, LogEntry entry) {
    final levelColor = _levelColor(colors, entry.level);
    final isExpanded = _expanded.contains(entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.level == AppLogLevel.error
              ? _errorColor.withValues(alpha: 0.25)
              : colors.border.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() {
            if (isExpanded) {
              _expanded.remove(entry);
            } else {
              _expanded.add(entry);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(label: entry.levelLabel, color: levelColor),
                    const Spacer(),
                    Text(
                      entry.formattedTimestamp,
                      style: TextStyle(
                        fontFamily: _monoFont,
                        color: colors.muted.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _copyEntry(entry),
                        borderRadius: BorderRadius.circular(6),
                        child: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: colors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  entry.message,
                  style: TextStyle(
                    fontFamily: _monoFont,
                    color: colors.foreground,
                    fontSize: 12,
                    height: 1.5,
                  ),
                  maxLines: isExpanded ? null : 3,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (entry.error != null) ...[
                  const SizedBox(height: 8),
                  _detailBlock(colors, entry.error!, levelColor),
                ],
                if (isExpanded &&
                    entry.extras != null &&
                    entry.extras!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  EvolveFieldLabel(t.appLogs.detailExtras),
                  const SizedBox(height: 4),
                  _detailBlock(
                    colors,
                    entry.extras!.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join('\n'),
                    colors.border,
                  ),
                ],
                if (entry.stackTrace != null) ...[
                  const SizedBox(height: 8),
                  if (isExpanded)
                    _detailBlock(
                      colors,
                      entry.stackTrace!,
                      colors.border,
                      mono: true,
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          LucideIcons.layers,
                          size: 11,
                          color: colors.muted.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          t.appLogs.stackTraceAvailable,
                          style: TextStyle(
                            color: colors.muted.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailBlock(
    EvolvePalette colors,
    String content,
    Color borderColor, {
    bool mono = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: _monoFont,
          color: colors.muted,
          fontSize: mono ? 10 : 11,
          height: 1.4,
        ),
      ),
    );
  }

  void _copyEntry(LogEntry entry) {
    final buffer = StringBuffer()
      ..writeln(
        '[${entry.formattedTimestamp}] [${entry.levelLabel}] ${entry.message}',
      );
    if (entry.error != null) buffer.writeln('Error: ${entry.error}');
    if (entry.extras != null) buffer.writeln('Extras: ${entry.extras}');
    if (entry.stackTrace != null) {
      buffer
        ..writeln('Stack Trace:')
        ..writeln(entry.stackTrace);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _toast(t.appLogs.copiedToClipboard);
  }
}
