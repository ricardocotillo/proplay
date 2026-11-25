import 'package:intl/intl.dart';

/// "Hoy 20:00", "Mañana 19:00" or "vie 13 nov, 20:00". [now] is passed in so
/// the result is deterministic. Needs `initializeDateFormatting('es')`.
String eventWhenLabel(DateTime now, DateTime date) {
  final hm = DateFormat('HH:mm').format(date);
  // Calendar-day difference (compares dates, not durations: DST-safe).
  final diff = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  if (diff == 0) return 'Hoy $hm';
  if (diff == 1) return 'Mañana $hm';
  return DateFormat('EEE d MMM, HH:mm', 'es').format(date);
}

/// Seat progress for the card: fill [fraction], [label] and [urgent] (<= 3 left).
({double fraction, String label, bool urgent}) seatsInfo(
  int playerCount,
  int maxPlayers,
) {
  if (maxPlayers <= 0) {
    return (
      fraction: 0,
      label: '$playerCount/$maxPlayers cupos',
      urgent: false,
    );
  }
  final fraction = (playerCount / maxPlayers).clamp(0.0, 1.0);
  final left = maxPlayers - playerCount;
  if (left <= 0) return (fraction: 1, label: 'Lleno', urgent: false);
  if (left <= 3) {
    return (
      fraction: fraction,
      label: left == 1 ? 'Último cupo' : 'Últimos $left cupos',
      urgent: true,
    );
  }
  return (
    fraction: fraction,
    label: '$playerCount/$maxPlayers cupos',
    urgent: false,
  );
}
