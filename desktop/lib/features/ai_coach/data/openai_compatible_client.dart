import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:evolve_desktop/core/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/chat_message.dart';
import '../domain/coach_backend.dart';
import 'coach_wire.dart';

/// The user-facing (already-localized) error strings a backend hands the client
/// so the generic transport stays free of i18n. Each maps a transport failure
/// mode to the message the assistant bubble should show.
class CoachErrorMessages {
  const CoachErrorMessages({
    required this.preflightFailed,
    required this.contextTooLong,
    required this.serverTimeout,
    required this.connectionError,
    required this.apiError,
    required this.modelNotFound,
  });

  /// Connection refused / host unreachable — offline (cloud) or the local
  /// server isn't running.
  final String preflightFailed;

  /// The selected model isn't available/loaded on the server (HTTP 404 or a
  /// model-not-found error body) — the most common local first-run mistake.
  final String modelNotFound;

  /// The context grew too long for the model (HTTP 400 whose body says so).
  final String contextTooLong;

  /// The stream stalled past the (backend-tuned) timeout.
  final String serverTimeout;

  /// Any other unexpected transport error.
  final String connectionError;

  /// A non-400 HTTP error, given the status code.
  final String Function(int code) apiError;
}

/// Generic transport for any server that speaks the OpenAI `/chat/completions`
/// + `/models` dialect — OpenRouter in the cloud, Ollama / LM Studio / llama.cpp
/// locally. The only differences between deployments are the [baseUrl],
/// [headers], the timeouts, and the localized [errors]; the streaming and
/// discovery logic is identical, so it lives here once.
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({
    required this.baseUrl,
    required this.headers,
    required this.errors,
    this.connectTimeout = const Duration(seconds: 15),
    this.firstTokenTimeout = const Duration(seconds: 20),
    this.interChunkTimeout = const Duration(seconds: 15),
    http.Client Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new;

  /// OpenAI-compatible base, ending in `/v1` (e.g. `http://localhost:11434/v1`).
  final String baseUrl;
  final Map<String, String> headers;
  final CoachErrorMessages errors;

  /// Time allowed to establish the HTTP connection.
  final Duration connectTimeout;

  /// Time allowed for the FIRST streamed line — generous for local backends, a
  /// cold model can take tens of seconds to load before the first token.
  final Duration firstTokenTimeout;

  /// Time allowed between subsequent streamed lines once tokens are flowing.
  final Duration interChunkTimeout;

  final http.Client Function() _clientFactory;

  Uri get _chatUrl => Uri.parse('$baseUrl/chat/completions');
  Uri get _modelsUrl => Uri.parse('$baseUrl/models');

  /// Cheap reachability probe (`GET /models`) used by the status pill and local
  /// auto-detection. Never throws — returns false on any error/timeout.
  Future<bool> reachable() async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(_modelsUrl, headers: headers)
          .timeout(connectTimeout);
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// The models the server reports, or an empty list on any failure (the caller
  /// then falls back to manual entry).
  Future<List<CoachModel>> listModels() async {
    final client = _clientFactory();
    try {
      final response = await client
          .get(_modelsUrl, headers: headers)
          .timeout(connectTimeout);
      if (response.statusCode != 200) return const [];
      return parseModelsResponse(response.body);
    } catch (error) {
      debugPrint('[Coach] model discovery failed: $error');
      return const [];
    } finally {
      client.close();
    }
  }

  /// Streams assistant text for [history]. On any failure yields exactly one of
  /// the localized [errors] strings and completes, so the caller can render the
  /// failure inline. The first line is awaited up to [firstTokenTimeout] (cold
  /// model load), subsequent lines up to [interChunkTimeout].
  Stream<String> stream(
    List<ChatMessage> history, {
    required String systemPrompt,
    required String model,
    required double temperature,
  }) async* {
    final body = jsonEncode(
      buildChatRequestBody(
        history: history,
        systemPrompt: systemPrompt,
        model: model,
        temperature: temperature,
        stream: true,
      ),
    );

    final client = _clientFactory();
    final request = http.Request('POST', _chatUrl)
      ..headers.addAll(headers)
      ..headers['Content-Type'] = 'application/json'
      ..body = body;

    try {
      // Streaming servers (Ollama, LM Studio) can delay the response headers
      // until the model is loaded and the first token is ready, so the header
      // wait needs the generous first-token budget — not connectTimeout, which
      // would false-fail every cold model load. (reachable()/listModels() keep
      // the short connectTimeout so status + discovery stay snappy.)
      final response = await client.send(request).timeout(firstTokenTimeout);

      if (response.statusCode != 200) {
        // Bound the error-body drain so a server that flushes an error status
        // then stalls the body can't hang this stream forever.
        final errorBody = await response.stream
            .bytesToString()
            .timeout(interChunkTimeout, onTimeout: () => '');
        AppLogger.error(
          '[Coach] API error ${response.statusCode}',
          'Body: $errorBody',
        );
        yield _mapHttpError(response.statusCode, errorBody);
        return;
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final iterator = StreamIterator(lines);
      // Stay on the generous first-token budget until a real content delta
      // arrives — SSE keep-alives / comment lines / role-only openers (which
      // OpenRouter and cold local servers emit first) must NOT shrink it.
      var started = false;
      try {
        while (true) {
          final timeout = started ? interChunkTimeout : firstTokenTimeout;
          final hasNext = await iterator.moveNext().timeout(timeout);
          if (!hasNext) break;
          final chunk = parseOpenAiSseLine(iterator.current);
          if (chunk.done) break;
          if (chunk.hasContent) {
            started = true;
            yield chunk.content!;
          }
        }
      } finally {
        await iterator.cancel();
      }
    } on TimeoutException catch (error, stack) {
      AppLogger.error('[Coach] stream timeout', error, stack);
      yield errors.serverTimeout;
    } on SocketException catch (error, stack) {
      // Offline (cloud) or the local server isn't running.
      AppLogger.error('[Coach] socket error', error, stack);
      yield errors.preflightFailed;
    } on http.ClientException catch (error, stack) {
      // Connection refused surfaces here on some platforms.
      AppLogger.error('[Coach] client error', error, stack);
      yield errors.preflightFailed;
    } catch (error, stack) {
      AppLogger.error('[Coach] stream exception', error, stack);
      yield errors.connectionError;
    } finally {
      client.close();
    }
  }

  /// Maps a non-200 status + body to the most actionable localized message.
  /// A bad/unloaded model id — the most common local first-run mistake — is a
  /// 404 (or a model-not-found body) and gets its own message instead of a
  /// generic "request failed". A 400 is only treated as context-length when the
  /// body actually says so; otherwise it falls through to the coded error.
  String _mapHttpError(int statusCode, String body) {
    final lower = body.toLowerCase();
    final looksModelMissing = statusCode == 404 ||
        (lower.contains('model') &&
            (lower.contains('not found') ||
                lower.contains('not loaded') ||
                lower.contains('no such') ||
                lower.contains('does not exist')));
    if (looksModelMissing) return errors.modelNotFound;

    final looksContextLength = statusCode == 400 &&
        (lower.contains('context') ||
            lower.contains('length') ||
            lower.contains('token'));
    if (looksContextLength) return errors.contextTooLong;

    return errors.apiError(statusCode);
  }
}
