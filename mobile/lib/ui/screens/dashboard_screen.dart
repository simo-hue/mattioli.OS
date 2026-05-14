import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/settings_provider.dart';

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

    // Biometric lock check
    final biometricLock = ref.read(settingsProvider).biometricLock;
    if (biometricLock) {
      _isBiometricAuthenticated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticate();
      });
    }

    // Check profile name after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProfileName();
    });
  }

  Future<void> _authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        setState(() => _isBiometricAuthenticated = true);
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Sblocca l\'app per continuare',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        setState(() => _isBiometricAuthenticated = true);
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
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
                        if (success && mounted) {
                          Navigator.pop(context);
                        } else if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final currentView = ref.watch(calendarViewProvider);

    if (!_isBiometricAuthenticated) {
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
        onTap: (index) {
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
        },
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
                const ProtocolloPanel(),
                const SizedBox(height: 20),
                const ViewTabBar(),
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
                          child: _buildViewContent(currentView),
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
        return const StatisticsScreen();
      case 1:
        return _HomeTabWrapper(child: _buildHomeBody(currentView));
      case 2:
        return const MacroGoalsScreen();
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
                                image: NetworkImage(userProfile.avatarUrl ?? 'https://github.com/simonemattioli.png'),
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


