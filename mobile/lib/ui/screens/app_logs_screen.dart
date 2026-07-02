import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../core/rtl.dart';
import '../../i18n/translations.g.dart';

/// Full-screen log viewer showing all in-memory log entries.
/// Designed for technical users — shows timestamps, levels, stack traces, etc.
class AppLogsScreen extends StatefulWidget {
  const AppLogsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AppLogsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  State<AppLogsScreen> createState() => _AppLogsScreenState();
}

class _AppLogsScreenState extends State<AppLogsScreen> {
  AppLogLevel? _activeFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    AppLogger.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    AppLogger.removeListener(_onLogsChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    if (mounted) setState(() {});
  }

  List<LogEntry> get _filteredLogs {
    var logs = AppLogger.logs;
    if (_activeFilter != null) {
      logs = logs.where((e) => e.level == _activeFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      logs = logs.where((e) {
        return e.message.toLowerCase().contains(q) ||
            (e.error?.toLowerCase().contains(q) ?? false) ||
            (e.stackTrace?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    return logs;
  }

  String _formatLogs(List<LogEntry> logs) {
    if (logs.isEmpty) return 'No logs available.';

    final buffer = StringBuffer();
    buffer.writeln('=== App Logs Export ===');
    buffer.writeln('Exported: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${logs.length}');
    buffer.writeln('');

    for (final entry in logs) {
      buffer.writeln('[${entry.formattedTimestamp}] [${entry.levelLabel}] ${entry.message}');
      if (entry.error != null) {
        buffer.writeln('  Error: ${entry.error}');
      }
      if (entry.extras != null && entry.extras!.isNotEmpty) {
        buffer.writeln('  Extras: ${entry.extras}');
      }
      if (entry.stackTrace != null) {
        buffer.writeln('  Stack Trace:');
        for (final line in entry.stackTrace!.split('\n').take(10)) {
          buffer.writeln('    $line');
        }
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  void _copyAllLogs() {
    final text = _formatLogs(AppLogger.logs);
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t.appLogs.copiedToClipboard),
          backgroundColor: context.appColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareLogs() async {
    final text = _formatLogs(AppLogger.logs);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/mattioli_logs_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(text);
    
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exported App Logs',
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  void _confirmClearLogs() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.t.appLogs.clearLogsTitle,
          style: TextStyle(
            color: context.appColors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          context.t.appLogs.clearLogsConfirm,
          style: TextStyle(color: context.appColors.mutedForeground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.t.common.actions.cancel,
              style: TextStyle(color: context.appColors.mutedForeground),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              AppLogger.clearLogs();
            },
            child: Text(
              context.t.appLogs.clearLogsAction,
              style: TextStyle(color: context.appColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final logs = _filteredLogs;
    final errorCount = AppLogger.errorCount;
    final warningCount = AppLogger.warningCount;
    final infoCount =
        AppLogger.logs.where((e) => e.level == AppLogLevel.info).length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: DirectionalIcon(
            LucideIcons.chevronLeft,
            LucideIcons.chevronRight,
            color: colors.foreground,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.t.appLogs.title,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isSearchVisible ? LucideIcons.x : LucideIcons.search,
              color: colors.mutedForeground,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              color: colors.mutedForeground,
              size: 20,
            ),
            color: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(LucideIcons.share, size: 16, color: colors.foreground),
                    const SizedBox(width: 10),
                    Text(
                      'Share Logs File',
                      style: TextStyle(color: colors.foreground, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(LucideIcons.copy, size: 16, color: colors.foreground),
                    const SizedBox(width: 10),
                    Text(
                      context.t.appLogs.copyAll,
                      style: TextStyle(color: colors.foreground, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 16, color: colors.destructive),
                    const SizedBox(width: 10),
                    Text(
                      context.t.appLogs.clearLogsAction,
                      style: TextStyle(color: colors.destructive, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'share') _shareLogs();
              if (value == 'copy') _copyAllLogs();
              if (value == 'clear') _confirmClearLogs();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.jetBrainsMono(
                    color: colors.foreground,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: context.t.appLogs.searchPlaceholder,
                    hintStyle: TextStyle(
                      color: colors.mutedForeground.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      LucideIcons.search,
                      size: 16,
                      color: colors.mutedForeground,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),
            crossFadeState: _isSearchVisible
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          // Filter chips + stats bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  context,
                  label: context.t.appLogs.filterAll,
                  count: AppLogger.logs.length,
                  isActive: _activeFilter == null,
                  onTap: () => setState(() => _activeFilter = null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: context.t.appLogs.filterErrors,
                  count: errorCount,
                  isActive: _activeFilter == AppLogLevel.error,
                  color: colors.destructive,
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == AppLogLevel.error ? null : AppLogLevel.error),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: context.t.appLogs.filterWarnings,
                  count: warningCount,
                  isActive: _activeFilter == AppLogLevel.warning,
                  color: const Color(0xFFEAB308),
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == AppLogLevel.warning
                          ? null
                          : AppLogLevel.warning),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  context,
                  label: context.t.appLogs.filterInfo,
                  count: infoCount,
                  isActive: _activeFilter == AppLogLevel.info,
                  color: const Color(0xFF3B82F6),
                  onTap: () => setState(() => _activeFilter =
                      _activeFilter == AppLogLevel.info ? null : AppLogLevel.info),
                ),
              ],
            ),
          ),

          // Logs list
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return _buildLogCard(context, logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required int count,
    required bool isActive,
    Color? color,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    final chipColor = color ?? colors.foreground;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? chipColor.withValues(alpha: 0.15)
              : colors.card.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? chipColor.withValues(alpha: 0.4)
                : colors.border.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? chipColor : colors.mutedForeground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isActive
                    ? chipColor.withValues(alpha: 0.2)
                    : colors.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isActive ? chipColor : colors.mutedForeground,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.card.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.border.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              LucideIcons.fileCheck,
              size: 28,
              color: colors.mutedForeground.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t.appLogs.emptyTitle,
            style: TextStyle(
              color: colors.foreground,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t.appLogs.emptySubtitle,
            style: TextStyle(
              color: colors.mutedForeground.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, LogEntry entry) {
    final colors = context.appColors;

    Color levelColor;
    IconData levelIcon;
    switch (entry.level) {
      case AppLogLevel.error:
        levelColor = colors.destructive;
        levelIcon = LucideIcons.circleX;
        break;
      case AppLogLevel.warning:
        levelColor = const Color(0xFFEAB308);
        levelIcon = LucideIcons.triangleAlert;
        break;
      case AppLogLevel.info:
        levelColor = const Color(0xFF3B82F6);
        levelIcon = LucideIcons.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.level == AppLogLevel.error
              ? colors.destructive.withValues(alpha: 0.2)
              : colors.border.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showLogDetail(context, entry),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: level badge + timestamp
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: levelColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(levelIcon, size: 11, color: levelColor),
                          const SizedBox(width: 4),
                          Text(
                            entry.levelLabel,
                            style: GoogleFonts.jetBrainsMono(
                              color: levelColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      entry.formattedTimestamp,
                      style: GoogleFonts.jetBrainsMono(
                        color: colors.mutedForeground.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Message
                Text(
                  entry.message,
                  style: GoogleFonts.jetBrainsMono(
                    color: colors.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                // Error preview
                if (entry.error != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: levelColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      entry.error!,
                      style: GoogleFonts.jetBrainsMono(
                        color: colors.mutedForeground,
                        fontSize: 11,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // Stack trace indicator
                if (entry.stackTrace != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.layers,
                        size: 11,
                        color: colors.mutedForeground.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.t.appLogs.stackTraceAvailable,
                        style: TextStyle(
                          color: colors.mutedForeground.withValues(alpha: 0.5),
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

  void _showLogDetail(BuildContext context, LogEntry entry) {
    final colors = context.appColors;

    Color levelColor;
    switch (entry.level) {
      case AppLogLevel.error:
        levelColor = colors.destructive;
        break;
      case AppLogLevel.warning:
        levelColor = const Color(0xFFEAB308);
        break;
      case AppLogLevel.info:
        levelColor = const Color(0xFF3B82F6);
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: levelColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        entry.levelLabel,
                        style: GoogleFonts.jetBrainsMono(
                          color: levelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.formattedTimestamp,
                        style: GoogleFonts.jetBrainsMono(
                          color: colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        LucideIcons.copy,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln(
                          '[${entry.formattedTimestamp}] [${entry.levelLabel}] ${entry.message}',
                        );
                        if (entry.error != null) {
                          buffer.writeln('Error: ${entry.error}');
                        }
                        if (entry.extras != null) {
                          buffer.writeln('Extras: ${entry.extras}');
                        }
                        if (entry.stackTrace != null) {
                          buffer.writeln('Stack Trace:');
                          buffer.writeln(entry.stackTrace);
                        }
                        Clipboard.setData(
                          ClipboardData(text: buffer.toString()),
                        );
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.t.appLogs.copiedToClipboard),
                            backgroundColor: colors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildDetailSection(
                      context,
                      title: context.t.appLogs.detailMessage,
                      content: entry.message,
                    ),
                    if (entry.error != null)
                      _buildDetailSection(
                        context,
                        title: context.t.appLogs.detailError,
                        content: entry.error!,
                        color: levelColor,
                      ),
                    if (entry.extras != null && entry.extras!.isNotEmpty)
                      _buildDetailSection(
                        context,
                        title: context.t.appLogs.detailExtras,
                        content: entry.extras!.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n'),
                      ),
                    if (entry.stackTrace != null)
                      _buildDetailSection(
                        context,
                        title: context.t.appLogs.detailStackTrace,
                        content: entry.stackTrace!,
                        isStackTrace: true,
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context, {
    required String title,
    required String content,
    Color? color,
    bool isStackTrace = false,
  }) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color ?? colors.mutedForeground,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (color ?? colors.border).withValues(alpha: 0.3),
            ),
          ),
          child: SelectableText(
            content,
            style: GoogleFonts.jetBrainsMono(
              color: isStackTrace
                  ? colors.mutedForeground.withValues(alpha: 0.8)
                  : colors.foreground,
              fontSize: isStackTrace ? 10 : 12,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
