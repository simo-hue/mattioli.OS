import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'auth_provider.dart';
import '../core/data_mode.dart';
import '../core/private_local_database.dart';
import '../core/app_logger.dart';

// ── User Profile Model ────────────────────────────────────────────────────────
// Deriva i dati reali dall'oggetto User di Supabase Auth.
// full_name può essere impostato durante signup o aggiornato in profiles.

class UserProfile {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? dateOfBirth;

  const UserProfile({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
  });

  /// Costruisce un profilo dall'oggetto User di Supabase.
  factory UserProfile.fromSupabaseUser(User user) {
    final meta = user.userMetadata;
    // full_name viene da OAuth oppure da signUp con metadata
    final fullName = (meta?['full_name'] as String?) ?? '';
    final parts = fullName.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return UserProfile(
      firstName: firstName.isEmpty ? null : firstName,
      lastName: lastName.isEmpty ? null : lastName,
      email: user.email,
      phone: user.phone,
      avatarUrl: meta?['avatar_url'] as String?,
      dateOfBirth: meta?['date_of_birth'] as String?,
    );
  }

  /// Profilo vuoto (stato iniziale / loading)
  const UserProfile.empty()
    : firstName = null,
      lastName = null,
      email = null,
      phone = null,
      avatarUrl = null,
      dateOfBirth = null;

  /// Display name con fallback
  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    if (email != null) return email!.split('@').first;
    return 'Utente';
  }

  bool requiresNameSetup({required bool isPrivateMode}) {
    final nameParts = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (nameParts.isEmpty) return true;
    if (!isPrivateMode) return false;

    return nameParts.join(' ').toLowerCase() == 'private user';
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? dateOfBirth,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}

bool shouldPromptForStartupName({
  required AuthState authState,
  required UserProfile userProfile,
}) {
  if (!authState.canAccessApp) return false;
  if (authState.dataMode != AppDataMode.private) return false;

  return userProfile.requiresNameSetup(isPrivateMode: true);
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final dataMode = ref.watch(activeDataModeProvider);
    if (dataMode == AppDataMode.private) {
      loadPrivateProfile();
      return const UserProfile.empty();
    }

    final authState = ref.watch(authProvider);
    if (!authState.isLoggedIn || authState.user == null) {
      return const UserProfile.empty();
    }
    return UserProfile.fromSupabaseUser(authState.user!);
  }

  Future<UserProfile> loadPrivateProfile() async {
    try {
      final db = ref.read(privateLocalDatabaseProvider);
      final row = await db.loadProfileRow();
      // Resolve the avatar against the CURRENT container before handing it to
      // the UI. `profiles.avatar_url` is a legacy absolute path and iOS
      // regenerates the container UUID in it across reinstalls, so the stored
      // string goes stale while the image itself is still on disk. Rendering it
      // raw is what showed the (black) default avatar instead of the photo.
      // NOT copyWith: its `??` would keep the stale stored path whenever the
      // resolve returns null, which is exactly the case that must show the
      // default avatar instead of a dangling one.
      final profile =
          _fromPrivateRow(row, avatarPath: await db.resolveAvatarPath());
      state = profile;
      return profile;
    } catch (e, stack) {
      AppLogger.error('[UserProfile] Private profile load error', e, stack);
      state = const UserProfile.empty();
      return const UserProfile.empty();
    }
  }

  Future<void> updatePrivateProfile({
    required String fullName,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
  }) async {
    if (ref.read(activeDataModeProvider) != AppDataMode.private) return;
    await ref
        .read(privateLocalDatabaseProvider)
        .updateProfile(
          fullName: fullName,
          dateOfBirth: dateOfBirth,
          clearDateOfBirth: clearDateOfBirth,
        );
    await loadPrivateProfile();
  }

  Future<void> updatePrivateAvatar(String path) async {
    if (ref.read(activeDataModeProvider) != AppDataMode.private) return;
    await ref.read(privateLocalDatabaseProvider).updateProfile(avatarUrl: path);
    await loadPrivateProfile();
  }

  /// [avatarPath] is the avatar RESOLVED against the current container (see
  /// [PrivateLocalDatabase.resolveAvatarPath]) — deliberately a parameter
  /// rather than `row['avatar_url']`, so a stale stored path can never reach
  /// the UI.
  UserProfile _fromPrivateRow(
    Map<String, dynamic> row, {
    String? avatarPath,
  }) {
    final fullName = (row['full_name'] as String? ?? '').trim();
    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = fullName.isEmpty ? null : parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : null;

    return UserProfile(
      firstName: firstName,
      lastName: lastName,
      email: null,
      avatarUrl: avatarPath,
      dateOfBirth: row['date_of_birth'] as String?,
    );
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
