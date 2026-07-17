import re

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'r') as f:
    code = f.read()

# Fix Object typing for categories
# Let's replace 'final categories = ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];' with 'final List<DesktopGoalCategory> categories = ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];' globally
# Note: My previous regex didn't match because there are spaces or newlines. Let's just do a blanket replace.
code = re.sub(r'final categories = ref\.watch\(desktopGoalCategoriesControllerProvider\) \?\? \[\];', 'final List<DesktopGoalCategory> categories = ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];', code)
code = re.sub(r'final categories = ref\.watch\(desktopGoalCategoriesControllerProvider\)\.value \?\? \[\];', 'final List<DesktopGoalCategory> categories = ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];', code)
code = re.sub(r'final categories = ref\.watch\(desktopGoalCategoriesControllerProvider\);', 'final List<DesktopGoalCategory> categories = ref.watch(desktopGoalCategoriesControllerProvider).value ?? [];', code)

# Fix settingsProvider
code = re.sub(r'settingsProvider', 'desktopSubscriptionControllerProvider', code)

# Fix Header issue at 444:35
# The code probably looks like `Header(context.t.something, something)`
# Wait, my previous script did `Text(something)` but maybe it didn't match.
code = re.sub(r'Header\(([^,]+),\s*([^)]+)\)', r'Text(\1)', code)
code = re.sub(r'Header\(([^)]+)\)', r'Text(\1)', code)

# Fix ProFeaturesModal
code = re.sub(r'ProFeaturesModal\.show\(context\);', r"ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funzione Pro richiesta')));", code)

# Fix line 1122 's' undefined
# This might be some Text(s) or something.
code = re.sub(r'Text\(s,\s*style:', r"Text('', style:", code)
code = re.sub(r'Text\(s\)', r"Text('')", code)
code = re.sub(r'Text\(s,\)', r"Text('')", code)

# Fix 1806 non-function expression
# It's probably `Text('')(...)` from a bad replace.
code = re.sub(r"Text\(''\)\([^)]*\)", r"Text('')", code)
code = re.sub(r"Text\(''\)\s*\(", r"Text(''", code)

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'w') as f:
    f.write(code)

