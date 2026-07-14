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

  group('CoachBackendKind.fromCode', () {
    test('parses local, defaults everything else to cloud', () {
      expect(CoachBackendKind.fromCode('local'), CoachBackendKind.local);
      expect(CoachBackendKind.fromCode(' LOCAL '), CoachBackendKind.local);
      expect(CoachBackendKind.fromCode('cloud'), CoachBackendKind.cloud);
      expect(CoachBackendKind.fromCode(null), CoachBackendKind.cloud);
      expect(CoachBackendKind.fromCode('nonsense'), CoachBackendKind.cloud);
    });
  });

  group('CoachConfig', () {
    test('defaults are cloud + Ollama URL + neutral temperature', () {
      final config = CoachConfig.defaults();
      expect(config.backend, CoachBackendKind.cloud);
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
      expect(config.activeModel, kDefaultCloudModel); // still on cloud
      expect(
        config.copyWith(backend: CoachBackendKind.local).activeModel,
        'llama3.1:8b',
      );
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
