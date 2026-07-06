import 'dart:async';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/core/desktop_data_mode.dart';
import 'package:evolve_desktop/core/desktop_private_db.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivateProfileState {
  const PrivateProfileState({this.fullName, this.dateOfBirth, this.avatarPath});

  final String? fullName;
  final String? dateOfBirth;
  final String? avatarPath;

  PrivateProfileState copyWith({
    String? fullName,
    String? dateOfBirth,
    bool clearDateOfBirth = false,
    String? avatarPath,
    bool clearAvatarPath = false,
  }) {
    return PrivateProfileState(
      fullName: fullName ?? this.fullName,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      avatarPath: clearAvatarPath ? null : (avatarPath ?? this.avatarPath),
    );
  }
}

final privateProfileProvider =
    AsyncNotifierProvider<PrivateProfileNotifier, PrivateProfileState>(
      PrivateProfileNotifier.new,
    );

class PrivateProfileNotifier extends AsyncNotifier<PrivateProfileState> {
  @override
  FutureOr<PrivateProfileState> build() async {
    final mode = ref.watch(activeDesktopDataModeProvider);
    if (!mode.isPrivate) {
      return const PrivateProfileState();
    }

    try {
      final db = await DesktopPrivateDb.instance.database;
      final ownerId = await DesktopPrivateDb.instance.ownerId;
      // The schema column is `avatar_url` (shared with mobile; the local file
      // path of the cached avatar). An earlier version queried a non-existent
      // `avatar_path`, which broke the whole private-profile load.
      final rows = await db.query(
        'profiles',
        columns: ['full_name', 'date_of_birth', 'avatar_url'],
        where: 'id = ?',
        whereArgs: [ownerId],
      );

      if (rows.isNotEmpty) {
        final row = rows.first;
        return PrivateProfileState(
          fullName: row['full_name'] as String?,
          dateOfBirth: row['date_of_birth'] as String?,
          avatarPath: row['avatar_url'] as String?,
        );
      }
    } catch (e, stack) {
      AppLogger.error('Failed to load private profile', e, stack);
    }

    return const PrivateProfileState();
  }

  Future<void> updateProfile({
    required String fullName,
    String? dateOfBirth,
  }) async {
    final mode = ref.read(activeDesktopDataModeProvider);
    if (!mode.isPrivate) return;

    try {
      final normalizedDateOfBirth = dateOfBirth?.trim().isEmpty ?? true
          ? null
          : dateOfBirth?.trim();

      // Stamps updated_at (last-write-wins comparator) and notifies the
      // after-write sync trigger.
      await DesktopPrivateDb.instance.updateProfileFields(
        fullName: fullName.trim(),
        dateOfBirth: normalizedDateOfBirth,
      );

      state = AsyncData(
        state.value?.copyWith(
              fullName: fullName.trim(),
              dateOfBirth: normalizedDateOfBirth,
              clearDateOfBirth: normalizedDateOfBirth == null,
            ) ??
            PrivateProfileState(
              fullName: fullName.trim(),
              dateOfBirth: normalizedDateOfBirth,
            ),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to update private profile', e, stack);
    }
  }

  Future<void> updateAvatar(String avatarPath) async {
    final mode = ref.read(activeDesktopDataModeProvider);
    if (!mode.isPrivate) return;

    try {
      // Writes avatar_url + updated_at and marks the avatar pseudo-record
      // dirty so the image uploads as an encrypted CKAsset.
      await DesktopPrivateDb.instance.setAvatarPath(avatarPath);

      state = AsyncData(
        state.value?.copyWith(avatarPath: avatarPath) ??
            PrivateProfileState(avatarPath: avatarPath),
      );
    } catch (e, stack) {
      AppLogger.error('Failed to update private avatar', e, stack);
    }
  }
}
