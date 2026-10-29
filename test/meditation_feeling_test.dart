import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/meditation_feeling.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/ui/meditation/widgets/feeling_widgets.dart';

void main() {
  group('Feeling scale', () {
    test('has the five labels, from 1 to 5', () {
      expect(MeditationFeeling.labels, <String>[
        'Very low',
        'Low',
        'Okay',
        'Good',
        'Very good',
      ]);
      expect(MeditationFeeling.labelFor(1), 'Very low');
      expect(MeditationFeeling.labelFor(3), 'Okay');
      expect(MeditationFeeling.labelFor(5), 'Very good');
    });

    test('has no label outside 1 to 5', () {
      expect(MeditationFeeling.labelFor(null), isNull);
      expect(MeditationFeeling.labelFor(0), isNull);
      expect(MeditationFeeling.labelFor(6), isNull);
    });

    test('reads stored values, and ignores anything else', () {
      expect(MeditationFeeling.parse(4), 4);
      expect(MeditationFeeling.parse(2.0), 2);
      expect(MeditationFeeling.parse(0), isNull);
      expect(MeditationFeeling.parse(9), isNull);
      expect(MeditationFeeling.parse('3'), isNull);
      expect(MeditationFeeling.parse(null), isNull);
    });
  });

  group('A saved practice', () {
    test('keeps what is stored, and null where nothing was recorded', () {
      final DateTime start = DateTime(2026, 10, 7, 9);
      final MeditationLogEntry entry = MeditationLogEntry(
        id: 'a',
        sessionId: 'stop',
        title: 'STOP',
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 2)),
        secondsPractised: 118,
        completed: true,
      );

      final Map<String, dynamic> map = entry.toMap();
      expect(map['sessionId'], 'stop');
      expect(map['title'], 'STOP');
      expect(map['secondsPractised'], 118);
      expect(map['completed'], isTrue);
      expect(map.containsKey('feelBefore'), isTrue);
      expect(map['feelBefore'], isNull);
      expect(map['feelAfter'], isNull);
      expect(map.keys.toSet(), <String>{
        'sessionId',
        'title',
        'startedAt',
        'endedAt',
        'secondsPractised',
        'completed',
        'feelBefore',
        'feelAfter',
      });
    });

    test(
      'is read back with its values, and safely when fields are missing',
      () {
        final MeditationLogEntry entry =
            MeditationLogEntry.fromMap(<String, dynamic>{
              'sessionId': 'stop',
              'title': 'STOP',
              'startedAt': DateTime(2026, 10, 7, 9),
              'endedAt': DateTime(2026, 10, 7, 9, 2),
              'secondsPractised': 118,
              'completed': true,
              'feelBefore': 2,
              'feelAfter': 4,
            }, id: 'abc');
        expect(entry.id, 'abc');
        expect(entry.feelBefore, 2);
        expect(entry.feelAfter, 4);
        expect(entry.completed, isTrue);

        final MeditationLogEntry sparse = MeditationLogEntry.fromMap(
          <String, dynamic>{'secondsPractised': 'x', 'feelAfter': 99},
          id: 'b',
        );
        expect(sparse.secondsPractised, 0);
        expect(sparse.completed, isFalse);
        expect(sparse.feelAfter, isNull);
        expect(sparse.sessionId, '');
      },
    );
  });

  group('Face picker', () {
    Future<List<int>> pumpPicker(
      WidgetTester tester, {
      int? value,
      FeelingPickerStyle style = FeelingPickerStyle.dark,
    }) async {
      final List<int> picked = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: FeelingPicker(
                value: value,
                style: style,
                onSelected: picked.add,
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    testWidgets('shows the five labels', (WidgetTester tester) async {
      await pumpPicker(tester);
      for (final String label in MeditationFeeling.labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('reports the face that is tapped', (WidgetTester tester) async {
      final List<int> picked = await pumpPicker(tester);

      for (int value = 1; value <= 5; value += 1) {
        await tester.tap(find.text(MeditationFeeling.labels[value - 1]));
        await tester.pump();
      }
      expect(picked, <int>[1, 2, 3, 4, 5]);
    });

    testWidgets('says which face is selected to screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPicker(tester, value: 4, style: FeelingPickerStyle.gold);

      // A screen reader must be able to activate the face, not just read it.
      expect(
        tester.getSemantics(find.bySemanticsLabel('Good')),
        isSemantics(
          label: 'Good',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Low')),
        isSemantics(
          label: 'Low',
          isButton: true,
          isSelected: false,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('fits a narrow screen without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await pumpPicker(tester, value: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
