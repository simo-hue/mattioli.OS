import re

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'r') as f:
    content = f.read()

# Replace ConsumerWidget with ConsumerStatefulWidget
old_class = """class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {"""

new_class = """class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isRunningStartupOnboardingFlow = false;
  bool _isNameDialogOpen = false;
  bool _isWelcomeDialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupOnboardingFlow();
    });
  }

  Future<void> _runStartupOnboardingFlow() async {
    if (_isRunningStartupOnboardingFlow || !mounted) return;
    _isRunningStartupOnboardingFlow = true;
    try {
      final isProfileReady = await _ensureProfileNameReady();
      if (!isProfileReady || !mounted) return;
      _checkTutorial();
    } finally {
      _isRunningStartupOnboardingFlow = false;
    }
  }

  Future<bool> _ensureProfileNameReady() async {
    final authState = ref.read(desktopAuthControllerProvider);
    if (authState.user != null) return true; // Logged in user
    
    // Privacy mode
    final prefs = ref.read(sharedPreferencesProvider);
    final hasName = prefs?.getString('private_profile_name') != null;
    if (hasName) return true;

    return _showNameDialog();
  }

  Future<bool> _showNameDialog() async {
    if (_isNameDialogOpen || !mounted) return false;
    _isNameDialogOpen = true;
    
    bool result = false;
    try {
      result = await showEvolveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _NamePromptDialog(),
      ) ?? false;
    } finally {
      _isNameDialogOpen = false;
    }
    return result;
  }

  void _checkTutorial() {
    final prefs = ref.read(sharedPreferencesProvider);
    final hasSeenTutorial = prefs?.getBool('has_seen_tutorial') ?? false;
    
    if (!hasSeenTutorial && mounted && !_isWelcomeDialogOpen && !_isNameDialogOpen) {
      _showWelcomeScreen();
    }
  }

  Future<void> _showWelcomeScreen() async {
    if (_isWelcomeDialogOpen || !mounted) return;
    _isWelcomeDialogOpen = true;
    
    try {
      await showEvolveDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => EvolveAlertDialog(
          icon: Icons.auto_awesome,
          title: const Text('Benvenuto in Evolve'),
          subtitle: 'Inizia il tuo percorso di crescita personale.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Questa applicazione ti aiuta a costruire buone abitudini e raggiungere i tuoi obiettivi a lungo termine.'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    ref.read(sharedPreferencesProvider)?.setBool('has_seen_tutorial', true);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Inizia il tour'),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _isWelcomeDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {"""

content = content.replace(old_class, new_class)

# The end of build method needs closing brace.
# Wait, let's just do it with a more precise replace.

with open('desktop/lib/features/dashboard/presentation/dashboard_page.dart', 'w') as f:
    f.write(content)

