import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../widgets/biometric_lock_gate.dart';


import '../../core/theme.dart';
import '../../providers/goal_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/data_mode.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/profile_avatar_image.dart';
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
import '../kit/evolve_button.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../providers/tutorial_provider.dart';
import '../../core/app_logger.dart';
import '../../i18n/translations.g.dart';

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

  final GlobalKey _checkInKey = GlobalKey();
  final GlobalKey _aiChatKey = GlobalKey();
  final GlobalKey _manageHabitsKey = GlobalKey();
  final GlobalKey _viewTabKey = GlobalKey();
  final GlobalKey _calendarBoxKey = GlobalKey();
  final GlobalKey _addHabitKey = GlobalKey();
  final GlobalKey _statsNavKey = GlobalKey();
  final GlobalKey _homeNavKey = GlobalKey();
  final GlobalKey _goalsNavKey = GlobalKey();
  bool _isRunningStartupOnboardingFlow = false;
  bool _isNameDialogOpen = false;
  bool _isWelcomeDialogOpen = false;
  bool _isDashboardTutorialShowing = false;
  Timer? _dashboardTutorialStartTimer;
  TutorialCoachMark? _dashboardTutorial;

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Profile setup must finish before any tutorial overlay is allowed to run.
    // Don't start it behind the biometric lock — the build() listener resumes
    // the flow once the lock overlay is dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(biometricLockActiveProvider)) {
        _runStartupOnboardingFlow();
      }
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
    final authState = ref.read(authProvider);
    if (!authState.canAccessApp) {
      return false;
    }

    if (authState.dataMode != AppDataMode.private) {
      return true;
    }

    final userProfile = await ref
        .read(userProfileProvider.notifier)
        .loadPrivateProfile();
    if (!mounted) return false;

    final shouldPrompt = shouldPromptForStartupName(
      authState: authState,
      userProfile: userProfile,
    );
    if (!shouldPrompt) {
      return true;
    }

    return _showNameDialog(isPrivateMode: true);
  }

  void _checkTutorial() {
    final hasSeenTutorial = ref.read(tutorialProvider);
    if (!hasSeenTutorial &&
        mounted &&
        !ref.read(biometricLockActiveProvider) &&
        !_isNameDialogOpen &&
        !_isWelcomeDialogOpen &&
        !_isDashboardTutorialShowing) {
      unawaited(_showWelcomeScreen());
    }
  }

  Future<void> _showWelcomeScreen() async {
    if (_isWelcomeDialogOpen || _isDashboardTutorialShowing || !mounted) return;

    _isWelcomeDialogOpen = true;
    bool shouldStartTutorial = false;
    try {
      shouldStartTutorial =
          await showGeneralDialog<bool>(
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
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
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
                            context.t.tutorial.welcomeToEvolve,
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
                            context.t.tutorial.welcomeDesc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                              Navigator.pop(context, true);
                            },
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  context.t.habits.startTour,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary
                                                .computeLuminance() >
                                            0.5
                                        ? Colors.black
                                        : Colors.white,
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
          ) ??
          false;
    } finally {
      _isWelcomeDialogOpen = false;
    }

    if (shouldStartTutorial && mounted) {
      _scheduleTutorialStart();
    }
  }

  void _scheduleTutorialStart() {
    _dashboardTutorialStartTimer?.cancel();
    _dashboardTutorialStartTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || _isNameDialogOpen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isNameDialogOpen) {
          _showTutorial();
        }
      });
    });
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
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
                      context.t.tutorial.youAreReady,
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
                      context.t.tutorial.theJourneyStartsNowGiveYour,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
                        ref
                            .read(tutorialProvider.notifier)
                            .setTutorialSeen(true);
                        ref
                            .read(calendarViewProvider.notifier)
                            .setView(CalendarView.month);
                        Navigator.pop(context);
                        _onItemTapped(1, bypassTutorialLock: true);
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            context.t.habits.start,
                            style: TextStyle(
                              color:
                                  Theme.of(
                                        context,
                                      ).colorScheme.primary.computeLuminance() >
                                      0.5
                                  ? Colors.black
                                  : Colors.white,
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
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isLandscape = size.width > size.height;
    final horizontalMargin = isLandscape ? 16.0 : 20.0;
    final availableWidth = math.max(240.0, size.width - (horizontalMargin * 2));
    final maxWidth = math.min(availableWidth, isLandscape ? 480.0 : 520.0);
    final availableHeight = math.max(
      160.0,
      size.height - mediaQuery.padding.vertical,
    );
    final maxHeight = isLandscape
        ? math.min(220.0, math.max(160.0, availableHeight - 48.0))
        : math.min(360.0, math.max(220.0, availableHeight - 96.0));
    final cardPadding = isLandscape
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(22);

    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: maxWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            padding: cardPadding,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        LucideIcons.info,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: context.appColors.foreground,
                            fontSize: isLandscape ? 17.0 : 18.0,
                            fontFamily: 'Inter',
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 10.0 : 12.0),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.appColors.mutedForeground,
                      fontFamily: 'Inter',
                      fontSize: isLandscape ? 13 : 14,
                      height: isLandscape ? 1.38 : 1.5,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 14.0 : 20.0),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (!isFirst)
                        TextButton(
                          onPressed: () {
                            ref.hapticSelection();
                            controller.previous();
                          },
                          child: Text(
                            context.t.tutorial.back,
                            style: TextStyle(
                              color: context.appColors.mutedForeground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor:
                              Theme.of(
                                    context,
                                  ).colorScheme.primary.computeLuminance() >
                                  0.5
                              ? Colors.black
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          nextButtonText ?? (isLast
                                    ? context.t.tutorial.finish
                                    : context.t.tutorial.next),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  bool _canStartDashboardTutorial() {
    if (!mounted ||
        _isNameDialogOpen ||
        _isWelcomeDialogOpen ||
        _isDashboardTutorialShowing) {
      return false;
    }

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isCurrentRoute) return false;

    return [
      _checkInKey,
      _aiChatKey,
      _manageHabitsKey,
      _viewTabKey,
      _calendarBoxKey,
      _goalsNavKey,
    ].every((key) => key.currentContext != null);
  }

  void _completeDashboardTutorial() {
    unawaited(ref.read(tutorialProvider.notifier).setTutorialSeen(true));
  }

  void _clearDashboardTutorialState({bool removeOverlay = false}) {
    _dashboardTutorialStartTimer?.cancel();
    if (removeOverlay) {
      _dashboardTutorial?.removeOverlayEntry();
    }
    _dashboardTutorial = null;
    _isDashboardTutorialShowing = false;
  }

  void _finishDashboardTutorial({bool advanceToGoals = false}) {
    if (!mounted) return;

    _clearDashboardTutorialState(removeOverlay: true);
    _completeDashboardTutorial();

    if (!advanceToGoals) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onItemTapped(2, bypassTutorialLock: true);
    });
  }

  void _showTutorial() {
    if (!_canStartDashboardTutorial()) return;

    final List<TargetFocus> targets = [
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
                context.t.tutorial.dailyCheckIn,
                context.t.tutorial.dailyCheckinDesc,
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
                context.t.tutorial.aiChat,
                context.t.tutorial.yourPersonalAiAssistantAskFor,
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
                context.t.tutorial.manageHabits,
                context.t.tutorial.addEditOrDeleteDailyHabits,
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
                context.t.tutorial.calendarViews,
                context.t.tutorial.navigateBetweenDifferentViewsToSee,
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
                context.t.tutorial.calendar,
                context.t.tutorial.simplyClickOnADayTo,
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
                context.t.tutorial.movingToGoals,
                context.t.tutorial.goalsPageDesc,
                controller,
                isLast: true,
                nextButtonText: context.t.tutorial.goToGoals,
                onNextPressed: () {
                  _finishDashboardTutorial(advanceToGoals: true);
                },
              );
            },
          ),
        ],
      ),
    ];

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      hideSkip: true,
      paddingFocus: 10,
      opacityShadow: 0.85,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: Duration.zero,
      pulseEnable: false,
      onFinish: () {
        _finishDashboardTutorial();
      },
      onSkip: () {
        _finishDashboardTutorial();
        return true;
      },
    );
    _dashboardTutorial = tutorial;
    _isDashboardTutorialShowing = true;
    try {
      tutorial.show(context: context);
    } catch (e, stack) {
      _clearDashboardTutorialState();
      AppLogger.warning(
        '[Tutorial] Unable to start dashboard tutorial',
        e,
        stack,
      );
    }
  }

  @override
  void dispose() {
    _dashboardTutorialStartTimer?.cancel();
    _dashboardTutorial?.removeOverlayEntry();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<bool> _showNameDialog({required bool isPrivateMode}) async {
    if (_isNameDialogOpen || !mounted) return false;

    _isNameDialogOpen = true;
    try {
      final didSave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _NamePromptDialog(
            onSave: (name) =>
                _saveProfileName(name, isPrivateMode: isPrivateMode),
          );
        },
      );

      return didSave ?? false;
    } finally {
      _isNameDialogOpen = false;
    }
  }

  Future<bool> _saveProfileName(
    String name, {
    required bool isPrivateMode,
  }) async {
    if (isPrivateMode) {
      try {
        await ref
            .read(userProfileProvider.notifier)
            .updatePrivateProfile(fullName: name);
        return true;
      } catch (e, stack) {
        AppLogger.error(
          '[Profile] Private profile name update error',
          e,
          stack,
        );
        return false;
      }
    }

    return ref.read(authProvider.notifier).updateProfileName(name);
  }

  bool _isTutorialFlowIncomplete() {
    return !ref.read(tutorialProvider) ||
        !ref.read(goalsTutorialProvider) ||
        !ref.read(statsTutorialProvider);
  }

  void _onItemTapped(int index, {bool bypassTutorialLock = false}) {
    if (index == _selectedNavIndex) return;
    if (!bypassTutorialLock && _isTutorialFlowIncomplete()) return;

    if ((index - _selectedNavIndex).abs() > 1) {
      _pageController.jumpToPage(index);
      setState(() => _selectedNavIndex = index);
    } else {
      unawaited(
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        ),
      );
    }
    ref.hapticSelection();
  }

  @override
  Widget build(BuildContext context) {
    final currentView = ref.watch(calendarViewProvider);
    final hasSeenDashboardTutorial = ref.watch(tutorialProvider);
    final hasSeenGoalsTutorial = ref.watch(goalsTutorialProvider);
    final hasSeenStatsTutorial = ref.watch(statsTutorialProvider);
    final isTutorialNavigationLocked =
        !hasSeenDashboardTutorial ||
        !hasSeenGoalsTutorial ||
        !hasSeenStatsTutorial;

    // The app-wide biometric lock lives above this screen (BiometricLockGate).
    // Resume the deferred onboarding/tutorial flow once the lock is cleared.
    ref.listen<bool>(biometricLockActiveProvider, (previous, next) {
      if (previous == true && next == false && mounted) {
        _runStartupOnboardingFlow();
      }
    });

    // Listen for tutorial reset
    ref.listen<bool>(tutorialProvider, (previous, next) {
      if (next == false && mounted && !ref.read(biometricLockActiveProvider)) {
        _clearDashboardTutorialState(removeOverlay: true);
        _runStartupOnboardingFlow();
      }
    });

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
        physics: isTutorialNavigationLocked
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
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
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: _getPage(index, currentView),
          );
        },
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedNavIndex,
        navKeys: [_statsNavKey, _homeNavKey, _goalsNavKey],
        navigationEnabled: !isTutorialNavigationLocked,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildHomeBody(CalendarView currentView) {
    final habits = ref.watch(goalsProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        PositionedDirectional(
          top: -100,
          start: -80,
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
                  child: Container(
                    key: _calendarBoxKey,
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
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 280;
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 56 : 80,
                      height: compact ? 56 : 80,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.sparkles,
                        size: compact ? 28 : 40,
                        color: primaryColor,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 24),
                    Text(
                      context.t.habits.yourCanvasIsEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: compact ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: context.appColors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      context.t.habits.createYourFirstHabitToStart,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: compact ? 13 : 14,
                        color: context.appColors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: compact ? 18 : 32),
                    EvolveButton(
                      key: _addHabitKey,
                      label: context.t.habits.addHabit,
                      icon: LucideIcons.plus,
                      expand: false,
                      haptic: EvolveButtonHaptic.medium,
                      onPressed: () => HabitManagementModal.show(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
        return StatisticsScreen(
          isActive: _selectedNavIndex == 0,
          onFinishTutorial: () {
            _showEndTutorialScreen();
          },
        );
      case 1:
        return _HomeTabWrapper(child: _buildHomeBody(currentView));
      case 2:
        return MacroGoalsScreen(
          isActive: _selectedNavIndex == 2,
          statsNavKey: _statsNavKey,
          onFinishTutorial: () {
            _onItemTapped(0, bypassTutorialLock: true);
          },
        );
      default:
        return const SizedBox();
    }
  }
}

class _NamePromptDialog extends ConsumerStatefulWidget {
  const _NamePromptDialog({required this.onSave});

  final Future<bool> Function(String name) onSave;

  @override
  ConsumerState<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends ConsumerState<_NamePromptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    ref.hapticMedium();
    final success = await widget.onSave(name);
    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t.habits.errorSavingPleaseTryAgain,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: context.appColors.card.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.appColors.border.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
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
                  context.t.habits.welcomeToEvolve,
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
                  context.t.habits.toStartWhatShouldWeCall,
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
                  controller: _controller,
                  decoration: InputDecoration(
                    labelText: context.t.habits.yourName,
                    labelStyle: TextStyle(
                      color: context.appColors.mutedForeground,
                      fontSize: 14,
                    ),
                    floatingLabelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    filled: true,
                    fillColor: context.appColors.background.withValues(
                      alpha: 0.5,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.appColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: TextStyle(
                    color: context.appColors.foreground,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                GestureDetector(
                  onTap: _handleSubmit,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        context.t.habits.startNow,
                        style: TextStyle(
                          color:
                              Theme.of(
                                    context,
                                  ).colorScheme.primary.computeLuminance() >
                                  0.5
                              ? Colors.black
                              : Colors.white,
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
      ),
    );
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
    if (hour < 12) return context.t.habits.goodMorning;
    if (hour < 18) return context.t.habits.goodAfternoon;
    return context.t.habits.goodEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final greeting = _getGreeting(context);
    final formattedDate = DateFormat(
      'EEEE, d MMMM',
      LocaleSettings.currentLocale.languageCode,
    ).format(DateTime.now());

    // Capitalize first letter of date
    final displayDate = formattedDate.isNotEmpty
        ? formattedDate[0].toUpperCase() + formattedDate.substring(1)
        : formattedDate;

    final userProfile = ref.watch(userProfileProvider);
    final isPrivateMode =
        ref.watch(activeDataModeProvider) == AppDataMode.private;
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
                              color: isPro
                                  ? const Color(0xFFEAB308)
                                  : primaryColor.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: Container(
                              color: context.appColors.card,
                              child: ProfileAvatarImage(
                                avatarUrl: userProfile.avatarUrl,
                                isPrivate: isPrivateMode,
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
