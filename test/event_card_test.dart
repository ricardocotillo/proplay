import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proplay/models/session_model.dart';
import 'package:proplay/theme/app_theme.dart';
import 'package:proplay/widgets/event_card.dart';
import 'package:responsive_framework/responsive_framework.dart';

SessionModel session({
  String title = 'Fútbol 7 nocturno',
  double cost = 12,
  int playerCount = 3,
  int maxPlayers = 14,
  String? district = 'Miraflores',
  String? address = 'Av. Larco 123',
}) {
  final d = DateTime.now().add(const Duration(days: 3));
  return SessionModel(
    id: 's',
    templateId: 't',
    groupId: 'g',
    title: title,
    eventDate: d,
    eventEndDate: d.add(const Duration(hours: 1)),
    status: 'OPEN',
    playerCount: playerCount,
    maxPlayers: maxPlayers,
    costPerPlayer: cost,
    sport: 'fútbol',
    minAge: 0,
    maxAge: 99,
    desiredGender: 'any',
    district: district,
    locationAddress: address,
  );
}

Future<void> pump(
  WidgetTester tester,
  SessionModel s, {
  VoidCallback? onTap,
  double textScale = 1,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: const [
            Breakpoint(start: 0, end: 639, name: MOBILE),
            Breakpoint(start: 640, end: double.infinity, name: TABLET),
          ],
        ),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: EventCard(session: s, onTap: onTap ?? () {}),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('shows title, price, seats and join button', (tester) async {
    await pump(tester, session());
    expect(find.text('Fútbol 7 nocturno'), findsOneWidget);
    expect(find.text('S/ 12.00'), findsOneWidget);
    expect(find.text('3/14 cupos'), findsOneWidget);
    expect(find.text('Unirme'), findsOneWidget);
    expect(find.text('FÚTBOL · MIRAFLORES'), findsOneWidget);
  });

  testWidgets('free event shows Gratis', (tester) async {
    await pump(tester, session(cost: 0));
    expect(find.text('Gratis'), findsOneWidget);
  });

  testWidgets('full event shows Lleno and no join button', (tester) async {
    await pump(tester, session(playerCount: 14));
    expect(find.text('Lleno'), findsOneWidget);
    expect(find.text('Unirme'), findsNothing);
  });

  testWidgets('urgent event shows remaining seats', (tester) async {
    await pump(tester, session(playerCount: 12));
    expect(find.text('Últimos 2 cupos'), findsOneWidget);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var taps = 0;
    await pump(tester, session(), onTap: () => taps++);
    await tester.tap(find.text('Fútbol 7 nocturno'));
    expect(taps, 1);
  });

  testWidgets('no overflow with long text, null fields and 1.3 text scale', (
    tester,
  ) async {
    await pump(
      tester,
      session(
        title: 'Campeonato relámpago de fútbol siete nocturno en el parque',
        district: null,
        address: null,
        playerCount: 13,
      ),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout with long address renders without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      session(address: 'Avenida Javier Prado Este 4200, Santiago de Surco'),
      width: 700,
    );
    expect(tester.takeException(), isNull);
  });
}
