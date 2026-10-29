import 'report_calculator.dart';

/// Everything the one-page PDF shows. There is deliberately no field for
/// journal text, mood notes or check-in answers: they can never be added
/// to the PDF by mistake.
class ReportPdfData {
  const ReportPdfData({
    required this.name,
    required this.role,
    required this.firstDay,
    required this.lastDay,
    required this.createdAt,
    required this.includeMood,
    required this.includeCheckIns,
    required this.includePractice,
    this.mood,
    this.checkIns = const <CheckInRow>[],
    this.practice,
  });

  final String name;
  final String role;
  final DateTime firstDay;
  final DateTime lastDay;
  final DateTime createdAt;
  final bool includeMood;
  final bool includeCheckIns;
  final bool includePractice;

  /// Null when nothing was logged in the period.
  final MoodSummary? mood;
  final List<CheckInRow> checkIns;
  final PracticeSummary? practice;
}
