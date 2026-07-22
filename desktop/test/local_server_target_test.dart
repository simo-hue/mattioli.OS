// Coverage for the product descriptor. These assertions exist because the
// bundle ids and install paths used to live in AppDelegate.swift, where NO
// Flutter test could reach them — so a typo or a stale id was both unverified
// and unverifiable. Now it is ordinary data.
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:evolve_desktop/features/ai_coach/domain/local_server_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('forPreset / forBaseUrl', () {
    test('every preset resolves, and to itself', () {
      for (final preset in LocalServerPreset.values) {
        expect(LocalServerTarget.forPreset(preset).preset, preset);
      }
    });

    test('a preset base URL resolves to that product', () {
      expect(
        LocalServerTarget.forBaseUrl('http://localhost:11434/v1').preset,
        LocalServerPreset.ollama,
      );
      expect(
        LocalServerTarget.forBaseUrl('http://localhost:1234/v1').preset,
        LocalServerPreset.lmStudio,
      );
    });

    test(
      'an un-normalized URL still resolves (matching goes through normalize)',
      () {
        expect(
          LocalServerTarget.forBaseUrl('localhost:1234').preset,
          LocalServerPreset.lmStudio,
        );
        expect(
          LocalServerTarget.forBaseUrl('http://localhost:11434/v1/').preset,
          LocalServerPreset.ollama,
        );
      },
    );

    test(
      'an unknown endpoint falls back to custom, which cannot be launched',
      () {
        final target = LocalServerTarget.forBaseUrl('http://10.0.0.5:8080/v1');
        expect(target.preset, LocalServerPreset.custom);
        expect(target.canLaunch, isFalse);
        expect(target.bundleIds, isEmpty);
      },
    );
  });

  group('launchable targets', () {
    test('Ollama and LM Studio are launchable and carry a path fallback', () {
      for (final target in [
        LocalServerTarget.ollama,
        LocalServerTarget.lmStudio,
      ]) {
        expect(target.canLaunch, isTrue, reason: target.displayName);
        expect(target.bundleIds, isNotEmpty, reason: target.displayName);
        // The path fallback is what keeps an unconfirmed bundle id a SOFT
        // failure: a default install resolves even if every id misses.
        expect(target.appPath, startsWith('/Applications/'));
        expect(target.appPath, endsWith('.app'));
        expect(target.downloadUrl, startsWith('https://'));
      }
    });

    test('LM Studio carries its verified bundle id', () {
      // Triangulated from the Homebrew cask, the brew API JSON, and an
      // independent Info.plist scrape. If an on-device check ever contradicts
      // this, THIS is the line to change — not a Swift constant.
      expect(
        LocalServerTarget.lmStudio.bundleIds,
        contains('ai.elementlabs.lmstudio'),
      );
    });

    test('base URL hints agree with the presets they describe', () {
      for (final target in [
        LocalServerTarget.ollama,
        LocalServerTarget.lmStudio,
      ]) {
        expect(
          normalizeBaseUrl(target.baseUrlHint),
          normalizeBaseUrl(target.preset.baseUrl),
          reason: target.displayName,
        );
      }
    });
  });

  group('per-product tuning', () {
    // LM Studio defaults to Auto-Evict (at most one JIT-loaded model resident)
    // with a 60-minute TTL, so cold loads are routine rather than a first-run
    // event — every model switch pays one. Inheriting Ollama's 60s budget would
    // report a healthy cold load as a timeout.
    test('LM Studio gets a larger first-token budget than Ollama', () {
      expect(
        LocalServerTarget.lmStudio.firstTokenTimeout,
        greaterThan(LocalServerTarget.ollama.firstTokenTimeout),
      );
    });

    test('LM Studio gets a longer start poll than Ollama (Electron boot)', () {
      expect(
        LocalServerTarget.lmStudio.startPollAttempts,
        greaterThan(LocalServerTarget.ollama.startPollAttempts),
      );
    });

    // This flag is what makes a launch timeout mean different things per
    // product, and it drives every piece of LM-Studio-specific copy.
    test('only LM Studio needs its server switched on separately', () {
      expect(LocalServerTarget.lmStudio.serverIsOptIn, isTrue);
      expect(LocalServerTarget.ollama.serverIsOptIn, isFalse);
      expect(LocalServerTarget.custom.serverIsOptIn, isFalse);
    });

    // Ollama's `llama3.1:8b` and LM Studio's publisher-prefixed repo ids look
    // nothing alike, and this hint is shown in the manual-entry field a stuck
    // user lands in — so the wrong example is worse than none.
    test('model hints differ per product', () {
      expect(
        LocalServerTarget.lmStudio.modelHint,
        isNot(LocalServerTarget.ollama.modelHint),
      );
    });
  });
}
