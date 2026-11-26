import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/models/waitlist_entry_model.dart';
import 'package:proplay/utils/waitlist_bar.dart';

void main() {
  const waiting = WaitlistEntryModel(status: 'waiting');
  const offered = WaitlistEntryModel(status: 'offered');

  test('no entry: the normal join bar', () {
    expect(
      waitlistBar(null, playerCount: 10, maxPlayers: 10),
      WaitlistBar.none,
    );
  });

  test('a held seat always shows the confirm bar, even with seats free', () {
    expect(
      waitlistBar(offered, playerCount: 9, maxPlayers: 10),
      WaitlistBar.offered,
    );
    expect(
      waitlistBar(offered, playerCount: 10, maxPlayers: 10),
      WaitlistBar.offered,
    );
  });

  test('waiting on a full event shows the waitlist bar', () {
    expect(
      waitlistBar(waiting, playerCount: 10, maxPlayers: 10),
      WaitlistBar.waiting,
    );
  });

  test('waiting with a free seat can simply join', () {
    expect(
      waitlistBar(waiting, playerCount: 9, maxPlayers: 10),
      WaitlistBar.none,
    );
  });
}
