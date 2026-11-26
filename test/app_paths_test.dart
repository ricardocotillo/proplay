import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/app_paths.dart';
import 'package:proplay/utils/auth_redirect.dart';
import 'package:proplay/utils/shell_nav.dart';

void main() {
  test('paths are the router URLs', () {
    expect(eventPath('e1'), '/events/e1');
    expect(ticketPath('e1_u1'), '/tickets/e1_u1');
    expect(createEventPath('g1'), '/group/g1/create-event');
    expect(groupPath('g1'), '/group/g1');
  });

  test('a guest on a ticket or create-event link signs in, then returns', () {
    for (final p in [ticketPath('e1_u1'), createEventPath('g1')]) {
      final to = authRedirect(loggedIn: false, location: p, target: p);
      expect(to, authPath('/login', from: p), reason: p);
      expect(
        authRedirect(loggedIn: true, location: '/login', from: p),
        p,
        reason: p,
      );
    }
  });

  test('the event page is open to guests and every path is a safe ?from=', () {
    expect(
      authRedirect(
        loggedIn: false,
        location: eventPath('e1'),
        target: eventPath('e1'),
      ),
      isNull,
    );
    for (final p in [
      eventPath('e1'),
      ticketPath('e1_u1'),
      createEventPath('g1'),
    ]) {
      expect(safeFrom(p), p);
    }
  });

  test('nav highlights the section of an event or ticket page', () {
    expect(activeSection(eventPath('e1')), 'explore');
    expect(activeSection(ticketPath('e1_u1')), 'tickets');
  });
}
