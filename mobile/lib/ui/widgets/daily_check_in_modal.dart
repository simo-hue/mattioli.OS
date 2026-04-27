import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';

class DailyCheckInModal extends ConsumerStatefulWidget {
  const DailyCheckInModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const DailyCheckInModal(),
    );
  }

  @override
  ConsumerState<DailyCheckInModal> createState() => _DailyCheckInModalState();
}

class _DailyCheckInModalState extends ConsumerState<DailyCheckInModal> {
  double _mood = 9.0;
  double _energy = 8.0;

  String _getMoodEmoji(int value) {
    if (value >= 9) return '🤩';
    if (value >= 7) return '😊';
    if (value >= 5) return '😐';
    if (value >= 3) return '😔';
    return '😫';
  }

  String _getEnergyEmoji(int value) {
    if (value >= 9) return '⚡️';
    if (value >= 7) return '⚡️';
    if (value >= 5) return '🔋';
    if (value >= 3) return '🪫';
    return '💤';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          const Text(
            'Daily Check-in',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Traccia il tuo umore ed energia.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),

          // Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Check-in',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 24),

                // Mood Section
                _buildSliderSection(
                  label: 'Mood',
                  icon: LucideIcons.heart,
                  value: _mood,
                  emoji: _getMoodEmoji(_mood.round()),
                  onChanged: (val) => setState(() => _mood = val),
                ),

                const SizedBox(height: 32),

                // Energy Section
                _buildSliderSection(
                  label: 'Energy',
                  icon: LucideIcons.zap,
                  value: _energy,
                  emoji: _getEnergyEmoji(_energy.round()),
                  onChanged: (val) => setState(() => _energy = val),
                ),

                const SizedBox(height: 32),

                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.hapticSuccess();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.save, size: 18),
                        const SizedBox(width: 10),
                        const Text(
                          'Update Daily Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40), // Safe area bottom
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required String label,
    required IconData icon,
    required double value,
    required String emoji,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$emoji ${value.round()}/10',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: AppColors.border,
            thumbColor: Theme.of(context).colorScheme.primary,
            overlayColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 10,
            onChanged: (v) {
              onChanged(v);
              ref.hapticAction();
            },
          ),
        ),
      ],
    );
  }
}
