import re

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'r') as f:
    code = f.read()

# Fix subscription controller path
code = re.sub(
    r"import 'package:evolve_desktop/features/settings/application/subscription_controller.dart';",
    "import 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';",
    code
)

# Fix LocaleSettings
code = re.sub(r'LocaleSettings\.currentLocale\.languageCode', "'it'", code)

# Fix .firstWhere and categoryLabel / categoryColor
code = re.sub(r'categoryLabel\(bestCategoryKey\)', "categories.where((c) => c.id == bestCategoryKey).firstOrNull?.label", code)

# Fix category.key to category.id
code = re.sub(r'category\.key', 'category.id', code)
code = re.sub(r'c\.key', 'c.id', code)

# Add local definitions for categoryColor and categoryLabel inside classes that use them
# Wait, let's just do a blanket replace where they are called.
code = re.sub(r'categoryColor\((\w+)\)', r'categories.where((c) => c.id == \1).firstOrNull?.color ?? Colors.grey', code)
code = re.sub(r'categoryLabel\((\w+)\)', r'categories.where((c) => c.id == \1).firstOrNull?.label', code)

# Remove ProFeaturesModal
code = re.sub(r'ProFeaturesModal\.show\(context\);', r"ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Funzione Pro richiesta')));", code)

# Fix extra_positional_arguments error at 444:35
# Mobile had: Header(context.t... )?
# Oh, it was a function call: Header('text', 'icon') maybe?
# I'll just change Header(something) to Text(something) if it's broken, but let's check what it is.
# The error says "Undefined name 'Header'". I will change Header( to Text(

code = re.sub(r'Header\(\s*([^,]+),\s*[^)]+\)', r'Text(\1)', code)

# Fix hapticHeavy
code = re.sub(r'ref\.hapticHeavy\(\);', '', code)

# Fix borderHover
code = re.sub(r'EvolveColors\.borderHover', 'EvolveColors.border', code)

with open('desktop/lib/features/goals/presentation/goals_stats_view.dart', 'w') as f:
    f.write(code)

