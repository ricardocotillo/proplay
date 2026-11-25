import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/theme/app_theme.dart';
import 'package:proplay/widgets/event_card.dart';
import 'package:proplay/widgets/skeleton.dart';
import 'package:responsive_framework/responsive_framework.dart';

Future<void> _pump(
  WidgetTester tester,
  double width, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: const [
            Breakpoint(start: 0, end: 639, name: MOBILE),
            Breakpoint(start: 640, end: double.infinity, name: TABLET),
          ],
        ),
      ),
      home: const Scaffold(body: EventCardSkeleton()),
    ),
  );
}

void main() {
  testWidgets('skeleton is exactly as tall as an EventCard', (tester) async {
    await _pump(tester, 390);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Card)).height, kEventCardHeight);
  });

  testWidgets('skeleton image width follows the card breakpoint', (
    tester,
  ) async {
    for (final w in [390.0, 800.0]) {
      await _pump(tester, w);
      await tester.pump(const Duration(milliseconds: 300));
      final image = tester.getSize(find.byType(Skeleton).first);
      expect(image.width, w < 640 ? 132 : 168, reason: 'viewport $w');
    }
  });

  testWidgets('skeleton stops animating when reduced motion is on', (
    tester,
  ) async {
    await _pump(tester, 390, reduceMotion: true);
    // Would never settle if the pulse kept repeating.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
