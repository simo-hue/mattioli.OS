import '../../core/localization.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import 'personal_info_screen.dart';
import 'app_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'subscription_screen.dart';
import '../../core/haptics.dart';
import '../../core/app_logger.dart';
import '../../providers/tutorial_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        ref.hapticMedium();
      }
    } catch (e, stack) {
      AppLogger.error('Error picking image', e, stack);
    }
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
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
                border: Border.all(
                  color: context.appColors.border.withValues(alpha: 0.5),
                  width: 1.5,
                ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.appColors.destructive.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.logOut,
                          color: context.appColors.destructive,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.translate('Conferma Uscita'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.appColors.foreground,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.translate('Sei sicuro di voler uscire dal tuo account? Dovrai reinserire le tue credenziali per accedere nuovamente.'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: context.appColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          context.l10n.translate('Annulla'),
                          style: TextStyle(
                            color: context.appColors.mutedForeground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () async {
                          Navigator.pop(dialogContext);
                          ref.hapticHeavy();
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: context.appColors.destructive,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: context.appColors.destructive.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            context.l10n.translate('Esci'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final settings = ref.watch(settingsProvider);
    final isPro = settings.isPro;

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: context.appColors.background,
            elevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.chevronLeft, color: context.appColors.foreground),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Container(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withValues(alpha: 0.1),
                                  primaryColor.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: isPro ? const Color(0xFFEAB308) : primaryColor.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(45),
                                child: _profileImage != null
                                    ? Image.file(
                                        _profileImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : userProfile.avatarUrl != null
                                        ? Image.network(
                                            userProfile.avatarUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : Image.asset(
                                            'assets/images/default_avatar.png',
                                            fit: BoxFit.cover,
                                          ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: context.appColors.background, width: 2),
                              ),
                              child: Icon(
                                LucideIcons.camera,
                                size: 14,
                                color: context.appColors.background,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${userProfile.firstName} ${userProfile.lastName}',
                      style: TextStyle(
                        color: context.appColors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.shieldCheck, size: 10, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              const Text(
                                'Account Verificato',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isPro) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAB308).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEAB308).withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.crown, size: 10, color: Color(0xFFEAB308)),
                                SizedBox(width: 4),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Color(0xFFEAB308),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),

            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'IMPOSTAZIONI ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.user,
                  title: context.l10n.translate('Informazioni Personali'),
                  subtitle: userProfile.email ?? '',
                  onTap: () {
                    Navigator.push(context, PersonalInfoScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.creditCard,
                  title: context.l10n.translate('Abbonamento'),
                  subtitle: settings.isPro ? 'Gestisci il tuo piano Pro' : 'Passa a Pro',
                  onTap: () {
                    Navigator.push(context, SubscriptionScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.settings,
                  title: context.l10n.translate('Impostazioni App'),
                  subtitle: context.l10n.translate('Lingua, Tema, Unità di misura'),
                  onTap: () {
                    Navigator.push(context, AppSettingsScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.bell,
                  title: context.l10n.translate('Notifiche'),
                  subtitle: context.l10n.translate('Promemoria e avvisi di sistema'),
                  onTap: () {
                    Navigator.push(context, NotificationSettingsScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.shield,
                  title: context.l10n.translate('Privacy e Sicurezza'),
                  subtitle: context.l10n.translate('Gestione dati e biometrica'),
                  onTap: () {
                    Navigator.push(context, PrivacySettingsScreen.route());
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'AIUTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.info,
                  title: context.l10n.translate('Ripeti Tutorial'),
                  subtitle: context.l10n.translate('Visualizza di nuovo la guida iniziale'),
                  onTap: () async {
                    Navigator.pop(context); // Torna alla home
                    // Piccola attesa per completare la transizione
                    await Future.delayed(const Duration(milliseconds: 300));
                    ref.read(tutorialProvider.notifier).setTutorialSeen(false);
                    ref.read(goalsTutorialProvider.notifier).setTutorialSeen(false);
                    ref.read(statsTutorialProvider.notifier).setTutorialSeen(false);
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'SISTEMA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                // Logout Button
                GestureDetector(
                  onTap: () {
                    ref.hapticLight();
                    _showLogoutConfirmationDialog(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.appColors.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.appColors.destructive.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Esci',
                        style: TextStyle(
                          color: context.appColors.destructive,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Versione 1.0.0',
                    style: TextStyle(
                      color: context.appColors.mutedForeground.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.appColors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: context.appColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.appColors.border),
          ),
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: context.appColors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: context.appColors.mutedForeground.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: context.appColors.mutedForeground,
        ),
        onTap: () {
          ref.hapticLight();
          onTap();
        },
      ),
    );
  }
}
