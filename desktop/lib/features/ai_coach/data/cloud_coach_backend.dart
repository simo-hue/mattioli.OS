import 'package:evolve_desktop/i18n/translations.g.dart';

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import 'openai_compatible_client.dart';
import 'openrouter_config.dart';

/// The hosted engine: OpenRouter's OpenAI-compatible endpoint. Data leaves the
/// device, so the caller gates this behind the private-mode consent dialog.
class CloudCoachBackend implements CoachBackend {
  CloudCoachBackend({OpenAiCompatibleClient? client})
    : _client =
          client ??
          OpenAiCompatibleClient(
            baseUrl: OpenRouterConfig.baseUrl,
            headers: {
              'Authorization': 'Bearer ${OpenRouterConfig.apiKey}',
              'HTTP-Referer': 'https://github.com/simo/mattioli.OS',
              'X-Title': 'Mattioli OS (Desktop)',
            },
            // Cloud is fast; no cold-model start to wait on.
            firstTokenTimeout: const Duration(seconds: 20),
            interChunkTimeout: const Duration(seconds: 10),
            errors: CoachErrorMessages(
              preflightFailed: t.ai.openRouter.noInternet,
              modelNotFound: t.ai.openRouter.apiError(code: 404),
              contextTooLong: t.ai.openRouter.contextTooLong,
              serverTimeout: t.ai.openRouter.serverTimeout,
              connectionError: t.ai.openRouter.connectionErrorShort,
              apiError: (code) => t.ai.openRouter.apiError(code: code),
            ),
          );

  final OpenAiCompatibleClient _client;

  static bool get hasApiKey =>
      OpenRouterConfig.apiKey.isNotEmpty &&
      OpenRouterConfig.apiKey != 'YOUR_OPENROUTER_API_KEY';

  @override
  CoachBackendKind get kind => CoachBackendKind.cloud;

  @override
  Stream<String> streamResponse(
    List<ChatMessage> history, {
    required String systemPrompt,
    required String model,
    required double temperature,
  }) async* {
    if (!hasApiKey) {
      yield t.ai.openRouter.apiKeyMissingShort;
      return;
    }
    yield* _client.stream(
      history,
      systemPrompt: systemPrompt,
      model: model,
      temperature: temperature,
    );
  }

  /// Cloud exposes a single curated model (no live discovery — OpenRouter lists
  /// hundreds). Kept as a list so the picker treats cloud and local uniformly.
  @override
  Future<List<CoachModel>> listModels() async => const [
    CoachModel(id: OpenRouterConfig.defaultModel, label: 'Gemini 2.5 Flash'),
  ];

  @override
  Future<bool> reachable() async => hasApiKey;
}
