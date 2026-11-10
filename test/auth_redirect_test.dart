import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/auth_redirect.dart';

void main() {
  test('guest on protected route goes to /welcome', () {
    expect(authRedirect(loggedIn: false, location: '/'), '/welcome');
    expect(authRedirect(loggedIn: false, location: '/group/x'), '/welcome');
  });

  test('guest may see public routes', () {
    for (final r in ['/welcome', '/login', '/registration']) {
      expect(authRedirect(loggedIn: false, location: r), isNull);
    }
  });

  test('signed-in user on public route goes to /', () {
    for (final r in ['/welcome', '/login', '/registration']) {
      expect(authRedirect(loggedIn: true, location: r), '/');
    }
  });

  test('signed-in user on protected route stays', () {
    expect(authRedirect(loggedIn: true, location: '/tickets'), isNull);
  });
}
