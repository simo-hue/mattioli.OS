import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteNotifier extends AsyncNotifier<String> {
  final _prefs = SharedPreferencesAsync();
  static const _key = 'quick_notes';

  @override
  Future<String> build() async {
    final note = await _prefs.getString(_key);
    return note ?? '';
  }

  Future<void> updateNote(String newNote) async {
    state = AsyncData(newNote);
    await _prefs.setString(_key, newNote);
  }
}

final noteProvider = AsyncNotifierProvider<NoteNotifier, String>(() {
  return NoteNotifier();
});
