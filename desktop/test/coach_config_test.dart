// Pure-logic coverage for the local-AI coach configuration: base-URL
// canonicalization, loopback/LAN detection (the zero-egress privacy predicate),
// preset matching, temperature clamping, and CoachConfig defaults/copyWith.
import 'package:evolve_desktop/features/ai_coach/domain/coach_backend.dart';
import 'package:evolve_desktop/features/ai_coach/domain/coach_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('defaults empty/null to the Ollama base', () {
      expect(normalizeBaseUrl(null), kDefaultLocalBaseUrl);
      expect(normalizeBaseUrl(''), kDefaultLocalBaseUrl);
      expect(normalizeBaseUrl('   '), kDefaultLocalBaseUrl);
    });

    test('prepends http:// when no scheme is present', () {
      expect(normalizeBaseUrl('localhost:11434/v1'), 'http://localhost:11434/v1');
    });

    test('appends /v1 to a bare host:port', () {
      expect(normalizeBaseUrl('http://localhost:11434'), 'http://localhost:11434/v1');
      expect(normalizeBaseUrl('localhost:1234'), 'http://localhost:1234/v1');
      expect(normalizeBaseUrl('http://localhost:11434/'), 'http://localhost:11434/v1');
    });

    test('strips trailing slashes but keeps an explicit path', () {
      expect(
        normalizeBaseUrl('http://localhost:1234/v1/'),
        'http://localhost:1234/v1',
      );
      expect(
        normalizeBaseUrl('https://example.com/api/v1'),
        'https://example.com/api/v1',
      );
    });

    test('preserves https and custom hosts', () {
      expect(
        normalizeBaseUrl('https://openrouter.ai/api/v1'),
        'https://openrouter.ai/api/v1',
      );
    });

    test('keeps IPv6 brackets when appending /v1 to a bare host', () {
      expect(normalizeBaseUrl('http://[::1]:11434'), 'http://[::1]:11434/v1');
      expect(
        normalizeBaseUrl('http://[::1]:11434/v1'),
        'http://[::1]:11434/v1',
      );
    });

    test('drops query/fragment and lowercases the scheme on path-bearing URLs', () {
      expect(
        normalizeBaseUrl('http://localhost:11434/v1?x=1'),
        'http://localhost:11434/v1',
      );
      expect(
        normalizeBaseUrl('HTTP://localhost:11434/v1#frag'),
        'http://localhost:11434/v1',
      );
      expect(normalizeBaseUrl('HTTP://localhost:11434'), 'http://localhost:11434/v1');
    });
  });

  group('isLoopbackOrLan', () {
    test('true for loopback hosts', () {
      expect(isLoopbackOrLan('http://localhost:11434/v1'), isTrue);
      expect(isLoopbackOrLan('http://127.0.0.1:1234/v1'), isTrue);
      expect(isLoopbackOrLan('http://0.0.0.0:11434'), isTrue);
      expect(isLoopbackOrLan('mac-studio.local:11434'), isTrue);
    });

    test('true for RFC-1918 private ranges', () {
      expect(isLoopbackOrLan('http://192.168.1.50:11434/v1'), isTrue);
      expect(isLoopbackOrLan('http://10.0.0.9:1234'), isTrue);
      expect(isLoopbackOrLan('http://172.16.5.4:11434'), isTrue);
      expect(isLoopbackOrLan('http://172.31.255.255:11434'), isTrue);
    });

    test('true for the whole 127.0.0.0/8 loopback block', () {
      expect(isLoopbackOrLan('http://127.0.0.2:11434'), isTrue);
      expect(isLoopbackOrLan('http://127.1.2.3:11434/v1'), isTrue);
    });

    test('true for IPv6 loopback / ULA / link-local and .localhost', () {
      expect(isLoopbackOrLan('http://[fd00::1]:11434/v1'), isTrue); // ULA
      expect(isLoopbackOrLan('http://[fc00::9]:11434'), isTrue); // ULA
      expect(isLoopbackOrLan('http://[fe80::1]:11434'), isTrue); // link-local
      expect(isLoopbackOrLan('http://foo.localhost:11434'), isTrue);
    });

    test('false for public / tunnelled hosts (badge as remote)', () {
      expect(isLoopbackOrLan('https://my-tunnel.ngrok.io/v1'), isFalse);
      expect(isLoopbackOrLan('http://172.32.0.1:11434'), isFalse); // just outside /12
      expect(isLoopbackOrLan('http://8.8.8.8:11434'), isFalse);
      expect(isLoopbackOrLan('https://openrouter.ai/api/v1'), isFalse);
      expect(isLoopbackOrLan('http://[2001:4860:4860::8888]:11434'), isFalse); // public IPv6
    });

    test('false for unparseable input', () {
      expect(isLoopbackOrLan(''), isFalse);
      expect(isLoopbackOrLan('   '), isFalse);
    });
  });

  group('LocalServerPreset', () {
    test('carries the expected base URLs', () {
      expect(LocalServerPreset.ollama.baseUrl, 'http://localhost:11434/v1');
      expect(LocalServerPreset.lmStudio.baseUrl, 'http://localhost:1234/v1');
      expect(LocalServerPreset.custom.baseUrl, '');
    });

    test('matches a normalized URL back to its preset', () {
      expect(LocalServerPreset.match('localhost:11434'), LocalServerPreset.ollama);
      expect(
        LocalServerPreset.match('http://localhost:1234/v1/'),
        LocalServerPreset.lmStudio,
      );
      expect(
        LocalServerPreset.match('http://192.168.1.9:11434/v1'),
        LocalServerPreset.custom,
      );
    });
  });

  group('clampTemperature', () {
    test('clamps to [0, 2]', () {
      expect(clampTemperature(-1), 0.0);
      expect(clampTemperature(0.7), 0.7);
      expect(clampTemperature(3.5), 2.0);
    });
  });

  group('effectiveCoachBackend', () {
    test('PRIVATE MODE NEVER GETS STANDARD', () {
      // The reason this function exists. Private mode keeps no account, and
      // `Supabase.initialize` is skipped there entirely — so a persisted
      // Standard choice must not route at a proxy that can only refuse it.
      expect(
        effectiveCoachBackend(
          chosen: CoachBackendKind.standard,
          isPrivate: true,
        ),
        CoachBackendKind.cloud,
        reason: 'falls back to BYOK, which still works without an account',
      );
    });

    test('private mode leaves the two engines it CAN serve alone', () {
      for (final kind in [CoachBackendKind.cloud, CoachBackendKind.local]) {
        expect(
          effectiveCoachBackend(chosen: kind, isPrivate: true),
          kind,
          reason: '${kind.name} needs no account and must not be rewritten',
        );
      }
    });

    test('outside private mode everything resolves to Standard (account is '
        'Standard-only)', () {
      // BYOK and Local are Private-mode features. A signed-in user's persisted
      // choice is preserved for when they return to Private mode, but never
      // serves in account mode, where the Pro-funded proxy is the only coach.
      for (final kind in CoachBackendKind.values) {
        expect(
          effectiveCoachBackend(chosen: kind, isPrivate: false),
          CoachBackendKind.standard,
          reason: '${kind.name} must resolve to Standard in account mode',
        );
      }
    });
  });

  group('resolveStandardCoachStatus', () {
    test('signed-in subscriber on a configured build is ready', () {
      expect(
        resolveStandardCoachStatus(
          isPrivate: false,
          isConfigured: true,
          hasSession: true,
          isPro: true,
        ),
        StandardCoachStatus.ready,
      );
    });

    test('PRIVATE MODE IS UNAVAILABLE even reporting Pro and a session', () {
      // `desktopIsProProvider` returns true unconditionally in private mode, so
      // an entitlement check that ran before the data-mode check would call this
      // ready and send the request to a function with nothing to authenticate.
      expect(
        resolveStandardCoachStatus(
          isPrivate: true,
          isConfigured: true,
          hasSession: true,
          isPro: true, // as private mode ALWAYS reports
        ),
        StandardCoachStatus.unavailablePrivate,
      );
    });

    test('a signed-in free user needs Pro — this is the 3.1.1 shape', () {
      // The purchase is the unlock. Not a key, not a code: the subscription.
      expect(
        resolveStandardCoachStatus(
          isPrivate: false,
          isConfigured: true,
          hasSession: true,
          isPro: false,
        ),
        StandardCoachStatus.needsPro,
      );
    });

    test('signed out reads as needsSignIn, not needsPro', () {
      // Distinct on purpose: telling a subscriber mid-token-refresh to buy a
      // subscription they already own is worse than saying nothing.
      expect(
        resolveStandardCoachStatus(
          isPrivate: false,
          isConfigured: true,
          hasSession: false,
          isPro: true,
        ),
        StandardCoachStatus.needsSignIn,
      );
    });

    test('an unconfigured build is our problem, not the user\'s', () {
      // No Supabase URL compiled in → there is no function to call. Must not
      // read as "sign in" or "subscribe": neither would fix it.
      expect(
        resolveStandardCoachStatus(
          isPrivate: false,
          isConfigured: false,
          hasSession: true,
          isPro: true,
        ),
        StandardCoachStatus.unavailableUnconfigured,
      );
    });
  });

  group('CoachBackendKind.fromCode', () {
    test('parses every value by name, defaulting to standard', () {
      expect(CoachBackendKind.fromCode('local'), CoachBackendKind.local);
      expect(CoachBackendKind.fromCode(' LOCAL '), CoachBackendKind.local);
      expect(CoachBackendKind.fromCode('cloud'), CoachBackendKind.cloud);
      expect(CoachBackendKind.fromCode('standard'), CoachBackendKind.standard);
      expect(CoachBackendKind.fromCode(null), CoachBackendKind.standard);
      expect(CoachBackendKind.fromCode('nonsense'), CoachBackendKind.standard);
    });

    test('EVERY value round-trips through its own code', () {
      // The parse was a binary `== local ? local : cloud`, which would have read
      // a persisted 'standard' back as cloud — sending a subscriber to a key
      // prompt for the mode they had already paid for. A fourth engine would
      // walk into the same trap, so assert the property, not the cases.
      for (final kind in CoachBackendKind.values) {
        expect(
          CoachBackendKind.fromCode(kind.code),
          kind,
          reason: '${kind.name} must survive a save/load round-trip',
        );
      }
    });
  });

  group('CoachConfig', () {
    test('defaults are standard + Ollama URL + neutral temperature', () {
      final config = CoachConfig.defaults();
      // Standard, not cloud: a fresh install must not land on "paste an API
      // key", which is the surface Guideline 3.1.1 objected to.
      expect(config.backend, CoachBackendKind.standard);
      expect(config.localBaseUrl, kDefaultLocalBaseUrl);
      expect(config.cloudModel, kDefaultCloudModel);
      expect(config.localModel, isNull);
      expect(config.temperature, kDefaultTemperature);
      expect(config.systemPromptOverride, isNull);
    });

    test('activeModel follows the backend', () {
      final config = CoachConfig.defaults().copyWith(
        localModel: 'llama3.1:8b',
      );
      expect(config.activeModel, kStandardCoachModel); // still on standard
      expect(
        config.copyWith(backend: CoachBackendKind.local).activeModel,
        'llama3.1:8b',
      );
      expect(
        config.copyWith(backend: CoachBackendKind.cloud).activeModel,
        kDefaultCloudModel,
      );
    });

    test('standard reports the server pin, not the BYOK model preference', () {
      // The two are different facts that happen to share a string today. If a
      // user hand-picks a cloud model, Standard must not claim to be running it
      // — the Edge Function pins the model server-side and ignores the body.
      final config = CoachConfig.defaults().copyWith(
        backend: CoachBackendKind.standard,
        cloudModel: 'anthropic/claude-sonnet-4.5',
      );
      expect(config.activeModel, kStandardCoachModel);
    });

    test('activeModel is empty when local has no model yet', () {
      final config = CoachConfig.defaults().copyWith(
        backend: CoachBackendKind.local,
      );
      expect(config.activeModel, '');
    });

    test('copyWith clears are explicit and non-destructive', () {
      final base = CoachConfig.defaults().copyWith(
        localModel: 'qwen2.5',
        systemPromptOverride: 'Be terse.',
      );
      expect(base.copyWith(clearLocalModel: true).localModel, isNull);
      expect(base.copyWith(clearSystemPrompt: true).systemPromptOverride, isNull);
      // A plain copyWith preserves them.
      expect(base.copyWith(temperature: 1.0).localModel, 'qwen2.5');
      expect(base.copyWith(temperature: 1.0).systemPromptOverride, 'Be terse.');
    });

    test('value equality', () {
      expect(CoachConfig.defaults(), CoachConfig.defaults());
      expect(
        CoachConfig.defaults(),
        isNot(CoachConfig.defaults().copyWith(temperature: 1.1)),
      );
    });
  });

  group('per-product (per-base-URL) local model memory', () {
    const ollama = kDefaultLocalBaseUrl; // :11434
    const lmStudio = 'http://localhost:1234/v1';

    test('localModel reads the entry for the ACTIVE base URL', () {
      // A pick made on Ollama is Ollama's alone — pointing at LM Studio reads
      // back null there (nothing remembered yet), not the Ollama id, which the
      // LM Studio server would answer with "model not found".
      final onOllama = CoachConfig.defaults().copyWith(localModel: 'llama3.1:8b');
      expect(onOllama.localModel, 'llama3.1:8b');

      final onLmStudio = onOllama.copyWith(localBaseUrl: lmStudio);
      expect(onLmStudio.localModel, isNull);
      expect(onLmStudio.localModels[ollama], 'llama3.1:8b');
    });

    test('each product keeps its own model across round-trips', () {
      final config = CoachConfig.defaults()
          .copyWith(localModel: 'llama3.1:8b') // on Ollama
          .copyWith(localBaseUrl: lmStudio, localModel: 'qwen2.5-7b');

      expect(config.localModel, 'qwen2.5-7b'); // active = LM Studio
      expect(config.copyWith(localBaseUrl: ollama).localModel, 'llama3.1:8b');
    });

    test('copyWith(localModel:) keys at the RESULTING base URL', () {
      // Setting the model and switching product in one call must land the model
      // on the new URL, never cross the wires onto the old one.
      final config = CoachConfig.defaults().copyWith(
        localBaseUrl: lmStudio,
        localModel: 'qwen2.5-7b',
      );
      expect(config.localModels[lmStudio], 'qwen2.5-7b');
      expect(config.localModels.containsKey(ollama), isFalse);
    });

    test('clearLocalModel forgets only the active URL', () {
      final config = CoachConfig.defaults()
          .copyWith(localModel: 'llama3.1:8b')
          .copyWith(localBaseUrl: lmStudio, localModel: 'qwen2.5-7b');

      final cleared = config.copyWith(clearLocalModel: true); // on LM Studio
      expect(cleared.localModel, isNull);
      expect(cleared.copyWith(localBaseUrl: ollama).localModel, 'llama3.1:8b');
    });

    test('equality and hashCode fold in the model map', () {
      final a = CoachConfig.defaults().copyWith(localModel: 'llama3.1:8b');
      final b = CoachConfig.defaults().copyWith(localModel: 'llama3.1:8b');
      final c = CoachConfig.defaults().copyWith(localModel: 'qwen2.5-7b');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('effectiveLocalModelOptions', () {
    const discovered = [CoachModel(id: 'llama3.1:8b'), CoachModel(id: 'qwen2.5:7b')];

    test('returns the discovered list unchanged when no current model', () {
      expect(effectiveLocalModelOptions(discovered, null), discovered);
      expect(effectiveLocalModelOptions(discovered, '  '), discovered);
    });

    test('returns the discovered list when the current model is listed', () {
      expect(
        effectiveLocalModelOptions(discovered, 'qwen2.5:7b'),
        discovered,
      );
    });

    test('appends a hand-typed model absent from the server list', () {
      final options = effectiveLocalModelOptions(discovered, 'phi3:mini');
      expect(options.map((m) => m.id), [
        'llama3.1:8b',
        'qwen2.5:7b',
        'phi3:mini',
      ]);
    });

    test('surfaces the current model even when discovery returned nothing', () {
      final options = effectiveLocalModelOptions(const [], 'phi3:mini');
      expect(options.single.id, 'phi3:mini');
    });
  });

  group('CoachModel', () {
    test('displayLabel falls back to id', () {
      expect(const CoachModel(id: 'llama3').displayLabel, 'llama3');
      expect(
        const CoachModel(id: 'llama3', label: 'Llama 3').displayLabel,
        'Llama 3',
      );
      expect(const CoachModel(id: 'x', label: '  ').displayLabel, 'x');
    });
  });
}
