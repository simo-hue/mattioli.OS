import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/features/auth/application/auth_controller.dart';
import 'package:evolve_desktop/shared/widgets/evolve_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum _AuthMode { signIn, signUp, resetPassword }

class DesktopAuthPage extends ConsumerStatefulWidget {
  const DesktopAuthPage({super.key});

  @override
  ConsumerState<DesktopAuthPage> createState() => _DesktopAuthPageState();
}

class _DesktopAuthPageState extends ConsumerState<DesktopAuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  _AuthMode _mode = _AuthMode.signIn;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(desktopAuthControllerProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: EvolvePanel(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 38,
                      color: EvolveColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      switch (_mode) {
                        _AuthMode.signIn => 'Accedi a Evolve',
                        _AuthMode.signUp => 'Crea il tuo account',
                        _AuthMode.resetPassword => 'Recupera password',
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    if (_mode == _AuthMode.signUp) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Nome'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value?.contains('@') ?? false
                          ? null
                          : 'Inserisci un indirizzo email valido.',
                    ),
                    if (_mode != _AuthMode.resetPassword) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => (value?.length ?? 0) >= 8
                            ? null
                            : 'Usa almeno 8 caratteri.',
                      ),
                    ],
                    if (auth.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        auth.errorMessage!,
                        style: const TextStyle(color: EvolveColors.rose),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _mode == _AuthMode.resetPassword
                                  ? 'Invia link di recupero'
                                  : _mode == _AuthMode.signUp
                                  ? 'Registrati'
                                  : 'Accedi',
                            ),
                    ),
                    const SizedBox(height: 10),
                    if (_mode == _AuthMode.signIn)
                      TextButton(
                        onPressed: () =>
                            setState(() => _mode = _AuthMode.resetPassword),
                        child: const Text('Password dimenticata?'),
                      ),
                    TextButton(
                      onPressed: () => setState(() {
                        _mode = _mode == _AuthMode.signUp
                            ? _AuthMode.signIn
                            : _AuthMode.signUp;
                      }),
                      child: Text(
                        _mode == _AuthMode.signUp
                            ? 'Hai gia un account? Accedi'
                            : 'Non hai un account? Registrati',
                      ),
                    ),
                    TextButton(
                      onPressed: _openPrivacyPolicy,
                      child: const Text('Privacy policy'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = ref.read(desktopAuthControllerProvider.notifier);
    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await auth.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        case _AuthMode.signUp:
          final requiresConfirmation = await auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text,
          );
          if (!mounted || !requiresConfirmation) return;
          _showMessage('Controlla la tua email per confermare l’account.');
          setState(() => _mode = _AuthMode.signIn);
        case _AuthMode.resetPassword:
          await auth.sendPasswordReset(_emailController.text.trim());
          if (!mounted) return;
          _showMessage('Link di recupero inviato.');
          setState(() => _mode = _AuthMode.signIn);
      }
    } catch (_) {}
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse('https://simo-hue.github.io/evolve/privacy.html'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
