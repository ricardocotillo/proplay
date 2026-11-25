import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:proplay/utils/event_format.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('eventWhenLabel', () {
    final now = DateTime(2026, 11, 13, 18, 0);

    test('same day is Hoy', () {
      expect(eventWhenLabel(now, DateTime(2026, 11, 13, 20, 0)), 'Hoy 20:00');
    });

    test('next day is Mañana', () {
      expect(
        eventWhenLabel(now, DateTime(2026, 11, 14, 19, 0)),
        'Mañana 19:00',
      );
    });

    test('across midnight is Mañana', () {
      expect(
        eventWhenLabel(
          DateTime(2026, 11, 13, 23, 30),
          DateTime(2026, 11, 14, 0, 30),
        ),
        'Mañana 00:30',
      );
    });

    test('month rollover is Mañana', () {
      expect(
        eventWhenLabel(DateTime(2026, 11, 30, 20), DateTime(2026, 12, 1, 8)),
        'Mañana 08:00',
      );
    });

    test('later dates use the weekday format', () {
      final label = eventWhenLabel(now, DateTime(2026, 11, 20, 20, 0));
      expect(label, contains('20'));
      expect(label, contains('nov'));
      expect(label, isNot(startsWith('Hoy')));
    });
  });

  group('seatsInfo', () {
    test('empty', () {
      final s = seatsInfo(0, 14);
      expect((s.fraction, s.label, s.urgent), (0.0, '0/14 cupos', false));
    });

    test('plenty left', () {
      final s = seatsInfo(7, 14);
      expect((s.fraction, s.label, s.urgent), (0.5, '7/14 cupos', false));
    });

    test('few left is urgent', () {
      final s = seatsInfo(12, 14);
      expect((s.label, s.urgent), ('Últimos 2 cupos', true));
    });

    test('one left', () {
      expect(seatsInfo(13, 14).label, 'Último cupo');
    });

    test('full', () {
      final s = seatsInfo(14, 14);
      expect((s.fraction, s.label, s.urgent), (1.0, 'Lleno', false));
    });

    test('zero max does not crash', () {
      expect(seatsInfo(0, 0).fraction, 0);
    });
  });
}
