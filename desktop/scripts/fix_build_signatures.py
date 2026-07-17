import re

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'r') as f:
    content = f.read()

# Revert all to BuildContext context
content = content.replace("Widget build(BuildContext context, WidgetRef ref)", "Widget build(BuildContext context)")

# Only the ConsumerWidgets or ConsumerState should have the WidgetRef in the signature.
# Actually, in Riverpod, `ConsumerState` has a `ref` property, so its build method is JUST `Widget build(BuildContext context)`.
# ONLY `ConsumerWidget` has `Widget build(BuildContext context, WidgetRef ref)`.
# Let's see which classes are ConsumerWidget.
# _HabitPanel is ConsumerWidget? No, in my script I changed _FocusGoalsPanel to ConsumerWidget.
# Let's fix _FocusGoalsPanel to have WidgetRef.
content = re.sub(
    r'(class _FocusGoalsPanel extends ConsumerWidget \{.*?@override\s+Widget build\(BuildContext context)',
    r'\1, WidgetRef ref',
    content,
    flags=re.DOTALL
)

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'w') as f:
    f.write(content)
