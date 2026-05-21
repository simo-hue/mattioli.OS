import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'goal_provider.dart';
import 'auth_provider.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../core/localization.dart';
import '../ui/widgets/error_modal.dart';

final supabase = Supabase.instance.client;

class DailyMood {
  final String id;
  final String userId;
  final String date;
  final int moodScore;
  final int energyScore;

  DailyMood({
    required this.id,
    required this.userId,
    required this.date,
    required this.moodScore,
    required this.energyScore,
  });

  factory DailyMood.fromJson(Map<String, dynamic> json) {
    return DailyMood(
      id: json['id'],
      userId: json['user_id'],
      date: json['date'],
      moodScore: json['mood_score'],
      energyScore: json['energy_score'],
    );
  }
}

typedef DailyMoodsMap = Map<String, DailyMood>; // dateKey -> DailyMood

class DailyMoodsNotifier extends Notifier<DailyMoodsMap> {
  @override
  DailyMoodsMap build() {
    ref.listen(authProvider, (previous, next) {
      if (next.isLoggedIn && next.user != null) {
        _syncFromSupabase();
      } else if (!next.isLoggedIn) {
        state = {};
      }
    });

    final authState = ref.read(authProvider);
    if (authState.isLoggedIn && authState.user != null) {
      _syncFromSupabase();
    }

    return {};
  }

  Future<void> _syncFromSupabase() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('daily_moods')
          .select('*')
          .eq('user_id', user.id);

      final DailyMoodsMap newMap = {};
      for (final row in response) {
        final date = row['date'] as String;
        newMap[date] = DailyMood.fromJson(row);
      }
      state = newMap;
    } catch (e, stack) {
      AppLogger.error('[DailyMoods] Sync error', e, stack);
    }
  }

  Future<void> saveMood(DateTime date, int mood, int energy) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final response = await supabase
          .from('daily_moods')
          .upsert({
            'user_id': user.id,
            'date': dateKey,
            'mood_score': mood,
            'energy_score': energy,
          }, onConflict: 'user_id, date')
          .select()
          .single();

      final updatedMood = DailyMood.fromJson(response);

      final newState = Map<String, DailyMood>.from(state);
      newState[dateKey] = updatedMood;
      state = newState;
    } catch (e, stack) {
      AppLogger.error('[DailyMoods] Save error', e, stack);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ErrorModal.show(
          context,
          title: context.l10n.moodSaveErrorTitle,
          message: context.l10n.moodSaveFailed,
          details: e.toString(),
        );
      }
    }
  }
}

final dailyMoodsProvider = NotifierProvider<DailyMoodsNotifier, DailyMoodsMap>(
  DailyMoodsNotifier.new,
);

class MoodCorrelation {
  final String goalId;
  final int lowMoodPct;
  final int highMoodPct;
  final int sensitivity;
  final int resilience;
  final double avgMoodDone;
  final double avgEnergyDone;
  final double avgMoodMissed;
  final double avgEnergyMissed;

  MoodCorrelation({
    required this.goalId,
    required this.lowMoodPct,
    required this.highMoodPct,
    required this.sensitivity,
    required this.resilience,
    required this.avgMoodDone,
    required this.avgEnergyDone,
    required this.avgMoodMissed,
    required this.avgEnergyMissed,
  });
}

final moodCorrelationProvider = Provider<List<MoodCorrelation>>((ref) {
  final moods = ref.watch(dailyMoodsProvider);
  final logs = ref.watch(habitLogsProvider);

  final habitCorrelations = <String, Map<String, dynamic>>{};

  logs.forEach((dateStr, habits) {
    if (moods.containsKey(dateStr)) {
      final mood = moods[dateStr]!;
      final isHighMood = mood.moodScore >= 60;
      final isLowMood = mood.moodScore < 40;

      habits.forEach((goalId, status) {
        if (!habitCorrelations.containsKey(goalId)) {
          habitCorrelations[goalId] = {
            'high_done': 0,
            'high_total': 0,
            'low_done': 0,
            'low_total': 0,
            'mood_done_sum': 0,
            'mood_done_count': 0,
            'energy_done_sum': 0,
            'energy_done_count': 0,
            'mood_missed_sum': 0,
            'mood_missed_count': 0,
            'energy_missed_sum': 0,
            'energy_missed_count': 0,
          };
        }

        final data = habitCorrelations[goalId]!;

        if (isHighMood) {
          data['high_total']++;
          if (status == 'done') data['high_done']++;
        } else if (isLowMood) {
          data['low_total']++;
          if (status == 'done') data['low_done']++;
        }

        if (status == 'done') {
          data['mood_done_sum'] += mood.moodScore;
          data['mood_done_count']++;
          data['energy_done_sum'] += mood.energyScore;
          data['energy_done_count']++;
        } else if (status == 'missed') {
          data['mood_missed_sum'] += mood.moodScore;
          data['mood_missed_count']++;
          data['energy_missed_sum'] += mood.energyScore;
          data['energy_missed_count']++;
        }
      });
    }
  });

  final List<MoodCorrelation> result = [];

  habitCorrelations.forEach((goalId, data) {
    final highTotal = data['high_total'] as int;
    final lowTotal = data['low_total'] as int;

    final highPct = highTotal > 0
        ? ((data['high_done'] as int) / highTotal * 100).round()
        : 0;
    final lowPct = lowTotal > 0
        ? ((data['low_done'] as int) / lowTotal * 100).round()
        : 0;

    final sensitivity = highPct - lowPct;
    final resilience = lowPct;

    final moodDoneCount = data['mood_done_count'] as int;
    final energyDoneCount = data['energy_done_count'] as int;
    final moodMissedCount = data['mood_missed_count'] as int;
    final energyMissedCount = data['energy_missed_count'] as int;

    final avgMoodDone = moodDoneCount > 0
        ? (data['mood_done_sum'] as int) / moodDoneCount
        : 0.0;
    final avgEnergyDone = energyDoneCount > 0
        ? (data['energy_done_sum'] as int) / energyDoneCount
        : 0.0;
    final avgMoodMissed = moodMissedCount > 0
        ? (data['mood_missed_sum'] as int) / moodMissedCount
        : 0.0;
    final avgEnergyMissed = energyMissedCount > 0
        ? (data['energy_missed_sum'] as int) / energyMissedCount
        : 0.0;

    result.add(
      MoodCorrelation(
        goalId: goalId,
        lowMoodPct: lowPct,
        highMoodPct: highPct,
        sensitivity: sensitivity,
        resilience: resilience,
        avgMoodDone: avgMoodDone,
        avgEnergyDone: avgEnergyDone,
        avgMoodMissed: avgMoodMissed,
        avgEnergyMissed: avgEnergyMissed,
      ),
    );
  });

  return result;
});
