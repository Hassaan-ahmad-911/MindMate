import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/journal_repository.dart';
import '../../Data/repositories/mood_repository.dart';
import '../../Models/journal_content.dart';
import '../../Models/journal_draft.dart';
import '../../Models/journal_model.dart';
import '../../Models/journal_rules.dart';
import '../../Models/mood_model.dart';
import '../../services/journal_safety_service.dart';
import '../../services/journal_tone_service.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'journal_args.dart';
import 'journal_viewmodel.dart';

/// The mood linked to an entry.
class JournalMoodLink {
  const JournalMoodLink({this.id, required this.label, this.intensity});

  factory JournalMoodLink.fromMood(MoodModel mood) {
    return JournalMoodLink(
      id: mood.id.isEmpty ? null : mood.id,
      label: mood.mood,
      intensity: mood.intensity,
    );
  }

  final String? id;
  final String label;
  final String? intensity;

  /// "Tired · Moderate".
  String get chipLabel => intensity == null ? label : '$label · $intensity';
}

/// The writing screen, for a new entry (with a draft kept on the phone) or
/// for editing one. "Let it out" ends on the keep-or-let-go screen, which
/// shares this ViewModel.
class JournalWriteViewModel extends GetxController {
  JournalWriteViewModel(
    this._repository, {
    MoodRepository? moods,
    JournalWriteArgs? args,
    DateTime Function()? clock,
  }) : _moods = moods,
       args = args ?? const JournalWriteArgs(),
       _clock = clock ?? DateTime.now,
       _startedAt = (clock ?? DateTime.now)();

  final JournalRepository _repository;
  final MoodRepository? _moods;
  final JournalWriteArgs args;
  final DateTime Function() _clock;

  /// The routes of the writing flow, removed when it ends.
  static const Set<String> flowRoutes = <String>{
    AppRoutes.journalNew,
    AppRoutes.journalWrite,
    AppRoutes.journalLetGo,
  };

  static const Duration draftDelay = Duration(seconds: 1);

  final TextEditingController titleController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();
  final Map<String, TextEditingController> _answers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};

  final RxBool isReady = false.obs;
  final RxBool hasError = false.obs;
  final RxString type = JournalTypes.free.obs;
  final RxnString activeQuestion = RxnString();
  final RxInt wordCount = 0.obs;
  final RxBool draftSaved = false.obs;
  final Rxn<JournalMoodLink> mood = Rxn<JournalMoodLink>();
  final RxList<MoodModel> dayMoods = <MoodModel>[].obs;
  final RxBool isSaving = false.obs;

  JournalContent? _content;
  final DateTime _startedAt;
  bool _moodChosen = false;
  bool _dirty = false;
  bool _finished = false;
  bool _restoring = false;
  Timer? _draftTimer;

  /// Whether the support check matched when "Done" was pressed on Let it
  /// out. Read by the keep-or-let-go screen; never stored.
  bool letItOutSupport = false;

  bool get isEditing => args.editing != null;

  JournalContent? get content => _content;

  JournalTemplate get template => _content!.templateFor(type.value);

  /// Shown above free writing when the user started from a prompt.
  String? get prompt => args.prompt ?? args.draft?.prompt;

  bool get showsPrompt =>
      prompt != null &&
      (type.value == JournalTypes.free || type.value == JournalTypes.letItOut);

  DateTime get writtenAt => args.editing?.createdAt ?? _startedAt;

  /// Each guided answer may hold its share of the 5,000 characters.
  int get answerMaxLength {
    final int count = _content == null ? 1 : template.questions.length;
    return count == 0
        ? JournalModel.bodyMaxLength
        : (JournalModel.bodyMaxLength ~/ count) - 2;
  }

  TextEditingController answerController(String questionId) {
    return _answers.putIfAbsent(questionId, () {
      final TextEditingController controller = TextEditingController();
      controller.addListener(_onTextChanged);
      return controller;
    });
  }

  FocusNode focusFor(String questionId) {
    return _focusNodes.putIfAbsent(questionId, () {
      final FocusNode node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          activeQuestion.value = questionId;
        } else if (activeQuestion.value == questionId) {
          activeQuestion.value = null;
        }
      });
      return node;
    });
  }

  @override
  void onInit() {
    super.onInit();
    titleController.addListener(_onTextChanged);
    bodyController.addListener(_onTextChanged);
    unawaited(load());
  }

  Future<void> load() async {
    hasError.value = false;
    try {
      _content = await _repository.loadContent();
    } catch (_) {
      hasError.value = true;
      return;
    }
    _restoring = true;
    _restore();
    _restoring = false;
    _updateWordCount();
    isReady.value = true;
    unawaited(_loadDayMoods(autoLink: !_moodChosen && mood.value == null));
  }

  void _restore() {
    final JournalModel? editing = args.editing;
    final JournalDraft? draft = args.draft;
    final MoodModel? linkMood = args.linkMood;

    if (editing != null) {
      type.value = editing.type;
      titleController.text = editing.title;
      if (template.isGuided) {
        for (final JournalAnswer answer in editing.answers) {
          answerController(answer.questionId).text = answer.text;
        }
      } else {
        bodyController.text = editing.body;
      }
      if (editing.hasMood) {
        mood.value = JournalMoodLink(
          id: editing.moodId,
          label: editing.moodLabel!,
          intensity: editing.moodIntensity,
        );
      }
      _moodChosen = true;
      return;
    }

    type.value = JournalTypes.normalize(draft?.type ?? args.type);
    if (draft != null) {
      titleController.text = draft.title;
      bodyController.text = draft.body;
      draft.answers.forEach((String id, String text) {
        answerController(id).text = text;
      });
      _moodChosen = draft.moodChosen;
      if (draft.moodLabel != null) {
        mood.value = JournalMoodLink(
          id: draft.moodId,
          label: draft.moodLabel!,
          intensity: draft.moodIntensity,
        );
      }
      draftSaved.value = true;
    }
    if (linkMood != null) {
      mood.value = JournalMoodLink.fromMood(linkMood);
      _moodChosen = true;
    }
  }

  // Text.

  void _onTextChanged() {
    _updateWordCount();
    if (_restoring || _finished) {
      return;
    }
    _dirty = true;
    _scheduleDraft();
  }

  void _updateWordCount() {
    if (_content == null) {
      return;
    }
    wordCount.value = JournalModel.countWords(_currentBody());
  }

  /// The text that would be saved as the body.
  String _currentBody() {
    if (_content != null && template.isGuided) {
      return JournalModel.joinAnswers(_currentAnswers());
    }
    return bodyController.text.trim();
  }

  List<JournalAnswer> _currentAnswers() {
    return template.questions
        .map(
          (JournalQuestion q) => JournalAnswer(
            questionId: q.id,
            question: q.text,
            text: answerController(q.id).text.trim(),
          ),
        )
        .toList(growable: false);
  }

  bool get hasText => _currentBody().isNotEmpty;

  /// Whether closing would lose something.
  bool get hasUnsavedText {
    if (isEditing) {
      return _dirty;
    }
    return hasText || titleController.text.trim().isNotEmpty;
  }

  /// Switches the way of writing, keeping what was typed: guided answers
  /// become free text and the other way round.
  void changeType(String newType) {
    if (_content == null || newType == type.value) {
      return;
    }
    final List<String> texts = <String>[];
    if (template.isGuided) {
      for (final JournalQuestion q in template.questions) {
        final TextEditingController c = answerController(q.id);
        if (c.text.trim().isNotEmpty) {
          texts.add(c.text.trim());
        }
        c.clear();
      }
    } else if (bodyController.text.trim().isNotEmpty) {
      texts.add(bodyController.text.trim());
      bodyController.clear();
    }

    type.value = newType;

    if (template.isGuided) {
      final List<JournalQuestion> questions = template.questions;
      for (int i = 0; i < texts.length; i += 1) {
        final int target = i < questions.length ? i : questions.length - 1;
        final TextEditingController c = answerController(questions[target].id);
        c.text = c.text.isEmpty ? texts[i] : '${c.text}\n\n${texts[i]}';
      }
    } else {
      bodyController.text = texts.join('\n\n');
    }
    _onTextChanged();
  }

  // The draft.

  void _scheduleDraft() {
    if (isEditing) {
      return;
    }
    _draftTimer?.cancel();
    _draftTimer = Timer(draftDelay, () => unawaited(_saveDraftNow()));
  }

  JournalDraft _buildDraft() {
    final Map<String, String> answers = <String, String>{};
    if (_content != null && template.isGuided) {
      for (final JournalQuestion q in template.questions) {
        answers[q.id] = answerController(q.id).text;
      }
    }
    final JournalMoodLink? link = mood.value;
    return JournalDraft(
      type: type.value,
      title: titleController.text,
      answers: answers,
      body: bodyController.text,
      prompt: prompt,
      moodId: link?.id,
      moodLabel: link?.label,
      moodIntensity: link?.intensity,
      moodChosen: _moodChosen,
      savedAt: _clock(),
    );
  }

  Future<void> _saveDraftNow() async {
    _draftTimer?.cancel();
    if (isEditing || _finished || _content == null) {
      return;
    }
    try {
      await _repository.saveDraft(_buildDraft());
      if (!isClosed && !_finished) {
        draftSaved.value = true;
      }
    } catch (_) {
      // The draft is a convenience; the screen still works without it.
    }
  }

  Future<void> _clearDraft() async {
    _draftTimer?.cancel();
    try {
      await _repository.clearDraft();
    } catch (_) {
      // Nothing to do: an old draft is offered once and can be discarded.
    }
  }

  /// "Keep draft" when closing.
  Future<void> keepDraftAndClose() async {
    await _saveDraftNow();
    _finished = true;
    Get.back<void>();
  }

  /// "Discard" when closing (or closing with nothing written).
  Future<void> discardAndClose() async {
    _finished = true;
    if (!isEditing) {
      await _clearDraft();
    }
    Get.back<void>();
  }

  // The mood link.

  Future<void> _loadDayMoods({bool autoLink = false}) async {
    final MoodRepository? moods = _moods;
    if (moods == null) {
      return;
    }
    final DateTime day = JournalDates.dayOf(writtenAt);
    try {
      final List<MoodModel> found = await moods.getMoodsBetween(
        day,
        DateTime(day.year, day.month, day.day + 1),
      );
      if (isClosed) {
        return;
      }
      dayMoods.assignAll(found);
      if (autoLink && found.isNotEmpty && !_moodChosen) {
        mood.value = JournalMoodLink.fromMood(found.first);
      }
    } catch (_) {
      // Linking a mood is optional; without moods the chip offers to log one.
    }
  }

  /// Picks a mood from the sheet, or none.
  void selectMood(MoodModel? selected) {
    mood.value = selected == null ? null : JournalMoodLink.fromMood(selected);
    _moodChosen = true;
    _dirty = true;
    _scheduleDraft();
  }

  /// Opens the mood flow and links the new mood when the user comes back.
  Future<void> logMood() async {
    final int before = dayMoods.length;
    await Get.toNamed<void>(AppRoutes.moodLog);
    await _loadDayMoods();
    if (!isClosed && dayMoods.length > before) {
      selectMood(dayMoods.first);
    }
  }

  // Saving.

  JournalModel _buildEntry() {
    final JournalContent content = _content!;
    final bool guided = template.isGuided;
    final List<JournalAnswer> answers = guided
        ? _currentAnswers()
        : const <JournalAnswer>[];
    String body = guided
        ? JournalModel.joinAnswers(answers)
        : bodyController.text.trim();
    if (body.length > JournalModel.bodyMaxLength) {
      body = body.substring(0, JournalModel.bodyMaxLength);
    }
    final JournalAnalysis analysis = JournalToneService.fromContent(
      content,
    ).analyse(body);
    final DateTime now = _clock();
    final JournalMoodLink? link = mood.value;
    final JournalModel? editing = args.editing;

    return JournalModel(
      id: editing?.id ?? '',
      title: JournalModel.titleOrFallback(titleController.text, body),
      type: type.value,
      answers: answers,
      body: body,
      moodId: link?.id,
      moodLabel: link?.label,
      moodIntensity: link?.intensity,
      tone: analysis.tone,
      toneScore: analysis.toneScore,
      topics: analysis.topics,
      wordCount: JournalModel.countWords(body),
      createdAt: editing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  bool _matchesSupport(JournalModel entry) {
    return JournalSafetyService.fromContent(
      _content!,
    ).matchesSupport('${entry.title}\n${entry.body}');
  }

  /// "Save entry" (or "Save changes", or "Keep it in my journal").
  Future<void> save() async {
    if (isSaving.value || _content == null) {
      return;
    }
    if (!hasText) {
      showMindMateSnackBar(
        'Write something first',
        template.isGuided
            ? 'Answer at least one question to save.'
            : 'Write a few words to save.',
      );
      return;
    }

    isSaving.value = true;
    _draftTimer?.cancel();
    try {
      final JournalModel entry = _buildEntry();
      final bool support = _matchesSupport(entry);

      if (isEditing) {
        await _repository.updateEntry(entry);
        _finished = true;
        JournalViewModel.active?.onEntryUpdated(entry);
        Get.back<JournalEditResult>(
          result: JournalEditResult(entry: entry, showSupport: support),
        );
        return;
      }

      final JournalModel saved = await _repository.createEntry(entry);
      _finished = true;
      await _clearDraft();
      JournalViewModel.active?.onEntrySaved(saved);
      Get.offNamedUntil<void>(
        AppRoutes.journalSaved,
        (Route<dynamic> route) => !flowRoutes.contains(route.settings.name),
        arguments: JournalSavedArgs(entry: saved, showSupport: support),
      );
    } catch (_) {
      if (!isEditing) {
        unawaited(_saveDraftNow());
      }
      showMindMateSnackBar(
        'Could not save',
        isEditing
            ? 'Check your connection and try again.'
            : 'Check your connection and try again. Your words are kept as a '
                  'draft.',
      );
    } finally {
      if (!isClosed) {
        isSaving.value = false;
      }
    }
  }

  // Let it out.

  /// "Done" on Let it out: checks for support wording, then opens the
  /// keep-or-let-go screen.
  void finishLetItOut() {
    if (_content == null) {
      return;
    }
    if (!hasText) {
      showMindMateSnackBar('Write something first', 'Write a few words.');
      return;
    }
    unawaited(_saveDraftNow());
    letItOutSupport = JournalSafetyService.fromContent(
      _content!,
    ).matchesSupport('${titleController.text}\n${_currentBody()}');
    Get.toNamed<void>(AppRoutes.journalLetGo);
  }

  /// The words shown on the keep-or-let-go screen.
  String get letItOutText => bodyController.text.trim();

  /// Deletes the draft, saves nothing and returns to Journal home.
  Future<void> letGo() async {
    _finished = true;
    await _clearDraft();
    titleController.clear();
    bodyController.clear();
    Get.until(
      (Route<dynamic> route) => !flowRoutes.contains(route.settings.name),
    );
    showMindMateSnackBar('Let go', 'Nothing was saved.');
  }

  @override
  void onClose() {
    _draftTimer?.cancel();
    titleController.dispose();
    bodyController.dispose();
    for (final TextEditingController c in _answers.values) {
      c.dispose();
    }
    for (final FocusNode node in _focusNodes.values) {
      node.dispose();
    }
    super.onClose();
  }
}
