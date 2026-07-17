import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_mode.dart';
import 'supabase_config.dart';
import 'openrouter_service.dart';
import '../providers/settings_provider.dart';

/// Where an AI Coach request goes, and how it authenticates.
///
/// The coach has two transports, and App Store Guideline 3.1.1 is the reason
/// there are two rather than one:
///
/// - **Standard** — our Supabase Edge Function, holding our OpenRouter key,
///   unlocked by the Pro subscription. This is the shape Apple requires: the
///   IAP unlocks the feature, not a key the user pastes in.
/// - **Connect your OpenRouter account** — the user's own key, straight to
///   openrouter.ai. Free for everyone, and the ONLY option in Private mode,
///   which has no account and therefore no way to reach our function.
///
/// Both speak the same wire format: the Edge Function reads `messages`, ignores
/// the model, and pipes OpenRouter's SSE straight back, so it is OpenAI-
/// compatible on purpose and one client serves both.
enum CoachMode {
  /// Our proxy, funded by the Pro subscription.
  standard,

  /// The user's own OpenRouter key.
  byok,
}

/// A resolved coach transport: everything a request needs, and nothing stateful.
class CoachEndpoint {
  const CoachEndpoint({
    required this.mode,
    required this.url,
    required this.host,
    required this.authorization,
    required this.sendModel,
  });

  final CoachMode mode;
  final Uri url;

  /// Host to probe before dialling.
  ///
  /// The preflight used to be hardcoded to `openrouter.ai`, which through the
  /// proxy would test reachability of a server we are not talking to — and
  /// report "you're offline" to someone whose connection is fine.
  final String host;

  /// Resolved per request, never captured.
  ///
  /// Standard mode authenticates with the Supabase session JWT, which rotates.
  /// A transport that captured the header once would 401 forever after the
  /// first refresh, with no way back short of restarting the app.
  final Future<String?> Function() authorization;

  /// Whether to name a model in the body. Only BYOK does: in Standard the
  /// server picks the model AND pins the provider, and letting the client
  /// choose would hand it our bill and break the Guideline 5.1.2(i) recipient
  /// disclosure.
  final bool sendModel;
}

/// The Supabase Edge Function that fronts our OpenRouter key.
///
/// Built from the same [SupabaseConfig.url] `main.dart` initialises the client
/// with, rather than reverse-engineered out of the client's REST URL.
Uri get _proxyUrl =>
    Uri.parse('${SupabaseConfig.url}/functions/v1/ai-coach');

/// The live Supabase session's access token, or null when signed out.
///
/// Injected rather than read inline so [coachEndpointProvider] is testable:
/// `Supabase.instance` throws when the client was never initialised, which is
/// every unit test. Overridden in tests; production reads the real session.
final coachSessionTokenProvider = Provider<Future<String?> Function()>(
  (_) => () async => Supabase.instance.client.auth.currentSession?.accessToken,
);

/// Which transport applies, or null when the coach is not usable yet.
///
/// A pure function because the rule is worth stating once, in one place, where
/// it can be read and tested — not spread across provider reads.
///
/// **The order is load-bearing, and `isPrivate` must come first.** Two
/// independent reasons, either of which is sufficient:
///
///  1. Private mode force-injects `isPro: true` unconditionally — in the sync
///     seed (settings_provider.dart:220-230), the async row load (:544), AND at
///     the DB layer on every settings write (private_local_database.dart:
///     833-843). So `isPro` is not a fact in private mode; it is a placeholder
///     that happens to share a name with the `profiles.is_pro` our proxy checks.
///  2. `Supabase.initialize` is skipped entirely in private mode (main.dart:
///     72-77), so `Supabase.instance.client` does not return null there — it
///     THROWS. Reading the session before the data mode is not a 401, it is a
///     crash.
///
/// Private mode can therefore only ever be BYOK. That is the mode's own logic
/// rather than a limitation: it keeps no account, so there is nothing for our
/// server to authenticate.
@visibleForTesting
CoachMode? resolveCoachMode({
  required bool isPrivate,
  required bool isPro,
  required bool hasSession,
  required bool hasKey,
}) {
  // A Pro user with no session is mid-sign-in or mid-refresh: fall through to
  // BYOK rather than fail, and pick Standard up on the next resolve.
  if (!isPrivate && isPro && hasSession) return CoachMode.standard;
  if (hasKey) return CoachMode.byok;
  return null;
}

/// The transport for this user right now, or null when nothing is configured
/// (BYOK with no key stored).
final coachEndpointProvider = FutureProvider<CoachEndpoint?>((ref) async {
  final isPrivate = ref.watch(activeDataModeProvider).isPrivate;
  // Guarded by isPrivate: reading the session in private mode throws, because
  // Supabase was never initialised there.
  final token = isPrivate ? null : ref.watch(coachSessionTokenProvider);
  final session = token == null ? null : await token();
  final key = await ref.watch(openRouterApiKeyProvider.future);

  final mode = resolveCoachMode(
    isPrivate: isPrivate,
    // Only read where it means something. In private mode it is always true and
    // says nothing.
    isPro: !isPrivate && ref.watch(settingsProvider).isPro,
    hasSession: session != null,
    hasKey: key != null,
  );

  switch (mode) {
    case null:
      return null;
    case CoachMode.standard:
      final url = _proxyUrl;
      return CoachEndpoint(
        mode: CoachMode.standard,
        url: url,
        host: url.host,
        // Resolved at send time, not captured here: the JWT rotates, and a
        // header frozen now would 401 forever after the first refresh.
        authorization: token!,
        sendModel: false,
      );
    case CoachMode.byok:
      return CoachEndpoint(
        mode: CoachMode.byok,
        url: Uri.parse('$kOpenRouterBaseUrl/chat/completions'),
        host: 'openrouter.ai',
        authorization: () async => key,
        sendModel: true,
      );
  }
});

/// Whether this user could reach Standard mode if they subscribed.
///
/// False in Private mode — not as a limitation but as the mode's own logic: it
/// keeps no account, so there is nothing for our server to authenticate. That
/// is also why BYOK stays free and first-class rather than being a consolation
/// prize.
final canUseStandardCoachProvider = Provider<bool>((ref) {
  return !ref.watch(activeDataModeProvider).isPrivate;
});
