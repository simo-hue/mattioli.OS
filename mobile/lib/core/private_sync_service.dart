import 'package:flutter_riverpod/flutter_riverpod.dart';

class PrivateSyncStatus {
  final bool isAvailable;
  final bool isEnabled;
  final DateTime? lastSyncedAt;
  final String? message;

  const PrivateSyncStatus({
    required this.isAvailable,
    required this.isEnabled,
    this.lastSyncedAt,
    this.message,
  });

  const PrivateSyncStatus.localOnly()
    : isAvailable = false,
      isEnabled = false,
      lastSyncedAt = null,
      message = 'iCloud sync is not implemented in this build.';
}

abstract class PrivateSyncService {
  Future<PrivateSyncStatus> status();
  Future<PrivateSyncStatus> syncNow();
}

class NoOpPrivateSyncService implements PrivateSyncService {
  const NoOpPrivateSyncService();

  @override
  Future<PrivateSyncStatus> status() async =>
      const PrivateSyncStatus.localOnly();

  @override
  Future<PrivateSyncStatus> syncNow() async =>
      const PrivateSyncStatus.localOnly();
}

final privateSyncServiceProvider = Provider<PrivateSyncService>((ref) {
  return const NoOpPrivateSyncService();
});
