import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/user_provider.dart';
import 'personal_info_screen.dart';
import 'app_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import '../../core/haptics.dart';

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
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft, color: AppColors.foreground),
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
                                color: primaryColor.withValues(alpha: 0.2),
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
                                  : Container(
                                      color: AppColors.card,
                                      child: const Icon(
                                        LucideIcons.user,
                                        size: 50,
                                        color: AppColors.mutedForeground,
                                      ),
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
                                border: Border.all(color: AppColors.background, width: 2),
                              ),
                              child: const Icon(
                                LucideIcons.camera,
                                size: 14,
                                color: AppColors.background,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${userProfile.firstName} ${userProfile.lastName}',
                      style: const TextStyle(
                        color: AppColors.foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),

            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'IMPOSTAZIONI ACCOUNT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.user,
                  title: 'Informazioni Personali',
                  subtitle: userProfile.email,
                  onTap: () {
                    Navigator.push(context, PersonalInfoScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.settings,
                  title: 'Impostazioni App',
                  subtitle: 'Lingua, Tema, Unità di misura',
                  onTap: () {
                    Navigator.push(context, AppSettingsScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.bell,
                  title: 'Notifiche',
                  subtitle: 'Promemoria e avvisi di sistema',
                  onTap: () {
                    Navigator.push(context, NotificationSettingsScreen.route());
                  },
                ),
                _buildProfileOption(
                  context: context,
                  icon: LucideIcons.shield,
                  title: 'Privacy e Sicurezza',
                  subtitle: 'Gestione dati e biometrica',
                  onTap: () {
                    Navigator.push(context, PrivacySettingsScreen.route());
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'SISTEMA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mutedForeground,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                // Logout Button
                GestureDetector(
                  onTap: () {
                    ref.hapticHeavy();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.destructive.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Disconnetti Sessione',
                        style: TextStyle(
                          color: AppColors.destructive,
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
                    'Versione 1.0.0 (Build 20260422)',
                    style: TextStyle(
                      color: AppColors.mutedForeground.withValues(alpha: 0.5),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.mutedForeground.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: AppColors.mutedForeground,
        ),
        onTap: () {
          ref.hapticLight();
          onTap();
        },
      ),
    );
  }
}
