import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_prefs_provider.dart';

class TutorialNotifier extends Notifier<bool> {
  static const _key = 'has_seen_tutorial';

  @override
  bool build() {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setTutorialSeen(bool seen) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool(_key, seen);
    state = seen;
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, bool>(TutorialNotifier.new);
