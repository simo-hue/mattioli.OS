import 'package:evolve_desktop/i18n/translations.g.dart';

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import '../domain/local_server_target.dart';
import 'openai_compatible_client.dart';

/// The private engine: a user-run OpenAI-compatible server (Ollama, LM Studio,
/// llama.cpp, Jan…) at [baseUrl]. No API key, no internet check, and a
/// per-product first-token budget so a cold model load doesn't false-fail.
class LocalCoachBackend implements CoachBackend {
  factory LocalCoachBackend({
    required String baseUrl,
    OpenAiCompatibleClient? client,
  }) {
    final target = LocalServerTarget.forBaseUrl(baseUrl);
    return LocalCoachBackend._(
      baseUrl: baseUrl,
      target: target,
      client:
          client ??
          OpenAiCompatibleClient(
            baseUrl: baseUrl,
            // A dummy bearer keeps servers that expect the header happy; local
            // servers ignore its value — unless one has been configured to
            // require a real token, which [CoachErrorMessages.unauthorized]
            // below now explains instead of leaving as a bare status code.
            headers: const {'Authorization': 'Bearer local'},
            // Per product: a cold model can take tens of seconds (Ollama) to
            // minutes (LM Studio, which evicts between switches) to load.
            firstTokenTimeout: target.firstTokenTimeout,
            interChunkTimeout: const Duration(seconds: 15),
            errors: CoachErrorMessages(
              preflightFailed: t.ai.local.notReachable(url: baseUrl),
              modelNotFound: t.ai.local.modelNotFound,
              contextTooLong: t.ai.openRouter.contextTooLong,
              serverTimeout: t.ai.local.timeout,
              connectionError: t.ai.local.streamError,
              apiError: (code) => t.ai.local.requestFailed(code: code),
              // A local server CAN now demand credentials: LM Studio 0.4.0 added
              // an opt-in "Require Authentication" toggle, and LM Studio's own
              // docs recommend enabling it alongside "Serve on Local Network" —
              // exactly the LAN endpoint `isLoopbackOrLan` deliberately permits.
              // Without this, that user got a bare `apiError(401)`, because 401
              // from a local server used to be considered impossible.
              unauthorized: t.ai.local.authRequired(app: target.displayName),
            ),
          ),
    );
  }

  LocalCoachBackend._({
    required this.baseUrl,
    required this.target,
    required OpenAiCompatibleClient client,
  }) : _client = client;

  /// OpenAI-compatible base URL, ending in `/v1`.
  final String baseUrl;

  /// The product [baseUrl] resolves to — supplies the timeout budget and the
  /// name used in error copy.
  final LocalServerTarget target;

  final OpenAiCompatibleClient _client;

  @override
  CoachBackendKind get kind => CoachBackendKind.local;

  @override
  Stream<String> streamResponse(
    List<ChatMessage> history, {
    required String systemPrompt,
    required String model,
    required double temperature,
  }) async* {
    if (model.trim().isEmpty) {
      yield t.ai.local.modelMissing;
      return;
    }
    yield* _client.stream(
      history,
      systemPrompt: systemPrompt,
      model: model,
      temperature: temperature,
    );
  }

  @override
  Future<List<CoachModel>> listModels() => _client.listModels();

  @override
  Future<bool> reachable() => _client.reachable();
}
