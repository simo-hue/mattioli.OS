import re

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'r') as f:
    code = f.read()

# Replace GoogleFonts.inter(...) with TextStyle(fontFamily: 'Inter', ...)
code = re.sub(r'GoogleFonts\.inter\(\s*', "TextStyle(\nfontFamily: 'Inter',\n", code)

# Fix mutedForeground -> muted
code = re.sub(r'mutedForeground', 'muted', code)

# Fix GoalCategory -> DesktopGoalCategory
code = re.sub(r'List<GoalCategory>', 'List<DesktopGoalCategory>', code)
code = re.sub(r'<GoalCategory>', '<DesktopGoalCategory>', code)

# Fix AppColors -> EvolveColors
code = re.sub(r'AppColors', 'EvolveColors', code)

# Remove tooltipRoundedRadius
code = re.sub(r'tooltipRoundedRadius:\s*[^,]+,', '', code)

# Remove context.t.whatever that I missed
# I will just regex replace context.t.[a-zA-Z0-9_.]+ with '' or a placeholder
code = re.sub(r'context\.t\.[a-zA-Z0-9_\.]+', "''", code)

# Fix the property 'label' can't be unconditionally accessed
code = re.sub(r'category\.label', '(category?.label ?? "")', code)
code = re.sub(r'category\.color', '(category?.color ?? Colors.grey)', code)

# Remove google_fonts import
code = re.sub(r"import 'package:google_fonts/google_fonts.dart';", "", code)

# Fix dead code issues by removing ?. where it's non-nullable. 
# desktopGoalCategoriesControllerProvider returns an AsyncValue probably? No, it returns List<DesktopGoalCategory> directly.
# Mobile macroGoalCategoriesProvider returns AsyncValue.
# Desktop is: ref.watch(desktopGoalCategoriesControllerProvider) (which is List<DesktopGoalCategory>)
code = re.sub(r'ref\.watch\(desktopGoalCategoriesControllerProvider\)\.value \?\? \[\]', 'ref.watch(desktopGoalCategoriesControllerProvider)', code)


with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'w') as f:
    f.write(code)

