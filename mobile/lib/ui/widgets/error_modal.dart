import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ErrorModal extends ConsumerWidget {
  final String title;
  final String message;
  final String? details;

  const ErrorModal({
    super.key,
    required this.title,
    required this.message,
    this.details,
  });

  static void show(BuildContext context, {
    required String title,
    required String message,
    String? details,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ErrorModal(title: title, message: message, details: details),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: colors.border, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          
          // Error Icon Header
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
              border: Border.all(color: colors.destructive.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: colors.destructive.withValues(alpha: 0.1),
                  blurRadius: 30,
                  spreadRadius: 5,
                )
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
            style: GoogleFonts.inter(
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
            style: GoogleFonts.inter(
              color: colors.mutedForeground,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          
          if (details != null) ...[
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
                    'Dettagli tecnici:',
                    style: GoogleFonts.inter(
                      color: colors.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details!,
                    style: GoogleFonts.firaCode(
                      color: colors.foreground.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 40),
          
          // Close Button
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
                  )
                ],
              ),
              child: Center(
                child: Text(
                  'Ho capito',
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
