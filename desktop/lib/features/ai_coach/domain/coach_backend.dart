import 'chat_message.dart';

/// Thrown when the Standard proxy reports `not_subscribed` (403).
///
/// A typed exception rather than a plain string yield so the chat page can
/// distinguish "the user needs to subscribe" from every other error and show
/// the paywall modal instead of a cryptic text bubble.
class CoachNotSubscribedException implements Exception {
  const CoachNotSubscribedException();
  @override
  String toString() => 'CoachNotSubscribedException: Pro subscription required.';
}

/// Which engine answers the coach. Persisted as its [code] in SharedPreferences.
///
/// There are three rather than two because of App Store Guideline 3.1.1, which
/// rejected the app for unlocking paid functionality with a user-supplied
/// OpenRouter key. The compliant shape is the inverse: [standard] is ours, held
/// server-side and unlocked by the IAP, while [cloud] — bring-your-own-key —
/// stays free and first-class for anyone who prefers to pay the provider direct.
/// Nothing is unlocked by a key any more, because nothing is locked.
enum CoachBackendKind {
  /// Our Supabase Edge Function, holding our OpenRouter key, funded by the Evolve
  /// Pro subscription. Zero setup — and unreachable in Private mode, which keeps
  /// no account for the function to authenticate.
  standard,

  /// The user's own OpenRouter account, billed to their own key (data leaves the
  /// device). Free, and the only remote option in Private mode.
  cloud,

  /// A user-run OpenAI-compatible server on this machine / LAN — Ollama, LM
  /// Studio, llama.cpp, Jan… (data never leaves the device when loopback).
  local;

  String get code => name; // 'standard' | 'cloud' | 'local'

  /// Tolerant parse of a persisted value; anything unrecognised → [standard],
  /// the zero-setup default.
  ///
  /// This was a binary `== local ? local : cloud`, which would have silently
  /// read a persisted 'standard' back as [cloud] — sending a subscriber to a
  /// key prompt for a mode they had already paid for. Match every value by name.
  static CoachBackendKind fromCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    for (final kind in values) {
      if (kind.name == normalized) return kind;
    }
    return CoachBackendKind.standard;
  }
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
