import 'package:shared_preferences/shared_preferences.dart';

class SavedNotesService {
  SavedNotesService._();
  static final instance = SavedNotesService._();
  static const _key = 'saved_study_note_ids';

  Future<Set<int>> getSavedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? [])
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toSet();
  }

  Future<bool> isSaved(int noteId) async =>
      (await getSavedIds()).contains(noteId);

  Future<void> setSaved(int noteId, bool saved) async {
    final ids = await getSavedIds();
    if (saved) {
      ids.add(noteId);
    } else {
      ids.remove(noteId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      ids.map((id) => id.toString()).toList()..sort(),
    );
  }
}
