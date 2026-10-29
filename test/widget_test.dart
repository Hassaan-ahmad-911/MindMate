import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindmate/ui/app/mindmate_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // Tests have no network; use bundled fonts or the fallback.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Splash plays, then a new user sees Welcome', (
    WidgetTester tester,
  ) async {
    // Left behind by the old onboarding slides; the app removes it.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_completed': true,
    });
    await tester.pumpWidget(const MindMateApp());
    await tester.pump();

    expect(find.bySemanticsLabel('MindMate'), findsOneWidget);

    // The intro lasts 4.2 seconds; the breathing loop never settles, so pump
    // past it instead of waiting for the animation to stop.
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Welcome to MindMate'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Track How You Feel'), findsNothing);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('onboarding_completed'), isFalse);
  });
}
