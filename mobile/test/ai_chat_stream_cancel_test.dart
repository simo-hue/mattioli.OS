// Regression coverage for the AI Coach's response stream lifecycle.
//
// `_sendMessage` captured `assistantMessageIndex = _messages.length` and then
// listened to the SSE token stream without ever storing the subscription. The
// trash / 'new chat' action is enabled for the whole streaming window (and
// `_isTyping` flips false on the first token), so clearing the conversation
// mid-response left the listener alive with a stale index: the next chunk threw
// `RangeError` from inside `onData`, which Dart routes to the zone's uncaught
// handler rather than the listener's `onError` — one global error modal per
// remaining chunk. The same un-cancelled subscription also kept the HTTP client
// open after the screen was popped, since the generator only closes it in its
// `finally`.
//
// These tests drive the stream chunk by chunk through `AIChatScreen.
// streamFactory` and assert the subscription is actually cancelled — a listener
// count, not just the absence of a throw.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mattioli_os/core/private_local_database.dart';
import 'package:mattioli_os/core/theme.dart';
import 'package:mattioli_os/i18n/translations.g.dart';
import 'package:mattioli_os/models/chat_message.dart';
import 'package:mattioli_os/providers/goal_provider.dart';
import 'package:mattioli_os/providers/shared_prefs_provider.dart';
import 'package:mattioli_os/core/coach_endpoint.dart';
import 'package:mattioli_os/ui/screens/ai_chat_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'support/fake_private_data_store.dart';

/// No-op notifications platform so providers that transitively touch the
/// notifications plugin don't explode on the unset instance. Same shim as
/// `ai_chat_screen_test.dart`.
class _NoopNotificationsPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterLocalNotificationsPlatform {
  @override
  Future<void> cancelAll() async {}
}

/// The shared fake reports no AI consent, which would put a confirm dialog in
/// front of every send. These tests are about the stream, not the consent gate.
class _ConsentedPrivateDataStore extends FakePrivateDataStore {
  @override
  Future<bool> hasPrivateAiExternalConsent() async => true;
}

/// Hands out a controller the test drives by hand in place of the real SSE call.
late StreamController<String> _tokens;

Future<void> _pumpChat(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'active_data_mode': 'private'});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        privateLocalDatabaseProvider.overrideWith(
          (ref) => _ConsentedPrivateDataStore(),
        ),
        initialGoalsProvider.overrideWithValue('[]'),
        initialLogsProvider.overrideWithValue('{}'),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AppTheme.darkTheme(null),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: AppLocaleUtils.supportedLocales,
          locale: const Locale('en'),
          home: const AIChatScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [text] into the composer and taps send, then pumps a few frames so the
/// async consent/key gates resolve and the listener attaches. Can't use
/// `pumpAndSettle` here: once `_isTyping` is true the typing indicator animates
/// forever, so the tree never settles.
Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.byIcon(LucideIcons.arrowUp));
  await tester.pump(); // start _sendMessage, hit the consent await
  await tester.pump(); // consent resolves, listener attaches
  // Fire the typing indicator's staggered dot timers (delays up to 400ms) while
  // still mounted, so they don't linger as pending timers past disposal.
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final realFactory = AIChatScreen.streamFactory;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    LocaleSettings.setLocaleSync(AppLocale.en);
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
    // A transport must resolve or the screen shows the setup card instead of the
    // composer and there is nothing to send. This test runs in Private mode,
    // where the only transport is the user's own key — which is the mode's own
    // logic, not a limitation: it keeps no account for our proxy to
    // authenticate.
    FlutterSecureStorage.setMockInitialValues({
      'openrouter_api_key': 'sk-or-test',
    });
    _tokens = StreamController<String>();
    AIChatScreen.streamFactory =
        (
          List<ChatMessage> history, {
          String? systemPrompt,
          CoachEndpoint? endpoint,
        }) => _tokens.stream;
  });

  tearDown(() async {
    AIChatScreen.streamFactory = realFactory;
    await _tokens.close();
  });

  testWidgets('clearing the chat mid-stream cancels the listener and a late '
      'chunk does not throw', (tester) async {
    await _pumpChat(tester);
    await _send(tester, 'How do I stay disciplined?');

    expect(_tokens.hasListener, isTrue, reason: 'stream should be subscribed');

    // First token lands normally.
    _tokens.add('Start ');
    await tester.pump();
    expect(find.textContaining('Start', findRichText: true), findsWidgets);

    // Trash the conversation while the rest of the reply is still streaming.
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // The fix: the subscription is dropped, which also runs the generator's
    // `finally { client.close(); }` in production.
    expect(
      _tokens.hasListener,
      isFalse,
      reason: 'deleting the chat must cancel the in-flight response',
    );

    // Before the fix this chunk indexed into the cleared list -> RangeError.
    _tokens.add('and the rest of the reply');
    await tester.pump();
    expect(tester.takeException(), isNull);

    // The conversation really is back to just the greeting, and the typing
    // indicator isn't left spinning on a stream that will never complete.
    expect(find.textContaining('rest of the reply', findRichText: true),
        findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsNothing);
  });

  testWidgets('popping the screen mid-stream cancels the listener',
      (tester) async {
    await _pumpChat(tester);
    await _send(tester, 'Hello coach');
    expect(_tokens.hasListener, isTrue);

    // Replacing the route disposes the chat state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(
      _tokens.hasListener,
      isFalse,
      reason: 'dispose must cancel the response stream',
    );

    _tokens.add('late token');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
