import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/shell_nav.dart';

void main() {
  group('activeNavPath', () {
    test('root', () => expect(activeNavPath('/'), '/'));
    test('events, detail and the /sessions alias', () {
      for (final l in ['/events', '/events/abc', '/sessions']) {
        expect(activeNavPath(l), '/events', reason: l);
      }
    });
    test('tickets', () => expect(activeNavPath('/tickets'), '/tickets'));
    test('other pages and look-alike prefixes have no active item', () {
      for (final l in [
        '/group/1',
        '/edit-profile',
        '/purchase-credits',
        '/eventsfoo',
        '/tickets-x',
      ]) {
        expect(activeNavPath(l), isNull, reason: l);
      }
    });
  });

  test('guests only see Eventos', () {
    expect(navFor(signedIn: false).map((e) => e.path), ['/events']);
    expect(navFor(signedIn: true), hasLength(3));
  });
}
