import 'package:shared_preferences/shared_preferences.dart';

import '../Models/journal_draft.dart';

/// Keeps one unsaved journal entry on this phone, per signed-in user. It is
/// never uploaded.
class JournalDraftStore {
  static String _key(String uid) => 'journal_draft_$uid';

  Future<JournalDraft?> read(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return JournalDraft.decode(prefs.getString(_key(uid)));
  }

  Future<void> write(String uid, JournalDraft draft) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), draft.encode());
  }

  Future<void> clear(String uid) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
