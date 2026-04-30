import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';

// ── User Profile Model ────────────────────────────────────────────────────────
// Deriva i dati reali dall'oggetto User di Supabase Auth.
// full_name può essere impostato durante signup o aggiornato in profiles.

class UserProfile {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  const UserProfile({
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.avatarUrl,
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
    );
  }

  /// Profilo vuoto (stato iniziale / loading)
  const UserProfile.empty()
      : firstName = null,
        lastName = null,
        email = null,
        phone = null,
        avatarUrl = null;

  /// Display name con fallback
  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    if (email != null) return email!.split('@').first;
    return 'Utente';
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
// Derivato direttamente da authProvider: nessun stato separato da mantenere.
// Si aggiorna automaticamente ogni volta che l'utente Supabase cambia.

final userProfileProvider = Provider<UserProfile>((ref) {
  final authState = ref.watch(authProvider);
  if (!authState.isLoggedIn || authState.user == null) {
    return const UserProfile.empty();
  }
  return UserProfile.fromSupabaseUser(authState.user!);
});
