import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _syncFromSupabase();
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
    } catch (e) {
      debugPrint('[DailyMoods] Sync error: $e');
    }
  }

  Future<void> saveMood(DateTime date, int mood, int energy) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      final response = await supabase.from('daily_moods').upsert({
        'user_id': user.id,
        'date': dateKey,
        'mood_score': mood,
        'energy_score': energy,
      }, onConflict: 'user_id, date').select().single();

      final updatedMood = DailyMood.fromJson(response);
      
      final newState = Map<String, DailyMood>.from(state);
      newState[dateKey] = updatedMood;
      state = newState;
    } catch (e) {
      debugPrint('[DailyMoods] Save error: $e');
    }
  }
}

final dailyMoodsProvider = NotifierProvider<DailyMoodsNotifier, DailyMoodsMap>(DailyMoodsNotifier.new);
