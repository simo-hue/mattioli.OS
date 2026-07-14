import 'package:evolve_desktop/i18n/translations.g.dart';

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import 'openai_compatible_client.dart';

/// The private engine: a user-run OpenAI-compatible server (Ollama, LM Studio,
/// llama.cpp, Jan…) at [baseUrl]. No API key, no internet check, and a generous
/// first-token budget so a cold model load doesn't false-fail.
class LocalCoachBackend implements CoachBackend {
  LocalCoachBackend({required this.baseUrl, OpenAiCompatibleClient? client})
    : _client =
          client ??
          OpenAiCompatibleClient(
            baseUrl: baseUrl,
            // A dummy bearer keeps servers that expect the header happy; local
            // servers ignore its value.
            headers: const {'Authorization': 'Bearer local'},
            // A cold model can take tens of seconds to load its first token.
            firstTokenTimeout: const Duration(seconds: 60),
            interChunkTimeout: const Duration(seconds: 15),
            errors: CoachErrorMessages(
              preflightFailed: t.ai.local.notReachable(url: baseUrl),
              modelNotFound: t.ai.local.modelNotFound,
              contextTooLong: t.ai.openRouter.contextTooLong,
              serverTimeout: t.ai.local.timeout,
              connectionError: t.ai.local.streamError,
              apiError: (code) => t.ai.local.requestFailed(code: code),
            ),
          );

  /// OpenAI-compatible base URL, ending in `/v1`.
  final String baseUrl;

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
