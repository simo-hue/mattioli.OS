import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/i18n/translations.g.dart';
import 'package:evolve_desktop/shared/widgets/evolve_dialog.dart';
import 'package:evolve_desktop/shared/widgets/evolve_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EvolveAlertDialog(
      icon: LucideIcons.keyRound,
      title: Text(t.settingsPage.changePassword),
      content: SizedBox(
        width: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.currentPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.newPassword,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t.settingsPage.confirmNewPassword,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: EvolveColors.destructive),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.settingsPage.cancel),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: EvolveSpinner(radius: 9),
                )
              : Text(t.settingsPage.updatePassword),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_currentController.text.isEmpty) {
      setState(() => _error = t.settingsPage.enterCurrentPassword);
      return;
    }
    if (_newController.text.length < 8) {
      setState(() => _error = t.settingsPage.newPasswordMinLength);
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = t.settingsPage.passwordsDontMatch);
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      await ref
          .read(desktopAuthControllerProvider.notifier)
          .updatePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = t.settingsPage.passwordUpdateFailed;
        });
      }
    }
  }
}
