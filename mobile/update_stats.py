import re

with open('lib/core/private_local_database.dart', 'r') as f:
    content = f.read()

# We need to replace macroGoalsStats(String year)
dart_code = """
  Future<Map<String, dynamic>> macroGoalsStats(String year) async {
    final allGoals = await loadMacroGoals();
    
    if (year == 'all') {
      final totalGoals = allGoals.length;
      final completedGoals = allGoals.where((g) => g.status == GoalStatus.completed).length;
      final successRate = totalGoals > 0 ? (completedGoals / totalGoals * 100).round() : 0;
      
      final yearStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.year != null) {
          yearStats.putIfAbsent(g.year!, () => {'total': 0, 'completed': 0});
          yearStats[g.year!]!['total'] = yearStats[g.year!]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            yearStats[g.year!]!['completed'] = yearStats[g.year!]!['completed']! + 1;
          }
        }
      }
      
      int? bestYear;
      int bestYearRate = -1;
      int? mostProdYear;
      int mostProdCount = -1;
      
      final yearProgression = <Map<String, dynamic>>[];
      final sortedYears = yearStats.keys.toList()..sort();
      for (final y in sortedYears) {
        final t = yearStats[y]!['total']!;
        final c = yearStats[y]!['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        
        if (r > bestYearRate || (r == bestYearRate && t > (yearStats[bestYear]?['total'] ?? 0))) {
          bestYearRate = r;
          bestYear = y;
        }
        if (c > mostProdCount) {
          mostProdCount = c;
          mostProdYear = y;
        }
        yearProgression.add({
          'year': y,
          'active': allGoals.where((g) => g.year == y && g.status == GoalStatus.active).length,
          'failed': allGoals.where((g) => g.year == y && g.status == GoalStatus.failed).length,
          'completed': c,
          'total': t,
        });
      }
      
      final categoryStats = <String, Map<String, int>>{};
      for (final g in allGoals) {
        final cat = g.categoryId ?? g.categoryKey;
        if (cat != null) {
          categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
          categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            categoryStats[cat]!['completed'] = categoryStats[cat]!['completed']! + 1;
          }
        }
      }
      
      final categoryPerformance = categoryStats.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {
          'category': e.key,
          'rate': t > 0 ? (c / t * 100).round() : 0,
        };
      }).toList();
      
      final typeDistribution = <String, int>{};
      for (final g in allGoals) {
        typeDistribution.update(g.type.name, (v) => v + 1, ifAbsent: () => 1);
      }
      
      final seasonalityStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.quarter != null) {
          seasonalityStats.putIfAbsent(g.quarter!, () => {'active': 0, 'failed': 0, 'completed': 0});
          if (g.status == GoalStatus.active) seasonalityStats[g.quarter!]!['active'] = seasonalityStats[g.quarter!]!['active']! + 1;
          if (g.status == GoalStatus.failed) seasonalityStats[g.quarter!]!['failed'] = seasonalityStats[g.quarter!]!['failed']! + 1;
          if (g.status == GoalStatus.completed) seasonalityStats[g.quarter!]!['completed'] = seasonalityStats[g.quarter!]!['completed']! + 1;
        }
      }
      final seasonality = seasonalityStats.entries.map((e) => {
        'quarter': e.key,
        'active': e.value['active'],
        'failed': e.value['failed'],
        'completed': e.value['completed'],
      }).toList()..sort((a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int));
      
      final monthlyStats = <int, Map<String, int>>{};
      for (final g in allGoals) {
        if (g.month != null) {
          monthlyStats.putIfAbsent(g.month!, () => {'total': 0, 'completed': 0});
          monthlyStats[g.month!]!['total'] = monthlyStats[g.month!]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            monthlyStats[g.month!]!['completed'] = monthlyStats[g.month!]!['completed']! + 1;
          }
        }
      }
      final monthlyHistory = monthlyStats.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {
          'month': e.key,
          'rate': t > 0 ? (c / t * 100).round() : 0,
        };
      }).toList()..sort((a, b) => (a['month'] as int).compareTo(b['month'] as int));
      
      final interestEvolution = <Map<String, dynamic>>[];
      for (final y in sortedYears) {
        final catsForYear = <String, int>{};
        for (final g in allGoals.where((g) => g.year == y)) {
          final cat = g.categoryId ?? g.categoryKey;
          if (cat != null) {
            catsForYear.update(cat, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        interestEvolution.add({
          'year': y,
          'categories': catsForYear,
        });
      }
      
      return {
        'total_goals': totalGoals,
        'completed_goals': completedGoals,
        'success_rate': successRate,
        'best_year': bestYear,
        'best_year_rate': bestYearRate,
        'most_productive_year': mostProdYear,
        'most_productive_count': mostProdCount,
        'year_progression': yearProgression,
        'category_performance': categoryPerformance,
        'type_distribution': typeDistribution,
        'seasonality': seasonality,
        'monthly_history': monthlyHistory,
        'interest_evolution': interestEvolution,
      };
    } else {
      final yInt = int.tryParse(year);
      final yearGoals = allGoals.where((g) => g.year == yInt).toList();
      
      final totalGoals = yearGoals.length;
      final completedGoals = yearGoals.where((g) => g.status == GoalStatus.completed).length;
      final successRate = totalGoals > 0 ? (completedGoals / totalGoals * 100).round() : 0;
      
      final categoryStats = <String, Map<String, int>>{};
      for (final g in yearGoals) {
        final cat = g.categoryId ?? g.categoryKey;
        if (cat != null) {
          categoryStats.putIfAbsent(cat, () => {'total': 0, 'completed': 0});
          categoryStats[cat]!['total'] = categoryStats[cat]!['total']! + 1;
          if (g.status == GoalStatus.completed) {
            categoryStats[cat]!['completed'] = categoryStats[cat]!['completed']! + 1;
          }
        }
      }
      
      String? bestCategory;
      int bestCategoryRate = -1;
      int maxCatTotal = -1;
      for (final e in categoryStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestCategoryRate || (r == bestCategoryRate && t > maxCatTotal)) {
          bestCategoryRate = r;
          bestCategory = e.key;
          maxCatTotal = t;
        }
      }
      
      final monthStats = <int, Map<String, int>>{};
      for (final g in yearGoals) {
        if (g.month != null) {
          monthStats.putIfAbsent(g.month!, () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0});
          monthStats[g.month!]!['total'] = monthStats[g.month!]!['total']! + 1;
          if (g.status == GoalStatus.completed) monthStats[g.month!]!['completed'] = monthStats[g.month!]!['completed']! + 1;
          if (g.status == GoalStatus.active) monthStats[g.month!]!['active'] = monthStats[g.month!]!['active']! + 1;
          if (g.status == GoalStatus.failed) monthStats[g.month!]!['failed'] = monthStats[g.month!]!['failed']! + 1;
        }
      }
      
      int? bestMonth;
      int bestMonthRate = -1;
      int maxMonthTotal = -1;
      for (final e in monthStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestMonthRate || (r == bestMonthRate && t > maxMonthTotal)) {
          bestMonthRate = r;
          bestMonth = e.key;
          maxMonthTotal = t;
        }
      }
      
      final typeStats = <String, Map<String, int>>{};
      for (final g in yearGoals) {
        typeStats.putIfAbsent(g.type.name, () => {'total': 0, 'completed': 0});
        typeStats[g.type.name]!['total'] = typeStats[g.type.name]!['total']! + 1;
        if (g.status == GoalStatus.completed) typeStats[g.type.name]!['completed'] = typeStats[g.type.name]!['completed']! + 1;
      }
      
      String? bestType;
      int bestTypeRate = -1;
      int maxTypeTotal = -1;
      for (final e in typeStats.entries) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        final r = t > 0 ? (c / t * 100).round() : 0;
        if (r > bestTypeRate || (r == bestTypeRate && t > maxTypeTotal)) {
          bestTypeRate = r;
          bestType = e.key;
          maxTypeTotal = t;
        }
      }
      
      final quarterlyStats = <int, Map<String, int>>{};
      for (final g in yearGoals) {
        if (g.quarter != null) {
          quarterlyStats.putIfAbsent(g.quarter!, () => {'total': 0, 'completed': 0, 'active': 0, 'failed': 0});
          quarterlyStats[g.quarter!]!['total'] = quarterlyStats[g.quarter!]!['total']! + 1;
          if (g.status == GoalStatus.completed) quarterlyStats[g.quarter!]!['completed'] = quarterlyStats[g.quarter!]!['completed']! + 1;
          if (g.status == GoalStatus.active) quarterlyStats[g.quarter!]!['active'] = quarterlyStats[g.quarter!]!['active']! + 1;
          if (g.status == GoalStatus.failed) quarterlyStats[g.quarter!]!['failed'] = quarterlyStats[g.quarter!]!['failed']! + 1;
        }
      }
      final quarterlyActivity = quarterlyStats.entries.map((e) => {
        'quarter': e.key,
        'total': e.value['total'],
        'completed': e.value['completed'],
        'active': e.value['active'],
        'failed': e.value['failed'],
      }).toList()..sort((a, b) => (a['quarter'] as int).compareTo(b['quarter'] as int));
      
      final monthlyComposed = <Map<String, dynamic>>[];
      final cumulativeMonthly = <Map<String, dynamic>>[];
      int cumTotal = 0;
      int cumCompleted = 0;
      for (int m = 1; m <= 12; m++) {
        final s = monthStats[m] ?? {'total': 0, 'completed': 0, 'active': 0, 'failed': 0};
        monthlyComposed.add({
          'month': m,
          'total': s['total'],
          'completed': s['completed'],
          'active': s['active'],
          'failed': s['failed'],
        });
        cumTotal += s['total']!;
        cumCompleted += s['completed']!;
        cumulativeMonthly.add({
          'month': m,
          'total': cumTotal,
          'completed': cumCompleted,
        });
      }
      
      final categoryRates = categoryStats.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {
          'category': e.key,
          'rate': t > 0 ? (c / t * 100).round() : 0,
        };
      }).toList();
      
      final categoryDistribution = categoryStats.entries.map((e) => {
        'category': e.key,
        'count': e.value['total'],
      }).toList();
      
      return {
        'total_goals': totalGoals,
        'completed_goals': completedGoals,
        'success_rate': successRate,
        'best_category': bestCategory,
        'best_category_rate': bestCategoryRate,
        'best_month': bestMonth,
        'best_month_rate': bestMonthRate,
        'best_type': bestType,
        'best_type_rate': bestTypeRate,
        'cumulative_monthly': cumulativeMonthly,
        'category_rates': categoryRates,
        'quarterly_activity': quarterlyActivity,
        'monthly_composed': monthlyComposed,
        'category_distribution': categoryDistribution,
      };
    }
  }
"""

start_str = "  Future<Map<String, dynamic>> macroGoalsStats(String year) async {"
end_str = "  Goal _goalFromRow(Map<String, Object?> row) {"

start_idx = content.find(start_str)
end_idx = content.find(end_str)

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + dart_code + "\n" + content[end_idx:]
    with open('lib/core/private_local_database.dart', 'w') as f:
        f.write(new_content)
    print("Successfully updated macroGoalsStats.")
else:
    print("Could not find start or end strings.")
