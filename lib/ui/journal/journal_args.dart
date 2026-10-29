import '../../Models/journal_draft.dart';
import '../../Models/journal_model.dart';
import '../../Models/mood_model.dart';

/// What the "How do you want to write?" and writing screens are opened with.
class JournalWriteArgs {
  const JournalWriteArgs({
    this.type,
    this.prompt,
    this.draft,
    this.editing,
    this.linkMood,
  });

  /// The way to write. Null on the chooser means "pick the default".
  final String? type;

  /// The prompt the user started from, shown above free writing.
  final String? prompt;

  /// A draft to carry on with.
  final JournalDraft? draft;

  /// An entry being edited.
  final JournalModel? editing;

  /// A mood to link, e.g. from the mood "Saved" screen.
  final MoodModel? linkMood;
}

/// What the journal "Saved" screen is opened with.
class JournalSavedArgs {
  const JournalSavedArgs({required this.entry, required this.showSupport});

  final JournalModel entry;

  /// Show the support card instead of the tone. Never stored.
  final bool showSupport;
}

/// What the writing screen returns after "Save changes".
class JournalEditResult {
  const JournalEditResult({required this.entry, required this.showSupport});

  final JournalModel entry;
  final bool showSupport;
}
