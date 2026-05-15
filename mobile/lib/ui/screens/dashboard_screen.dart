import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/settings_provider.dart';
import '../../providers/shared_prefs_provider.dart';

import '../../core/localization.dart';

import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/protocollo_panel.dart';
import '../widgets/view_tab_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/habit_calendar_widget.dart';
import '../widgets/habit_management_modal.dart';
import '../widgets/weekly_view_widget.dart';
import '../widgets/yearly_view_widget.dart';
import '../widgets/life_view_widget.dart';
import 'statistics_screen.dart';
import 'macro_goals_screen.dart';
import 'profile_screen.dart';
import '../../core/haptics.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/app_logger.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _selectedNavIndex = 1; // Starts on Home (now at index 1)
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isBiometricAuthenticated = true;

  final GlobalKey _checkInKey = GlobalKey();
  final GlobalKey _aiChatKey = GlobalKey();
  final GlobalKey _manageHabitsKey = GlobalKey();
  final GlobalKey _viewTabKey = GlobalKey();
  final GlobalKey _calendarBoxKey = GlobalKey();
  final GlobalKey _addHabitKey = GlobalKey();
  final GlobalKey _statsNavKey = GlobalKey();
  final GlobalKey _homeNavKey = GlobalKey();
  final GlobalKey _goalsNavKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedNavIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Check profile name after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileName();
      _checkTutorial();
    });
  }

  void _checkTutorial() {
    final hasSeenTutorial = ref.read(tutorialProvider);
    if (!hasSeenTutorial && mounted && _isBiometricAuthenticated) {
      _showWelcomeScreen();
    }
  }

  void _showWelcomeScreen() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.sparkles,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "Benvenuto in Growth",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Potrebbe essere uno STEP di NON RITORNO... Prima di iniziare però bisogna fare un tour per mostrarti come sfruttare al massimo l'applicazione.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref.hapticMedium();
                        Navigator.pop(context);
                        _showTutorial();
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Inizia il Tour',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEndTutorialScreen() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: FadeTransition(
            opacity: animation,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.rocket,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      "Sei pronto!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Il viaggio inizia ora. Dai il massimo!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref.hapticMedium();
                        ref.read(tutorialProvider.notifier).setTutorialSeen(true);
                        Navigator.pop(context);
                        _onItemTapped(1); // Go to Home
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Inizia',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTutorialContent(
    String title,
    String description,
    TutorialCoachMarkController controller, {
    bool isFirst = false,
    bool isLast = false,
    VoidCallback? onNextPressed,
    String? nextButtonText,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), 
          width: 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.info, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: context.appColors.foreground,
                  fontSize: 18.0,
                  fontFamily: 'Inter',
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          Text(
            description,
            style: TextStyle(
              color: context.appColors.mutedForeground,
              fontFamily: 'Inter',
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirst)
                TextButton(
                  onPressed: () {
                    ref.hapticSelection();
                    controller.previous();
                  },
                  child: Text("Indietro", style: TextStyle(color: context.appColors.mutedForeground, fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox.shrink(),
              ElevatedButton(
                onPressed: () {
                  ref.hapticSelection();
                  if (onNextPressed != null) {
                    onNextPressed();
                  } else if (isLast) {
                    controller.skip();
                  } else {
                    controller.next();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(nextButtonText ?? (isLast ? "Fine" : "Avanti"), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTutorial() {
    TutorialCoachMark? tutorial;
    List<TargetFocus> targets = [
      TargetFocus(
        identify: "Daily Check-in",
        keyTarget: _checkInKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Daily Check-in",
                "Qui puoi registrare il tuo stato d'animo quotidiano per tracciare il tuo benessere nel tempo e soprattutto correlarlo con il completamento dei tuoi obiettivi.",
                controller,
                isFirst: true,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "AI Chat",
        keyTarget: _aiChatKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "AI Chat",
                "Il tuo assistente personale. Chiedi consigli sulle tue abitudini. Lui è il tuo coach.",
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Gestione Abitudini",
        keyTarget: _manageHabitsKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Gestione Abitudini",
                "Aggiungi, modifica o elimina le tue abitudini quotidiane che vuoi rispettare in modo semplice e veloce.",
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Viste Calendario",
        keyTarget: _viewTabKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Viste Calendario",
                "Naviga tra le diverse visualizzazioni per vedere i tuoi progressi con varie alternative.",
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Calendario Box",
        keyTarget: _calendarBoxKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Calendario",
                "Basta cliccare su un giorno per visualizzare le abitudini giornaliere e spuntarle.",
                controller,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Obiettivi Nav",
        keyTarget: _goalsNavKey,
        enableTargetTab: false,
        enableOverlayTab: false,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTutorialContent(
                "Passiamo agli Obiettivi",
                "La pagina dove puoi gestire i tuoi obiettivi a lungo termine e le relative performance.",
                controller,
                isLast: true,
                nextButtonText: "Vai agli Obiettivi",
                onNextPressed: () {
                  controller.skip();
                  ref.read(tutorialProvider.notifier).setTutorialSeen(true);
                  _onItemTapped(2); // Change tab to MacroGoalsScreen
                },
              );
            },
          ),
        ],
      ),
    ];

    tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        ref.read(tutorialProvider.notifier).setTutorialSeen(true);
      },
      onSkip: () {
        ref.read(tutorialProvider.notifier).setTutorialSeen(true);
        return true;
      },
    );
    tutorial.show(context: context);
  }

  Future<void> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          setState(() => _isBiometricAuthenticated = true);
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Sblocca l\'app per continuare',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        if (mounted) {
          setState(() => _isBiometricAuthenticated = true);
        }
      }
    } catch (e, stack) {
      AppLogger.error('Biometric authentication error', e, stack);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _checkProfileName() {
    final userProfile = ref.read(userProfileProvider);
    if (userProfile.firstName == null || userProfile.firstName!.isEmpty) {
      _showNameDialog();
    }
  }

  void _showNameDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // User must enter a name
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Benvenuto in Growth!',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.appColors.foreground,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Per iniziare, come possiamo chiamarti?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: context.appColors.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Il tuo nome',
                      labelStyle: TextStyle(color: context.appColors.mutedForeground, fontSize: 14),
                      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                      filled: true,
                      fillColor: context.appColors.background.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.appColors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                      ),
                    ),
                    style: TextStyle(color: context.appColors.foreground, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 24),
                  
                  // Action Button
                  GestureDetector(
                    onTap: () async {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        ref.hapticMedium();
                        final success = await ref.read(authProvider.notifier).updateProfileName(name);
                        if (!context.mounted) return;
                        if (success) {
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Errore durante il salvataggio. Riprova.')),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Inizia ora',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onItemTapped(int index) {
    if ((index - _selectedNavIndex).abs() > 1) {
       _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
    setState(() => _selectedNavIndex = index);
    ref.hapticSelection();
  }

  @override
  Widget build(BuildContext context) {
    final currentView = ref.watch(calendarViewProvider);
    final biometricLockAsync = ref.watch(biometricLockProvider);
    
    // Auto-authenticate when lock is active
    ref.listen(biometricLockProvider, (prev, next) {
      next.whenData((isLocked) {
        if (isLocked && !_isBiometricAuthenticated) {
          _authenticate();
        }
      });
    });

    // Listen for tutorial reset
    ref.listen<bool>(tutorialProvider, (previous, next) {
      if (next == false && mounted && _isBiometricAuthenticated) {
        _showWelcomeScreen();
      }
    });

    if (biometricLockAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isLocked = biometricLockAsync.value ?? false;

    if (isLocked && !_isBiometricAuthenticated) {
      return Scaffold(
        backgroundColor: context.appColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'App Bloccata',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sblocca con i dati biometrici per continuare',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: context.appColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _authenticate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Riprova',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.appColors.background,
      // Custom app bar
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(64 + MediaQuery.of(context).padding.top),
        child: const _AppBar(),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: 3,
        onPageChanged: (index) {
          setState(() => _selectedNavIndex = index);
        },
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = (_pageController.page! - index).abs();
                // Custom curve for premium feel: scale from 1.0 to 0.95 and fade
                value = (1 - (value * 0.05)).clamp(0.9, 1.0);
              } else {
                // Initial state
                value = index == _selectedNavIndex ? 1.0 : 0.95;
              }
              
              return Opacity(
                opacity: ((value - 0.9) / 0.1).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: value,
                  child: child,
                ),
              );
            },
            child: _getPage(index, currentView),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedNavIndex,
        navKeys: [_statsNavKey, _homeNavKey, _goalsNavKey],
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomeBody(CalendarView currentView) {
    final habits = ref.watch(goalsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProtocolloPanel(
                  checkInKey: _checkInKey,
                  aiChatKey: _aiChatKey,
                  manageHabitsKey: _manageHabitsKey,
                ),
                const SizedBox(height: 20),
                ViewTabBar(key: _viewTabKey),
                const SizedBox(height: 12),
                Expanded(
                  child: habits.isEmpty && currentView != CalendarView.vita
                      ? _buildGlobalEmptyState()
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.02),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            key: _calendarBoxKey,
                            child: _buildViewContent(currentView),
                          ),
                        ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalEmptyState() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      decoration: AppTheme.glassPanelDecoration(context, radius: 14),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.sparkles,
              size: 40,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'La tua tela è vuota',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.appColors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Crea la tua prima abitudine per iniziare a tracciare i tuoi progressi e costruire la tua routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: context.appColors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            key: _addHabitKey,
            onPressed: () {
              ref.hapticMedium();
              HabitManagementModal.show(context);
            },
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Aggiungi Abitudine',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewContent(CalendarView view) {
    switch (view) {
      case CalendarView.month:
        return const HabitCalendarWidget(key: ValueKey('month'));
      case CalendarView.week:
        return const WeeklyViewWidget(key: ValueKey('week'));
      case CalendarView.year:
        return const YearlyViewWidget(key: ValueKey('year'));
      case CalendarView.vita:
        return const LifeViewWidget(key: ValueKey('vita'));
    }
  }

  Widget _getPage(int index, CalendarView currentView) {
    switch (index) {
      case 0:
        return StatisticsScreen(onFinishTutorial: () {
          _showEndTutorialScreen();
        });
      case 1:
        return _HomeTabWrapper(child: _buildHomeBody(currentView));
      case 2:
        return MacroGoalsScreen(
          statsNavKey: _statsNavKey,
          onFinishTutorial: () {
            _onItemTapped(0); // Move to Stats
          },
        );
      default:
        return const SizedBox();
    }
  }
}

class _HomeTabWrapper extends StatefulWidget {
  final Widget child;
  const _HomeTabWrapper({required this.child});

  @override
  State<_HomeTabWrapper> createState() => _HomeTabWrapperState();
}

class _HomeTabWrapperState extends State<_HomeTabWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

class _AppBar extends ConsumerWidget {
  const _AppBar();

  String _getGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.translate('Buongiorno');
    if (hour < 18) return context.l10n.translate('Buon pomeriggio');
    return context.l10n.translate('Buonasera');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final greeting = _getGreeting(context);
    final formattedDate = DateFormat('EEEE, d MMMM', context.l10n.language == 'Italiano' ? 'it_IT' : 'en_US').format(DateTime.now());
    
    // Capitalize first letter of date
    final displayDate = formattedDate.isNotEmpty 
        ? formattedDate[0].toUpperCase() + formattedDate.substring(1)
        : formattedDate;

    final userProfile = ref.watch(userProfileProvider);
    final displayName = userProfile.firstName ?? userProfile.displayName;
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: context.appColors.background.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: context.appColors.border.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 64, // Fixed height for content area
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, $displayName',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.appColors.foreground,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.appColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              displayDate,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: context.appColors.mutedForeground,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Profile & Action Hub
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          ref.hapticMedium();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPro ? const Color(0xFFEAB308) : primaryColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.appColors.card,
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: (userProfile.avatarUrl != null
                                    ? NetworkImage(userProfile.avatarUrl!)
                                    : const AssetImage('assets/images/default_avatar.png')) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


