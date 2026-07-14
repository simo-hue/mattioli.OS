import 'chat_message.dart';

/// Which engine answers the coach. Persisted as its [code] in SharedPreferences.
enum CoachBackendKind {
  /// The hosted OpenRouter endpoint (data leaves the device).
  cloud,

  /// A user-run OpenAI-compatible server on this machine / LAN — Ollama, LM
  /// Studio, llama.cpp, Jan… (data never leaves the device when loopback).
  local;

  String get code => name; // 'cloud' | 'local'

  /// Tolerant parse of a persisted value; anything unrecognised → [cloud], the
  /// zero-setup default.
  static CoachBackendKind fromCode(String? code) =>
      code?.trim().toLowerCase() == local.name
      ? CoachBackendKind.local
      : CoachBackendKind.cloud;
}

/// A model the coach can talk to, as reported by the server (or entered by
/// hand). [id] is the exact identifier sent on the wire; [label] is an optional
/// friendlier display string.
class CoachModel {
  const CoachModel({required this.id, this.label});

  final String id;
  final String? label;

  /// What the UI shows — [label] when present, otherwise the raw [id].
  String get displayLabel =>
      (label == null || label!.trim().isEmpty) ? id : label!;

  @override
  bool operator ==(Object other) =>
      other is CoachModel && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// A pluggable chat engine. Both the cloud and local backends implement this
/// over the same OpenAI-compatible wire format, so the presentation layer is
/// engine-agnostic.
abstract interface class CoachBackend {
  CoachBackendKind get kind;

  /// Streams assistant text chunks for [history] under [systemPrompt] using
  /// [model]. On failure a single user-facing (already-localized) error string
  /// is yielded and the stream completes, so the caller can render the failure
  /// inline in the assistant bubble.
  Stream<String> streamResponse(
    List<ChatMessage> history, {
    required String systemPrompt,
    required String model,
    required double temperature,
  });

  /// Best-effort list of models the server exposes. Empty when discovery fails
  /// or is unsupported (the caller then falls back to manual entry).
  Future<List<CoachModel>> listModels();

  /// Cheap reachability probe used for status + auto-detect. Never throws.
  Future<bool> reachable();
}
