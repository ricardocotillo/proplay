import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/district_utils.dart';

void main() {
  test('prefers locality', () {
    expect(
      districtFromComponents([
        (name: 'Lima', types: ['administrative_area_level_2']),
        (name: ' Miraflores ', types: ['locality', 'political']),
        (name: 'Otro', types: ['sublocality']),
      ]),
      'Miraflores',
    );
  });

  test('falls back to sublocality', () {
    expect(
      districtFromComponents([
        (name: 'San Isidro', types: ['sublocality', 'political']),
      ]),
      'San Isidro',
    );
  });

  test('returns null when nothing matches', () {
    expect(
      districtFromComponents([
        (name: 'Perú', types: ['country']),
      ]),
      isNull,
    );
    expect(districtFromComponents([]), isNull);
  });
}
