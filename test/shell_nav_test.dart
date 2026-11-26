import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/shell_nav.dart';

void main() {
  group('activeSection', () {
    test('explore: home, feed, event pages and the /sessions alias', () {
      for (final l in ['/', '/events', '/events/abc', '/sessions']) {
        expect(activeSection(l), 'explore', reason: l);
      }
    });
    test('tickets', () {
      expect(activeSection('/tickets'), 'tickets');
      expect(activeSection('/tickets/s_u'), 'tickets');
    });
    test('groups: list, create, group pages', () {
      for (final l in [
        '/groups',
        '/create-group',
        '/group/1',
        '/group/1/create-event',
        '/group/1/edit',
      ]) {
        expect(activeSection(l), 'groups', reason: l);
      }
    });
    test('profile: hub, edit, saldo pages', () {
      for (final l in [
        '/profile',
        '/edit-profile',
        '/purchase-credits',
        '/credit-history',
        '/credit-approval',
      ]) {
        expect(activeSection(l), 'profile', reason: l);
      }
    });
    test('look-alike prefixes belong to no section', () {
      for (final l in [
        '/eventsfoo',
        '/tickets-x',
        '/groupsfoo',
        '/validate-ticket',
      ]) {
        expect(activeSection(l), isNull, reason: l);
      }
    });
  });

  test('signed-in users get the four destinations, in order', () {
    expect(navFor(signedIn: true).map((e) => e.label), [
      'Explorar',
      'Mis partidos',
      'Grupos',
      'Perfil',
    ]);
  });

  test('guests only get Explorar, pointing at the public feed', () {
    final nav = navFor(signedIn: false);
    expect(nav.map((e) => e.path), ['/events']);
    expect(nav.single.section, 'explore');
  });

  test('every destination has a unique section and a route-shaped path', () {
    final nav = navFor(signedIn: true);
    expect(nav.map((e) => e.section).toSet(), hasLength(4));
    for (final item in nav) {
      expect(item.path, startsWith('/'));
      expect(activeSection(item.path), item.section);
    }
  });

  test('bottom bar only on the top level of each destination', () {
    for (final l in [
      '/',
      '/events',
      '/sessions',
      '/tickets',
      '/groups',
      '/profile',
    ]) {
      expect(showsBottomNav(l), isTrue, reason: l);
    }
    for (final l in [
      '/events/a',
      '/tickets/a',
      '/group/1',
      '/edit-profile',
      '/purchase-credits',
    ]) {
      expect(showsBottomNav(l), isFalse, reason: l);
    }
  });
}
