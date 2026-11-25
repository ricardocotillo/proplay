import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/sports.dart';

void main() {
  test('same sport and seed give the same photo', () {
    expect(sportPhoto('fútbol', 'abc'), sportPhoto('fútbol', 'abc'));
  });

  test('variant stays in 1..kSportPhotoVariants and accents are stripped', () {
    final re = RegExp(r'^assets/images/sports/futbol-([1-9])\.webp$');
    final seen = <int>{};
    for (var i = 0; i < 200; i++) {
      final m = re.firstMatch(sportPhoto('fútbol', 'event-$i'));
      expect(m, isNotNull);
      seen.add(int.parse(m!.group(1)!));
    }
    expect(seen, {for (var n = 1; n <= kSportPhotoVariants; n++) n});
  });

  test('every sport and variant has a bundled file', () {
    for (final s in kSports) {
      for (var n = 1; n <= kSportPhotoVariants; n++) {
        // Find a seed that lands on variant n.
        final seed = [for (var i = 0; i < 50; i++) '$i']
            .firstWhere((x) => sportPhoto(s.value, x).endsWith('-$n.webp'));
        final path = sportPhoto(s.value, seed);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}
