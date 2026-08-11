import 'dart:io';

import 'package:evolve_desktop/app/theme/evolve_theme.dart';
import 'package:evolve_desktop/core/app_logger.dart';
import 'package:evolve_desktop/features/dashboard/data/dashboard_repository.dart';
import 'package:evolve_desktop/features/dashboard/domain/dashboard_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A corrupt pending queue makes `_enqueue` throw while `_runOrQueue` is
/// already handling a network failure. The offline write is lost either way —
/// but the error the caller sees, and the diagnostic that explains it, must
/// still be about the network, not about the queue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a failing enqueue neither replaces the real error nor skips the log',
      () async {
    // A truncated/garbled keychain value: `_readPendingMutations` jsonDecodes
    // it, so `_enqueue` throws a FormatException.
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'desktop_dashboard_pending_user-id': 'not-json',
    });
    AppLogger.clearLogs();

    final repository = SupabaseDashboardRepository(
      client: SupabaseClient(
        'http://127.0.0.1:9',
        'test-publishable-key',
        httpClient: _OfflineHttpClient(),
      ),
      userId: 'user-id',
    );

    Object? thrown;
    try {
      await repository.createHabit(
        DashboardHabit(
          id: 'd710cf5c-45f7-4eb9-af81-a344c7f2546f',
          title: 'Lettura serale',
          color: EvolveColors.violet,
          streak: 0,
          weeklyProgress: const [
            false,
            false,
            false,
            false,
            false,
            false,
            false,
          ],
          state: HabitState.pending,
        ),
      );
    } catch (error) {
      thrown = error;
    }

    // The caller still sees why the write failed: the network was down. A
    // FormatException here would send it hunting for a JSON bug it never made.
    expect(thrown, isA<SocketException>());
    expect(
      AppLogger.logs.any(
        (entry) =>
            entry.level == AppLogLevel.error &&
            entry.message == 'Unable to sync insert on goals',
      ),
      isTrue,
      reason: 'the network failure must still reach the log',
    );
    // And the queue failure itself is not swallowed silently.
    expect(
      AppLogger.logs.any(
        (entry) =>
            entry.level == AppLogLevel.error &&
            entry.message == 'Unable to queue insert on goals',
      ),
      isTrue,
    );
  });
}

class _OfflineHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw const SocketException('Network is unreachable');
  }
}
