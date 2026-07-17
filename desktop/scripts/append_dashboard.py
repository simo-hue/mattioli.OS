import re

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'r') as f:
    content = f.read()

# Add the import if not present
if "import 'package:evolve_desktop/core/app_bootstrap.dart';" not in content:
    content = content.replace(
        "import 'package:evolve_desktop/features/auth/application/auth_controller.dart';",
        "import 'package:evolve_desktop/features/auth/application/auth_controller.dart';\nimport 'package:evolve_desktop/core/app_bootstrap.dart';"
    )

dialog_code = """
class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog();

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(WidgetRef ref) {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    ref.read(sharedPreferencesProvider)?.setString('private_profile_name', name);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        return EvolveAlertDialog(
          icon: Icons.person_outline,
          title: const Text('Come ti chiami?'),
          subtitle: 'Inserisci il tuo nome per personalizzare la dashboard.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Es. Simo',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _submit(ref),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _submit(ref),
                  child: const Text('Salva e continua'),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}
"""

if "_NamePromptDialog" not in content:
    content += "\n" + dialog_code

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'w') as f:
    f.write(content)

