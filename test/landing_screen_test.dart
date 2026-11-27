import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/screens/landing_screen.dart';
import 'package:responsive_framework/responsive_framework.dart';

// Two pumps: the first lets go_router resolve the route, the second runs the
// transition. Not pumpAndSettle: see setUpAll.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
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
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        breakpoints: const [
          Breakpoint(start: 0, end: 639, name: MOBILE),
          Breakpoint(start: 640, end: 767, name: 'SM'),
          Breakpoint(start: 768, end: 1023, name: TABLET),
          Breakpoint(start: 1024, end: double.infinity, name: DESKTOP),
        ],
      ),
    ),
  );
  await _settle(tester);
}

void main() {
  // pumpAndSettle never returns: the event skeletons animate while the
  // (mocked, never answering) Firestore query is pending.
  // The events grid builds SessionService, which reads Firestore.instance.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('renders hero and sections', (tester) async {
    await _pump(tester, const Size(1280, 3000));
    expect(find.text('Encuentra tu próximo partido'), findsOneWidget);
    expect(find.text('Cómo funciona'), findsOneWidget);
  });

  testWidgets('CTAs navigate', (tester) async {
    await _pump(tester, const Size(1280, 3000));
    await tester.tap(find.text('Ingresar').first);
    await _settle(tester);
    expect(find.text('login-stub'), findsOneWidget);

    GoRouter.of(tester.element(find.text('login-stub'))).go('/welcome');
    await _settle(tester);
    await tester.tap(find.text('Crear cuenta').first);
    await _settle(tester);
    expect(find.text('registration-stub'), findsOneWidget);
  });

  testWidgets('no overflow at 360px', (tester) async {
    // Tests render with the Ahem font (about twice as wide as Roboto), so
    // scale text down to approximate real widths.
    await _pump(tester, const Size(360, 3000), textScale: 0.5);
    expect(tester.takeException(), isNull);
  });
}
