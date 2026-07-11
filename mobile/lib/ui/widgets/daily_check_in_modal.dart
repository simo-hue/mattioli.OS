import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../core/haptics.dart';
import '../../providers/mood_provider.dart';
import '../kit/evolve_button.dart';
import '../kit/evolve_sheet.dart';
import '../../i18n/translations.g.dart';

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
  double _mood = 5.0;
  double _energy = 5.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final moods = ref.read(dailyMoodsProvider);
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todayMood = moods[dateKey];
      if (todayMood != null) {
        setState(() {
          _mood = todayMood.moodScore.toDouble();
          _energy = todayMood.energyScore.toDouble();
        });
      }
    });
  }

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
    final moods = ref.watch(dailyMoodsProvider);
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final isFirstTime = !moods.containsKey(dateKey);
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const EvolveGrabber(),
          const SizedBox(height: 24),

          // Header
          Text(
            context.t.habits.dailyCheckIn,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t.habits.trackYourMoodAndEnergy,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: context.appColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 32),

          // Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.appColors.cardElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appColors.border, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t.habits.dailyCheckIn,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.foreground,
                  ),
                ),
                const SizedBox(height: 24),

                // Mood Section
                _buildSliderSection(
                  label: context.t.habits.mood,
                  icon: LucideIcons.heart,
                  value: _mood,
                  emoji: _getMoodEmoji(_mood.round()),
                  onChanged: (val) => setState(() => _mood = val),
                ),

                const SizedBox(height: 32),

                // Energy Section
                _buildSliderSection(
                  label: context.t.habits.energy,
                  icon: LucideIcons.zap,
                  value: _energy,
                  emoji: _getEnergyEmoji(_energy.round()),
                  onChanged: (val) => setState(() => _energy = val),
                ),

                const SizedBox(height: 32),

                // Update Button
                EvolveButton(
                  label: isFirstTime
                      ? context.t.habits.enter
                      : context.t.habits.update,
                  icon: LucideIcons.save,
                  haptic: EvolveButtonHaptic.success,
                  onPressed: () async {
                    await ref.read(dailyMoodsProvider.notifier).saveMood(
                      DateTime.now(),
                      _mood.round(),
                      _energy.round(),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
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
            Icon(icon, size: 18, color: context.appColors.mutedForeground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: context.appColors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '$emoji ${value.round()}/10',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.appColors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor: context.appColors.border,
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
