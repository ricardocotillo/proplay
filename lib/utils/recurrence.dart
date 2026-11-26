/// Most weekly copies one "Crear evento" can make (this event included).
const int kMaxOccurrences = 8;

/// Start times of [count] weekly occurrences: the same wall-clock time every
/// 7 days (a daylight-saving change on the organizer's device does not move
/// the hour).
List<DateTime> weeklyOccurrences(DateTime first, int count) => [
  for (var i = 0; i < count; i++)
    DateTime(
      first.year,
      first.month,
      first.day + 7 * i,
      first.hour,
      first.minute,
    ),
];

/// Same shift for the end time, keeping the first event's duration.
List<DateTime> weeklyEnds(DateTime firstStart, DateTime firstEnd, int count) {
  final length = firstEnd.difference(firstStart);
  return [for (final s in weeklyOccurrences(firstStart, count)) s.add(length)];
}

/// Label of one dropdown option.
String occurrencesLabel(int n) =>
    n <= 1 ? 'No repetir' : 'Repetir cada semana: $n eventos en total';
