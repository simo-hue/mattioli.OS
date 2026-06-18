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
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: json['date'] as String,
      moodScore: json['mood_score'] as int,
      energyScore: json['energy_score'] as int,
    );
  }
}
