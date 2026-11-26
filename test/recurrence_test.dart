import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/recurrence.dart';

void main() {
  test('weekly occurrences keep the weekday and the clock time', () {
    final first = DateTime(2026, 12, 3, 20, 30); // Thursday
    final all = weeklyOccurrences(first, 4);
    expect(all, [
      DateTime(2026, 12, 3, 20, 30),
      DateTime(2026, 12, 10, 20, 30),
      DateTime(2026, 12, 17, 20, 30),
      DateTime(2026, 12, 24, 20, 30),
    ]);
    expect(all.every((d) => d.weekday == DateTime.thursday), isTrue);
  });

  test('crosses month and year ends', () {
    final all = weeklyOccurrences(DateTime(2026, 12, 24, 9), 3);
    expect(all.last, DateTime(2027, 1, 7, 9));
  });

  test('one occurrence is just the first', () {
    final first = DateTime(2026, 12, 3, 20);
    expect(weeklyOccurrences(first, 1), [first]);
  });

  test('every copy keeps the first event\'s duration', () {
    final s = DateTime(2026, 12, 3, 20);
    final e = DateTime(2026, 12, 3, 21, 30);
    final ends = weeklyEnds(s, e, 3);
    expect(ends[0], e);
    expect(ends[2], DateTime(2026, 12, 17, 21, 30));
  });

  test('labels and the cap', () {
    expect(kMaxOccurrences, 8);
    expect(occurrencesLabel(1), 'No repetir');
    expect(occurrencesLabel(4), contains('4 eventos'));
  });
}
