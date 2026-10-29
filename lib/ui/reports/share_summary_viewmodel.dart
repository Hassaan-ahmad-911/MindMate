import 'dart:typed_data';

import 'package:get/get.dart';

import '../../Data/repositories/report_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/break_log.dart';
import '../../Models/journal_model.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../../Models/report_calculator.dart';
import '../../Models/report_pdf_data.dart';
import '../../Models/user_profile.dart';
import '../../services/report_pdf_service.dart';
import '../shared/app_feedback.dart';

/// "Share a summary": choose a period and sections, then make a one-page
/// PDF on the phone and open the share sheet. Journal writing is never
/// included.
class ShareSummaryViewModel extends GetxController {
  ShareSummaryViewModel(
    this._repository, {
    DateTime Function()? clock,
    Future<ReportPdfFonts> Function()? loadFonts,
    Future<bool> Function(Uint8List bytes, String fileName)? share,
  }) : _clock = clock ?? DateTime.now,
       _loadFonts = loadFonts ?? ReportPdfFonts.load,
       _share = share ?? ReportPdfService.share;

  final ReportRepository _repository;
  final DateTime Function() _clock;
  final Future<ReportPdfFonts> Function() _loadFonts;
  final Future<bool> Function(Uint8List, String) _share;

  static const List<int> spans = <int>[14, 30, 90];

  static String spanLabel(int days) => switch (days) {
    14 => '2 weeks',
    30 => '1 month',
    _ => '3 months',
  };

  final RxInt span = 30.obs;
  final RxBool includeMood = true.obs;
  final RxBool includeCheckIns = true.obs;
  final RxBool includePractice = true.obs;
  final RxBool isBuilding = false.obs;

  ReportPdfFonts? _fonts;

  bool get hasMood => _repository.has(ReportSource.moods);

  bool get hasCheckIns => _repository.has(ReportSource.checkIns);

  bool get hasPractice =>
      _repository.has(ReportSource.practice) ||
      _repository.has(ReportSource.breaks) ||
      _repository.has(ReportSource.journal);

  bool get canCreate =>
      (hasMood && includeMood.value) ||
      (hasCheckIns && includeCheckIns.value) ||
      (hasPractice && includePractice.value);

  DateTime get lastDay => MoodStats.dayOf(_clock());

  DateTime get firstDay => MoodStats.addDays(lastDay, 1 - span.value);

  /// "10 Sep to 9 Oct".
  String get rangeLabel {
    const List<String> m = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String d(DateTime x) => '${x.day} ${m[x.month - 1]}';
    return '${d(firstDay)} to ${d(lastDay)}';
  }

  /// Builds the data for the PDF. Only what the switches allow is read.
  Future<ReportPdfData> buildData() async {
    final DateTime start = firstDay;
    final DateTime end = MoodStats.addDays(lastDay, 1);
    final bool mood = hasMood && includeMood.value;
    final bool checks = hasCheckIns && includeCheckIns.value;
    final bool practice = hasPractice && includePractice.value;

    final List<Object?> loaded = await Future.wait(<Future<Object?>>[
      mood ? _repository.moods(start, end) : Future<Object?>.value(),
      checks ? _repository.latestCheckIns(start, end) : Future<Object?>.value(),
      checks ? _repository.checkInContent() : Future<Object?>.value(),
      practice ? _repository.practice(start, end) : Future<Object?>.value(),
      practice ? _repository.breaks(start, end) : Future<Object?>.value(),
      practice ? _repository.journal(start, end) : Future<Object?>.value(),
      _repository.profile(),
    ]);
    final SourceResult<MoodModel>? moods =
        loaded[0] as SourceResult<MoodModel>?;
    final SourceResult<AssessmentLatest>? latest =
        loaded[1] as SourceResult<AssessmentLatest>?;
    final AssessmentContent? content = loaded[2] as AssessmentContent?;
    final SourceResult<MeditationLogEntry>? sessions =
        loaded[3] as SourceResult<MeditationLogEntry>?;
    final SourceResult<BreakLogEntry>? breaks =
        loaded[4] as SourceResult<BreakLogEntry>?;
    final SourceResult<JournalSummary>? journal =
        loaded[5] as SourceResult<JournalSummary>?;
    final UserProfile? profile = loaded[6] as UserProfile?;

    for (final SourceResult<Object>? r in <SourceResult<Object>?>[
      moods,
      latest,
      sessions,
      breaks,
      journal,
    ]) {
      if (r != null && r.failed) {
        throw StateError('A source did not load');
      }
    }

    return ReportPdfData(
      name: profile?.name ?? '',
      role: profile?.role ?? '',
      firstDay: start,
      lastDay: lastDay,
      createdAt: _clock(),
      includeMood: mood,
      includeCheckIns: checks,
      includePractice: practice,
      mood: moods?.items == null
          ? null
          : ReportCalculator.moodSummary(moods!.items!, start: start, end: end),
      checkIns: latest?.items == null || content == null
          ? const []
          : ReportCalculator.checkInRows(latest!.items!, content),
      practice: !practice
          ? null
          : ReportCalculator.practiceSummary(
              sessions: sessions?.items ?? const <MeditationLogEntry>[],
              breaks: breaks?.items,
              journal: journal?.items,
            ),
    );
  }

  /// "Create PDF": builds it on the phone, then opens the share sheet.
  Future<void> createPdf() async {
    if (isBuilding.value || !canCreate) {
      return;
    }
    isBuilding.value = true;
    try {
      final ReportPdfData data = await buildData();
      final ReportPdfFonts fonts = _fonts ??= await _loadFonts();
      final Uint8List bytes = await ReportPdfService.bytes(data, fonts);
      await _share(bytes, ReportPdfService.fileName(data.createdAt));
    } catch (_) {
      showMindMateSnackBar(
        'Could not make the PDF',
        'Check your connection and try again.',
      );
    } finally {
      if (!isClosed) {
        isBuilding.value = false;
      }
    }
  }

  void back() => Get.back<void>();
}
