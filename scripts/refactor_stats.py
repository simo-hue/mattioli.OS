import re

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'r') as f:
    code = f.read()

# 1. Imports
code = re.sub(r"import '../../../core/theme.dart';", "import 'package:evolve_desktop/app/theme/evolve_theme.dart';", code)
code = re.sub(r"import '../../../core/haptics.dart';", "import 'package:flutter/services.dart';", code)
code = re.sub(r"import '../../../models/macro_goal.dart';", "import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';", code)
code = re.sub(r"import '../../../providers/settings_provider.dart';", "import 'package:evolve_desktop/features/settings/application/subscription_controller.dart';", code)
code = re.sub(r"import '../../../providers/macro_goals_provider.dart';", "import 'package:evolve_desktop/features/dashboard/application/dashboard_controller.dart';", code)
code = re.sub(r"import '../../../providers/macro_goals_stats_provider.dart';", "import 'package:evolve_desktop/features/statistics/data/statistics_rpc_providers.dart';", code)
code = re.sub(r"import '../../../providers/macro_goal_categories_provider.dart';", "import 'package:evolve_desktop/features/goals/application/goal_categories_controller.dart';", code)
code = re.sub(r"import '../pro_features_modal.dart';", "", code)
code = re.sub(r"import '../../../i18n/translations.g.dart';", "", code)

# 2. Classes and methods
code = re.sub(r"MacroGoalsStatsView", "GoalsStatsView", code)
code = re.sub(r"MacroGoal", "DashboardGoal", code)

# 3. Theme
code = re.sub(r"context\.appColors", "context.evolveColors", code)
code = re.sub(r"context\.evolveColors\.card", "context.evolveColors.panel", code)
code = re.sub(r"context\.evolveColors\.foreground", "context.evolveColors.foreground", code)

# 4. Providers
code = re.sub(r"ref\.watch\(macroGoalsProvider\)\.goals", "ref.watch(dashboardControllerProvider).goals", code)
code = re.sub(r"ref\.watch\(macroGoalCategoriesProvider\)\.value", "ref.watch(desktopGoalCategoriesControllerProvider)", code)
code = re.sub(r"ref\.watch\(settingsProvider\)", "ref.watch(desktopSubscriptionControllerProvider)", code)
code = re.sub(r"macroGoalsStatsProvider", "macroGoalsStatsRpcProvider", code)

# 5. Translations
# We will do a generic replacement for context.t...
code = re.sub(r"context\.t\.macroGoals\.types\.lifetime", "'Lifetime'", code)
code = re.sub(r"context\.t\.macroGoals\.types\.annual", "'Annuale'", code)
code = re.sub(r"context\.t\.macroGoals\.types\.quarterly", "'Trimestrale'", code)
code = re.sub(r"context\.t\.macroGoals\.types\.monthly", "'Mensile'", code)
code = re.sub(r"context\.t\.macroGoals\.types\.weekly", "'Settimanale'", code)
code = re.sub(r"context\.t\.common\.status\.error", "'Errore'", code)
code = re.sub(r"context\.t\.macroGoals\.strength", "'Punto di forza'", code)
code = re.sub(r"context\.t\.common\.ofCompletion", "'di completamento'", code)
code = re.sub(r"context\.t\.macroGoals\.bestMonth", "'Mese migliore'", code)
code = re.sub(r"context\.t\.common\.none", "'Nessuno'", code)
code = re.sub(r"context\.t\.macroGoals\.successRate2", "'success rate'", code)
code = re.sub(r"context\.t\.macroGoals\.effectiveType", "'Tipo più efficace'", code)
code = re.sub(r"context\.t\.common\.total", "'Totale'", code)
code = re.sub(r"context\.t\.common\.completed", "'Completati'", code)
code = re.sub(r"context\.t\.macroGoals\.success2", "'Successo'", code)
code = re.sub(r"context\.t\.macroGoals\.trend", "'Trend'", code)
code = re.sub(r"context\.t\.statistics\.growth", "'Crescita'", code)
code = re.sub(r"context\.t\.statistics\.decline", "'Declino'", code)
code = re.sub(r"context\.t\.macroGoals\.historicalTotal", "'Totale Storico'", code)
code = re.sub(r"context\.t\.macroGoals\.from_", "'Dal'", code)
code = re.sub(r"context\.t\.macroGoals\.globalSuccess", "'Successo Globale'", code)
code = re.sub(r"context\.t\.macroGoals\.completedGoals", "'obiettivi completati'", code)
code = re.sub(r"context\.t\.macroGoals\.bestYear", "'Anno Migliore'", code)
code = re.sub(r"context\.t\.macroGoals\.completion", "'completamento'", code)
code = re.sub(r"context\.t\.macroGoals\.mostProductiveYear", "'Anno Più Produttivo'", code)
code = re.sub(r"context\.t\.macroGoals\.totalGoals", "'obiettivi totali'", code)
code = re.sub(r"context\.t\.macroGoals\.allYears", "'Tutti gli anni'", code)

code = re.sub(r"context\.t\.macroGoals\.progression", "'Progressione'", code)
code = re.sub(r"context\.t\.macroGoals\.activityHistory", "'Storico Attività'", code)
code = re.sub(r"context\.t\.macroGoals\.successByPeriod", "'Successo per periodo'", code)
code = re.sub(r"context\.t\.macroGoals\.performance", "'Performance'", code)
code = re.sub(r"context\.t\.macroGoals\.goals", "'obiettivi'", code)
code = re.sub(r"context\.t\.macroGoals\.successByGoalType", "'Successo per tipo di obiettivo'", code)
code = re.sub(r"context\.t\.macroGoals\.focusDistribution", "'Distribuzione Focus'", code)
code = re.sub(r"context\.t\.macroGoals\.activityByQuarter", "'Attività per Trimestre'", code)
code = re.sub(r"context\.t\.macroGoals\.seasonality", "'Stagionalità'", code)
code = re.sub(r"context\.t\.macroGoals\.interestEvolution", "'Evoluzione Interessi'", code)
code = re.sub(r"context\.t\.macroGoals\.selectYear", "'Seleziona Anno'", code)
code = re.sub(r"context\.t\.macroGoals\.allTime", "'Sempre'", code)

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'w') as f:
    f.write(code)

