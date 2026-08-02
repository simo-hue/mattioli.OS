import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/fonts.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../i18n/translations.g.dart';
import '../kit/evolve_sheet.dart';

class ErrorModal extends ConsumerWidget {
  final String title;
  final String message;
  final String? details;

  /// Show [details] even outside debug builds. Off by default (SEC-7: raw error
  /// text may leak internals). Opt in only for developer/QA-facing failures the
  /// user is expected to diagnose or report (e.g. habit-save errors).
  final bool forceDetails;

  const ErrorModal({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.forceDetails = false,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    bool forceDetails = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ErrorModal(
            title: title,
            message: message,
            details: details,
            forceDetails: forceDetails,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Column(
          children: [
            const EvolveGrabber(),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colors.destructive.withValues(alpha: 0.2),
                            colors.destructive.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: colors.destructive.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.destructive.withValues(alpha: 0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        LucideIcons.triangleAlert,
                        size: 40,
                        color: colors.destructive,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', 
                        color: colors.foreground,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', 
                        color: colors.mutedForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    // Raw error text is technical and may leak internals, so
                    // only show it in debug builds — or when the call site opts
                    // in via [forceDetails] for a developer/QA-facing failure
                    // the user must diagnose. Release users otherwise see just
                    // the title + message; the error is still reported to
                    // Sentry by the call site's AppLogger.error (SEC-7).
                    if ((kDebugMode || forceDetails) && details != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t.common.technicalDetails,
                              style: TextStyle(fontFamily: 'Inter', 
                                color: colors.mutedForeground,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              details!,
                              style: TextStyle(fontFamily: kMonospaceFontFamily, fontFamilyFallback: kMonospaceFontFallback, 
                                color: colors.foreground.withValues(alpha: 0.8),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                ref.hapticMedium();
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.foreground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colors.foreground.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    context.t.common.actions.gotIt,
                    style: TextStyle(
                      color: colors.background,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
