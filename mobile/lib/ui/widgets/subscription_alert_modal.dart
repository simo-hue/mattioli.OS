import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../i18n/translations.g.dart';

enum SubscriptionAlertType {
  success,
  warning,
  error,
}

class SubscriptionAlertModal extends ConsumerWidget {
  final String title;
  final String message;
  final String? details;
  final SubscriptionAlertType type;
  final VoidCallback? onConfirm;

  const SubscriptionAlertModal({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.details,
    this.onConfirm,
  });

  /// Shows an elegant dialog for a subscription status
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required SubscriptionAlertType type,
    String? details,
    VoidCallback? onConfirm,
    WidgetRef? ref,
  }) {
    // Trigger proper haptics based on type
    if (ref != null) {
      switch (type) {
        case SubscriptionAlertType.success:
          ref.hapticSuccess();
          break;
        case SubscriptionAlertType.warning:
          ref.hapticMedium();
          break;
        case SubscriptionAlertType.error:
          ref.hapticError();
          break;
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: type != SubscriptionAlertType.success, // Success dialog requires tapping button
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SubscriptionAlertModal(
            title: title,
            message: message,
            type: type,
            details: details,
            onConfirm: () {
              Navigator.pop(dialogContext);
              if (onConfirm != null) {
                onConfirm();
              }
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    // Custom configuration based on alert type
    final Color accentColor = switch (type) {
      SubscriptionAlertType.success => Colors.amber,
      SubscriptionAlertType.warning => Colors.amber,
      SubscriptionAlertType.error => colors.destructive,
    };

    final IconData icon = switch (type) {
      SubscriptionAlertType.success => LucideIcons.sparkles,
      SubscriptionAlertType.warning => LucideIcons.info,
      SubscriptionAlertType.error => LucideIcons.triangleAlert,
    };

    final Color glowColor = accentColor.withValues(alpha: 0.15);
    final Color borderGlowColor = accentColor.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderGlowColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Header with subtle pulse border
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 36,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Message
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colors.mutedForeground,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Technical Details (for errors)
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: SingleChildScrollView(
                  child: Text(
                    details!,
                    style: GoogleFonts.firaCode(
                      color: colors.foreground.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Confirm Button
          GestureDetector(
            onTap: () {
              ref.hapticLight();
              if (onConfirm != null) {
                onConfirm!();
              }
            },
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: type == SubscriptionAlertType.error
                      ? [colors.destructive, colors.destructive.withValues(alpha: 0.8)]
                      : [Colors.amber.shade400, Colors.amber.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: (type == SubscriptionAlertType.error ? colors.destructive : Colors.amber)
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  type == SubscriptionAlertType.success
                      ? context.t.common.startYourJourney
                      : context.t.common.actions.gotIt,
                  style: TextStyle(
                    color: type == SubscriptionAlertType.error ? Colors.white : Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
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
