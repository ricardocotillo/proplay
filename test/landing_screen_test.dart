import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/screens/landing_screen.dart';
import 'package:responsive_framework/responsive_framework.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Text('login-stub')),
      GoRoute(
        path: '/registration',
        builder: (_, _) => const Text('registration-stub'),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: const [
          Breakpoint(start: 0, end: 639, name: MOBILE),
          Breakpoint(start: 640, end: 767, name: 'SM'),
          Breakpoint(start: 768, end: 1023, name: TABLET),
          Breakpoint(start: 1024, end: double.infinity, name: DESKTOP),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders hero and sections', (tester) async {
    await _pump(tester, const Size(1280, 3000));
    expect(find.text('Encuentra tu próximo partido'), findsOneWidget);
    expect(find.text('Cómo funciona'), findsOneWidget);
  });

  testWidgets('CTAs navigate', (tester) async {
    await _pump(tester, const Size(1280, 3000));
    await tester.tap(find.text('Ingresar').first);
    await tester.pumpAndSettle();
    expect(find.text('login-stub'), findsOneWidget);

    GoRouter.of(tester.element(find.text('login-stub'))).go('/welcome');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta').first);
    await tester.pumpAndSettle();
    expect(find.text('registration-stub'), findsOneWidget);
  });

  testWidgets('no overflow at 360px', (tester) async {
    await _pump(tester, const Size(360, 3000));
    expect(tester.takeException(), isNull);
  });
}
