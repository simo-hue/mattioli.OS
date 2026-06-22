import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'goal_provider.dart';
import 'auth_provider.dart';
import '../models/daily_mood.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../core/navigator_key.dart';
import '../core/app_logger.dart';
import '../ui/widgets/error_modal.dart';
import '../i18n/translations.g.dart';

SupabaseClient get supabase => Supabase.instance.client;

typedef DailyMoodsMap = Map<String, DailyMood>; // dateKey -> DailyMood

class DailyMoodsNotifier extends Notifier<DailyMoodsMap> {
  @override
  DailyMoodsMap build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      _loadFromPrivateStore();
      return {};
    }

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

  Future<void> _loadFromPrivateStore() async {
    try {
      state = await ref.read(privateLocalDatabaseProvider).loadDailyMoods();
    } catch (e, stack) {
      AppLogger.error('[DailyMoods] Private load error', e, stack);
      state = {};
    }
  }

  Future<void> _syncFromSupabase() async {
    if (ref.read(activeDataModeProvider) == AppDataMode.private) return;
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
    if (ref.read(activeDataModeProvider) == AppDataMode.private) {
      try {
        final updatedMood = await ref
            .read(privateLocalDatabaseProvider)
            .saveMood(date, mood, energy);
        final newState = Map<String, DailyMood>.from(state);
        newState[updatedMood.date] = updatedMood;
        state = newState;
      } catch (e, stack) {
        AppLogger.error('[DailyMoods] Private save error', e, stack);
      }
      return;
    }

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
          title: context.t.common.moodSaveErrorTitle,
          message: context.t.common.moodSaveFailed,
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

/// Pure computation behind [moodCorrelationProvider]. Extracted so the
/// 0–10-scale mood banding (high >= 6, low < 4, 4–5 neutral) can be unit
/// tested without standing up Riverpod or the data stores.
List<MoodCorrelation> computeMoodCorrelations({
  required DailyMoodsMap moods,
  required HabitLogsMap logs,
}) {
  final habitCorrelations = <String, Map<String, dynamic>>{};

  logs.forEach((dateStr, habits) {
    if (moods.containsKey(dateStr)) {
      final mood = moods[dateStr]!;
      // Mood/energy are stored on a 0–10 scale (see the daily check-in slider
      // min:0/max:10 and the daily_moods CHECK). High = upper band (>= 6),
      // low = lower band (< 4), 4–5 is neutral — the 0–10 analogue of the
      // legacy 60/40 split this code used when the scale was 0–100.
      final isHighMood = mood.moodScore >= 6;
      final isLowMood = mood.moodScore < 4;

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
}

final moodCorrelationProvider = Provider<List<MoodCorrelation>>(
  (ref) => computeMoodCorrelations(
    moods: ref.watch(dailyMoodsProvider),
    logs: ref.watch(habitLogsProvider),
  ),
);
