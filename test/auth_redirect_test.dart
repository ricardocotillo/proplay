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

  test('signed-in user on public route returns to a safe ?from=', () {
    expect(
      authRedirect(
        loggedIn: true,
        location: '/registration',
        from: '/events/a',
      ),
      '/events/a',
    );
    expect(
      authRedirect(loggedIn: true, location: '/login', from: '//evil.com'),
      '/',
    );
    expect(
      authRedirect(loggedIn: true, location: '/login', from: 'https://x.pe'),
      '/',
    );
    expect(
      authRedirect(loggedIn: true, location: '/login', from: '/login'),
      '/',
    );
    expect(
      authRedirect(loggedIn: false, location: '/login', from: '/x'),
      isNull,
    );
  });

  test('authPath adds from only when safe', () {
    expect(authPath('/login'), '/login');
    expect(authPath('/login', from: '/events/a'), '/login?from=%2Fevents%2Fa');
    expect(authPath('/registration', from: '/welcome'), '/registration');
  });

  test('events feed is open to guests and signed-in users', () {
    for (final r in ['/events', '/events/abc']) {
      expect(authRedirect(loggedIn: false, location: r), isNull);
      expect(authRedirect(loggedIn: true, location: r), isNull);
    }
  });

  test('signed-in user on protected route stays', () {
    expect(authRedirect(loggedIn: true, location: '/tickets'), isNull);
  });

  test('credit approval is hidden from non super users', () {
    expect(adminRedirect(superUser: false, location: '/credit-approval'), '/');
    expect(
      adminRedirect(superUser: true, location: '/credit-approval'),
      isNull,
    );
    expect(
      adminRedirect(superUser: false, location: '/credit-history'),
      isNull,
    );
  });
}
