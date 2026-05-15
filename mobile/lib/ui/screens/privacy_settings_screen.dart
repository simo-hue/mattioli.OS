import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../providers/goal_provider.dart';
import '../../providers/macro_goals_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../providers/settings_provider.dart';
import '../../core/haptics.dart';
import '../../core/localization.dart';
import '../../core/app_logger.dart';
import '../widgets/pro_features_modal.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const PrivacySettingsScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        backgroundColor: context.appColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: context.appColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.translate('Privacy e Sicurezza'),
          style: TextStyle(
            color: context.appColors.foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'PROTEZIONE ACCESSO'),
            _buildSettingsCard(context, [
              _buildSwitchRow(
                context: context,
                ref: ref,
                icon: LucideIcons.shield,
                title: context.l10n.translate('Blocco Biometrico'),
                subtitle: 'FaceID / TouchID',
                value: settings.biometricLock,
                isLocked: !settings.isPro,
                onChanged: (val) async {
                  if (settings.isPro) {
                    if (val) {
                      final authenticated = await _authenticate(context);
                      if (authenticated) {
                        final currentSettings = ref.read(settingsProvider);
                        notifier.updateSettings(currentSettings.copyWith(biometricLock: true));
                        ref.hapticLight();
                      }
                    } else {
                      final currentSettings = ref.read(settingsProvider);
                      notifier.updateSettings(currentSettings.copyWith(biometricLock: false));
                      ref.hapticLight();
                    }
                  } else {
                    ref.hapticHeavy();
                    ProFeaturesModal.show(context);
                  }
                },
              ),
              _buildDivider(context),
              _buildActionRow(
                context: context,
                icon: LucideIcons.keyRound,
                title: 'Cambia Password',
                onTap: () {
                  ref.hapticLight();
                  _showChangePasswordModal(context);
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'GESTIONE DATI'),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.download,
                title: 'Esporta Dati',
                subtitle: 'Formato JSON / CSV',
                onTap: () {
                  ref.hapticMedium();
                  _exportData(context, ref);
                },
              ),
              _buildDivider(context),
              _buildActionRow(
                context: context,
                icon: LucideIcons.trash2,
                title: 'Elimina Account & Dati',
                titleColor: AppColors.destructive,
                onTap: () {
                  ref.hapticHeavy();
                  _showDeleteOrResetModal(context, ref);
                },
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'PERMESSI DI SISTEMA'),
            _buildSettingsCard(context, [
              _buildActionRow(
                context: context,
                icon: LucideIcons.settings2,
                title: 'Gestione Permessi',
                subtitle: 'Notifiche, Calendario, etc.',
                onTap: () async {
                  ref.hapticLight();
                  await openAppSettings();
                },
              ),
            ]),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Future<bool> _authenticate(BuildContext context) async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      return await auth.authenticate(
        localizedReason: 'Autenticati per abilitare la protezione dell\'app',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e, stack) {
      AppLogger.error('Biometric authentication error', e, stack);
      return false;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: context.appColors.mutedForeground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appColors.border,
      indent: 56,
    );
  }

  Widget _buildActionRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.appColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appColors.border),
              ),
              child: Icon(icon, size: 18, color: titleColor ?? primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: titleColor ?? context.appColors.foreground,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: context.appColors.mutedForeground.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLocked = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDisabled = isLocked;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: context.appColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            child: Icon(icon, size: 18, color: isDisabled ? context.appColors.mutedForeground : primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          color: isDisabled ? context.appColors.mutedForeground : context.appColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'PRO',
                          style: GoogleFonts.inter(
                            color: Colors.amber, 
                            fontSize: 9, 
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: AppColors.mutedForeground.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: (val) => onChanged(val), // Always interactive to allow modal trigger
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
              activeThumbColor: primaryColor,
              inactiveThumbColor: context.appColors.mutedForeground,
              inactiveTrackColor: context.appColors.border,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    bool isLoading = false;
    String? errorMessage;
    bool isVerified = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.appColors.card.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cambia Password',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.appColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified 
                            ? 'Inserisci la tua nuova password.' 
                            : 'Inserisci la tua password attuale per continuare.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: context.appColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      if (!isVerified) ...[
                        _buildPasswordField(
                          controller: currentPasswordController,
                          label: 'Password Attuale',
                          context: context,
                        ),
                      ] else ...[
                        _buildPasswordField(
                          controller: newPasswordController,
                          label: 'Nuova Password',
                          context: context,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          label: 'Conferma Nuova Password',
                          context: context,
                        ),
                      ],
                      
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.destructive,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isLoading ? null : () => Navigator.pop(context),
                            child: Text(
                              'Annulla',
                              style: GoogleFonts.inter(
                                color: context.appColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: isLoading ? null : () async {
                              if (!isVerified) {
                                final currentPwd = currentPasswordController.text;
                                if (currentPwd.isEmpty) {
                                  setState(() => errorMessage = 'Inserisci la password attuale.');
                                  return;
                                }
                                
                                setState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });
                                
                                try {
                                  final supabase = Supabase.instance.client;
                                  final email = supabase.auth.currentUser?.email;
                                  
                                  if (email == null) throw Exception('Utente non trovato.');
                                  
                                  await supabase.auth.signInWithPassword(email: email, password: currentPwd);
                                  
                                  setState(() {
                                    isLoading = false;
                                    isVerified = true;
                                    errorMessage = null;
                                  });
                                } catch (e) {
                                  setState(() {
                                    isLoading = false;
                                    errorMessage = 'La password attuale non è corretta.';
                                  });
                                }
                              } else {
                                final newPwd = newPasswordController.text;
                                final confirmPwd = confirmPasswordController.text;
                                
                                if (newPwd.isEmpty || confirmPwd.isEmpty) {
                                  setState(() => errorMessage = 'Tutti i campi sono obbligatori.');
                                  return;
                                }
                                
                                if (newPwd.length < 8) {
                                  setState(() => errorMessage = 'La nuova password deve essere di almeno 8 caratteri.');
                                  return;
                                }
                                
                                if (newPwd != confirmPwd) {
                                  setState(() => errorMessage = 'Le password non coincidono.');
                                  return;
                                }
                                
                                setState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });
                                
                                try {
                                  final supabase = Supabase.instance.client;
                                  
                                  await supabase.auth.updateUser(UserAttributes(password: newPwd));
                                  
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password aggiornata con successo!')),
                                    );
                                  }
                                } catch (e) {
                                  setState(() {
                                    isLoading = false;
                                    errorMessage = e.toString().replaceAll('Exception: ', '');
                                  });
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      isVerified ? 'Salva' : 'Verifica',
                                      style: GoogleFonts.inter(
                                        color: Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.w600,
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
            );
          },
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required BuildContext context,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.appColors.mutedForeground, fontSize: 14),
        floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: context.appColors.background.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
      style: TextStyle(color: context.appColors.foreground, fontFamily: 'Inter', fontSize: 14),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final settings = ref.read(settingsProvider);
      final goals = ref.read(goalsProvider);
      final macroGoals = ref.read(macroGoalsProvider).goals;

      // Construct JSON
      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'settings': {
          'themeMode': settings.themeMode,
          'accentColor': '#${settings.accentColor.toARGB32().toRadixString(16).substring(2)}',
          'defaultCalendarView': settings.defaultCalendarView,
          'hapticFeedback': settings.hapticFeedback,
          'language': settings.language,
          'timeFormat24h': settings.timeFormat24h,
          'aiSuggestions': settings.aiSuggestions,
          'isPro': settings.isPro,
          'focusMode': settings.focusMode,
          'milestones': settings.milestones,
          'deepWorkInsights': settings.deepWorkInsights,
          'habitReminders': settings.habitReminders,
          'goalDeadlines': settings.goalDeadlines,
          'aiInsights': settings.aiInsights,
          'weeklyReports': settings.weeklyReports,
          'eveningReview': settings.eveningReview,
          'biometricLock': settings.biometricLock,
          'anonymousAnalytics': settings.anonymousAnalytics,
          'morningBriefTime': settings.morningBriefTime,
          'eveningReviewTime': settings.eveningReviewTime,
        },
        'habits': goals.map((g) => g.toJson()).toList(),
        'macroGoals': macroGoals.map((g) => g.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final bytes = utf8.encode(jsonString);
      final file = XFile.fromData(
        bytes,
        mimeType: 'application/json',
        name: 'mattioli_os_export.json',
      );

      await Share.shareXFiles([file], text: 'I miei dati esportati da mattioli.OS');
    } catch (e, stack) {
      AppLogger.error('Error exporting data', e, stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'esportazione: $e')),
        );
      }
    }
  }
  void _showDeleteOrResetModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestione Account e Dati',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scegli l\'operazione che desideri effettuare. Entrambe le azioni richiedono conferma.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildOptionCard(
                    context: context,
                    icon: LucideIcons.refreshCw,
                    title: 'Resetta i Dati',
                    subtitle: 'Eliminerà abitudini, obiettivi e preferenze, ma manterrà il tuo account attivo.',
                    onTap: () {
                      Navigator.pop(context);
                      _showConfirmationDialog(
                        context: context,
                        title: 'Conferma Reset Dati',
                        message: 'Sei sicuro di voler eliminare tutti i tuoi dati? Questa azione non può essere annullata.',
                        onConfirm: () async {
                          await _resetData(context, ref);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  _buildOptionCard(
                    context: context,
                    icon: LucideIcons.trash2,
                    title: 'Elimina l\'Account',
                    subtitle: 'Eliminerà definitivamente il tuo account e tutti i dati associati. Questa azione è irreversibile.',
                    titleColor: AppColors.destructive,
                    onTap: () {
                      Navigator.pop(context);
                      _showConfirmationDialog(
                        context: context,
                        title: 'Conferma Eliminazione Account',
                        message: 'Sei sicuro di voler eliminare definitivamente il tuo account? Tutti i tuoi dati andranno persi per sempre.',
                        isDestructive: true,
                        onConfirm: () async {
                          await _deleteAccount(context, ref);
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Annulla',
                          style: GoogleFonts.inter(
                            color: context.appColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (titleColor ?? context.appColors.foreground).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: titleColor ?? context.appColors.foreground,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: context.appColors.mutedForeground,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.appColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appColors.border.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? AppColors.destructive : context.appColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Annulla',
                          style: GoogleFonts.inter(
                            color: context.appColors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          onConfirm();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDestructive ? AppColors.destructive : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Conferma',
                            style: GoogleFonts.inter(
                              color: isDestructive 
                                  ? Colors.white 
                                  : (Theme.of(context).colorScheme.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white),
                              fontWeight: FontWeight.w600,
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
        );
      },
    );
  }

  Future<void> _resetData(BuildContext context, WidgetRef ref) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utente non trovato.');

      await supabase.from('goals').delete().eq('user_id', user.id);
      await supabase.from('long_term_goals').delete().eq('user_id', user.id);
      
      // Clear local state and cache
      ref.read(goalsProvider.notifier).clearAll();
      ref.read(habitLogsProvider.notifier).clearAll();
      ref.read(macroGoalsProvider.notifier).clearAll();
      ref.read(settingsProvider.notifier).resetToDefaults();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dati resettati con successo!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante il reset: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Utente non trovato.');

      await supabase.from('goals').delete().eq('user_id', user.id);
      await supabase.from('goal_logs').delete().eq('user_id', user.id);
      await supabase.from('long_term_goals').delete().eq('user_id', user.id);
      await supabase.from('profiles').delete().eq('id', user.id);
      
      await supabase.auth.signOut();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account eliminato con successo!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
        );
      }
    }
  }
}
