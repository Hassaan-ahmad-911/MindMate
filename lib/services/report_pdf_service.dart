import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../Models/report_calculator.dart';
import '../Models/report_pdf_data.dart';

/// The fonts the PDF is written in (bundled in assets/fonts).
class ReportPdfFonts {
  const ReportPdfFonts({
    required this.regular,
    required this.medium,
    required this.semiBold,
    required this.bold,
    required this.title,
  });

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font bold;

  /// Lobster Two Bold.
  final pw.Font title;

  static Future<ReportPdfFonts> load({
    Future<ByteData> Function(String path)? loader,
  }) async {
    final Future<ByteData> Function(String) read = loader ?? rootBundle.load;
    Future<pw.Font> font(String file) async =>
        pw.Font.ttf(await read('assets/fonts/$file'));
    return ReportPdfFonts(
      regular: await font('Jost-Regular.ttf'),
      medium: await font('Jost-Medium.ttf'),
      semiBold: await font('Jost-SemiBold.ttf'),
      bold: await font('Jost-Bold.ttf'),
      title: await font('LobsterTwo-Bold.ttf'),
    );
  }
}

/// Builds the one-page summary on the phone and hands it to the system
/// share sheet. Nothing is uploaded or sent by the app.
class ReportPdfService {
  static const PdfColor _navy = PdfColor.fromInt(0xFF1F3550);
  static const PdfColor _primary = PdfColor.fromInt(0xFF4C7F9A);
  static const PdfColor _light = PdfColor.fromInt(0xFF95B7CA);
  static const PdfColor _gold = PdfColor.fromInt(0xFFE4B266);
  static const PdfColor _cream = PdfColor.fromInt(0xFFFDF7EE);
  static const PdfColor _ink = PdfColor.fromInt(0xFF263845);
  static const PdfColor _muted = PdfColor.fromInt(0xFF5E6B75);
  static const PdfColor _rule = PdfColor.fromInt(0xFFE3E7EA);

  static const String notice =
      'Made by the user from self-reported entries in the MindMate app. '
      'Questionnaire scores are screening results, not a diagnosis. This is '
      'not a clinical record.';
  static const String nothingLogged = 'Nothing logged in this period.';

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String _short(DateTime d) =>
      '${d.day} ${_months[d.month - 1].substring(0, 3)}';

  /// "10 September to 9 October 2026".
  static String periodLabel(DateTime first, DateTime last) {
    final String a = first.year == last.year
        ? '${first.day} ${_months[first.month - 1]}'
        : _date(first);
    return '$a to ${_date(last)}';
  }

  /// "MindMate-summary-2026-10-09.pdf".
  static String fileName(DateTime created) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'MindMate-summary-${created.year}-${two(created.month)}-'
        '${two(created.day)}.pdf';
  }

  /// One A4 page, always.
  static pw.Document build(ReportPdfData data, ReportPdfFonts fonts) {
    final pw.Document doc = pw.Document(
      title: 'MindMate summary',
      author: 'MindMate',
    );
    pw.TextStyle style(
      double size, {
      pw.Font? font,
      PdfColor color = _ink,
      double spacing = 0,
    }) => pw.TextStyle(
      font: font ?? fonts.regular,
      fontSize: size,
      color: color,
      letterSpacing: spacing,
    );

    pw.Widget heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          pw.Text(
            text.toUpperCase(),
            style: style(10, font: fonts.bold, color: _navy, spacing: 1.2),
          ),
          pw.SizedBox(height: 4),
          pw.Container(height: 2, color: _gold),
        ],
      ),
    );

    pw.Widget line(String label, String value) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.6)),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(label, style: style(8.5, color: _muted)),
          ),
          pw.Text(value, style: style(8.5, font: fonts.semiBold)),
        ],
      ),
    );

    pw.Widget empty() => pw.Text(nothingLogged, style: style(9, color: _muted));

    final List<pw.Widget> body = <pw.Widget>[
      pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(font: fonts.title, fontSize: 26, color: _navy),
          children: <pw.InlineSpan>[
            const pw.TextSpan(text: 'Mind'),
            const pw.TextSpan(
              text: 'Mate',
              style: pw.TextStyle(color: _primary),
            ),
            const pw.TextSpan(text: ' summary'),
          ],
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        <String>[
          if (data.name.trim().isNotEmpty) data.name.trim(),
          if (data.role.trim().isNotEmpty) data.role.trim(),
          periodLabel(data.firstDay, data.lastDay),
        ].join(' · '),
        style: style(9.5, color: _muted),
      ),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _cream,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(
            color: PdfColor.fromInt(0xFFEFCD9F),
            width: 0.6,
          ),
        ),
        child: pw.Text(notice, style: style(8.5, color: _ink)),
      ),
    ];

    if (data.includeMood) {
      body.add(heading('Mood'));
      final MoodSummary? m = data.mood;
      if (m == null) {
        body.add(empty());
      } else {
        body.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  children: <pw.Widget>[
                    line(
                      'Days with a mood logged',
                      '${m.daysLogged} of ${m.totalDays}',
                    ),
                    line(
                      'Good / in between / hard days',
                      '${m.good} / ${m.between} / ${m.hard}',
                    ),
                    line(
                      'Most common moods',
                      m.topMoods.isEmpty ? '—' : m.topMoods.join(', '),
                    ),
                    line(
                      'Factors on hard days',
                      m.hardFactors.isEmpty
                          ? '—'
                          : m.hardFactors
                                .map(
                                  (MapEntry<String, int> e) =>
                                      '${e.key} ${e.value}',
                                )
                                .join(', '),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                flex: 4,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text(
                      'Daily mood (hard to good)',
                      style: style(8, color: _muted),
                    ),
                    pw.SizedBox(height: 4),
                    _moodChart(m.dailyScores),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    }

    if (data.includeCheckIns) {
      body.add(heading('Check-in results'));
      if (data.checkIns.isEmpty) {
        body.add(empty());
      } else {
        pw.Widget cell(String t, {bool head = false, bool strong = false}) =>
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 2,
              ),
              child: pw.Text(
                t,
                style: style(
                  8.5,
                  font: head || strong ? fonts.semiBold : fonts.regular,
                  color: head ? _muted : _ink,
                ),
              ),
            );
        final List<pw.TableRow> rows = <pw.TableRow>[
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _rule)),
            ),
            children: <pw.Widget>[
              cell('Questionnaire', head: true),
              cell('Date', head: true),
              cell('Score', head: true),
              cell('Range', head: true),
              cell('Previous', head: true),
            ],
          ),
        ];
        for (final CheckInRow r in data.checkIns) {
          rows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _rule, width: 0.6),
                ),
              ),
              children: <pw.Widget>[
                cell(r.scale, strong: true),
                cell(_short(r.date)),
                cell(r.score),
                cell(r.range),
                cell(r.previous),
              ],
            ),
          );
          if (r.item9Positive) {
            rows.add(
              pw.TableRow(
                children: <pw.Widget>[
                  pw.SizedBox(),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4, left: 2),
                    child: pw.Text(
                      "Question 9 answered above 'Not at all'",
                      style: style(8, font: fonts.semiBold, color: _navy),
                    ),
                  ),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pw.SizedBox(),
                ],
              ),
            );
          }
        }
        body.add(
          pw.Table(
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(1.3),
              1: pw.FlexColumnWidth(0.9),
              2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(1.3),
            },
            children: rows,
          ),
        );
      }
    }

    if (data.includePractice) {
      body.add(heading('Practice and activity'));
      final PracticeSummary? p = data.practice;
      if (p == null) {
        body.add(empty());
      } else {
        final String time = ReportCalculator.hoursMinutes(
          p.minutes,
        ).replaceAll('h ', ' h ').replaceAll('m', ' min');
        final List<pw.Widget> left = <pw.Widget>[
          line('Guided practices', '${p.sessions} sessions, $time'),
          line(
            'Feeling before / after (1 to 5)',
            p.feelBefore == null || p.feelAfter == null
                ? '—'
                : '${p.feelBefore!.toStringAsFixed(1)} / '
                      '${p.feelAfter!.toStringAsFixed(1)}',
          ),
        ];
        final List<pw.Widget> right = <pw.Widget>[
          if (p.breaks != null) line('Short breaks', '${p.breaks}'),
          if (p.journalEntries != null)
            line(
              'Journal entries',
              '${p.journalEntries} (content not included)',
            ),
        ];
        body.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(child: pw.Column(children: left)),
              pw.SizedBox(width: 18),
              pw.Expanded(child: pw.Column(children: right)),
            ],
          ),
        );
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 32),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            ...body,
            pw.Spacer(),
            pw.Container(height: 0.6, color: _rule),
            pw.SizedBox(height: 6),
            pw.Row(
              children: <pw.Widget>[
                pw.Expanded(
                  child: pw.Text(
                    'Created ${_date(data.createdAt)} in MindMate',
                    style: style(7.5, color: _muted),
                  ),
                ),
                pw.Text('Page 1 of 1', style: style(7.5, color: _muted)),
              ],
            ),
          ],
        ),
      ),
    );
    return doc;
  }

  /// A small line of daily scores (-2 to 2) with a dashed zero line. Days
  /// with nothing logged break the line. The chart stays small for long
  /// periods so the text never has to shrink.
  static pw.Widget _moodChart(List<double?> scores) {
    const double width = 190;
    const double height = 58;
    return pw.CustomPaint(
      size: const PdfPoint(width, height),
      painter: (PdfGraphics canvas, PdfPoint size) {
        double y(double v) => (v + 2) / 4 * (size.y - 4) + 2;
        canvas
          ..setStrokeColor(_light)
          ..setLineWidth(0.6)
          ..setLineDashPattern(<num>[2, 2])
          ..moveTo(0, y(0))
          ..lineTo(size.x, y(0))
          ..strokePath()
          ..setLineDashPattern();
        if (scores.isEmpty) {
          return;
        }
        final double step = scores.length < 2
            ? 0
            : size.x / (scores.length - 1);
        canvas
          ..setStrokeColor(_navy)
          ..setLineWidth(1.1)
          ..setLineCap(PdfLineCap.round)
          ..setLineJoin(PdfLineJoin.round);
        bool drawing = false;
        for (int i = 0; i < scores.length; i += 1) {
          final double? v = scores[i];
          if (v == null) {
            drawing = false;
            continue;
          }
          if (drawing) {
            canvas.lineTo(i * step, y(v));
          } else {
            canvas.moveTo(i * step, y(v));
            drawing = true;
          }
        }
        canvas.strokePath();
      },
    );
  }

  static Future<Uint8List> bytes(ReportPdfData data, ReportPdfFonts fonts) =>
      build(data, fonts).save();

  /// Opens the system share sheet. The user chooses where it goes.
  static Future<bool> share(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);
}
