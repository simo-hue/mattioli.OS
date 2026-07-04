import re

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'r') as f:
    content = f.read()

# Make _FocusGoalsPanel a ConsumerWidget
if "class _FocusGoalsPanel extends StatelessWidget" in content:
    content = content.replace("class _FocusGoalsPanel extends StatelessWidget", "class _FocusGoalsPanel extends ConsumerWidget")
    
    # Replace build method signature
    content = content.replace(
        """  @override
  Widget build(BuildContext context) {""",
        """  @override
  Widget build(BuildContext context, WidgetRef ref) {"""
    )

    # Add Pro check
    old_button = """              builder: (context) => IconButton(
                onPressed: () => showEvolveDialog<void>(
                  context: context,
                  builder: (context) => const CreateGoalDialog(),
                ),"""
                
    new_button = """              builder: (context) => IconButton(
                onPressed: () {
                  final isPro = ref.read(desktopSubscriptionControllerProvider).value?.isActive ?? false;
                  if (!isPro && goals.length >= 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Limite di 100 obiettivi raggiunto. Passa a Pro per crearne altri.')),
                    );
                    return;
                  }
                  showEvolveDialog<void>(
                    context: context,
                    builder: (context) => const CreateGoalDialog(),
                  );
                },"""
                
    content = content.replace(old_button, new_button)

# Also import desktop_subscription_controller if needed
if "desktop_subscription_controller.dart" not in content:
    content = content.replace(
        "import 'package:evolve_desktop/features/auth/application/auth_controller.dart';",
        "import 'package:evolve_desktop/features/auth/application/auth_controller.dart';\nimport 'package:evolve_desktop/features/settings/application/desktop_subscription_controller.dart';"
    )

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'w') as f:
    f.write(content)

