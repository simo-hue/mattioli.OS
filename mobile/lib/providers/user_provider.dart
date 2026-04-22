import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;

  UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
  });

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) {
    return UserProfile(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    return UserProfile(
      firstName: 'Simone',
      lastName: 'Mattioli',
      email: 'simone@mattioli.os',
      phone: '+39 333 1234567',
    );
  }

  void updateProfile(UserProfile profile) {
    state = profile;
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);
