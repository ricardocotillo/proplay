import 'package:proplay/models/waitlist_entry_model.dart';

/// What the event page's bottom bar shows for someone on the waitlist.
enum WaitlistBar { none, waiting, offered }

/// A held seat always shows its confirm bar. A waiting user sees the waitlist
/// bar only while the event is full: with a free seat they can simply join
/// (the join also removes them from the list).
WaitlistBar waitlistBar(
  WaitlistEntryModel? entry, {
  required int playerCount,
  required int maxPlayers,
}) {
  if (entry == null) return WaitlistBar.none;
  if (entry.isOffered) return WaitlistBar.offered;
  return playerCount >= maxPlayers ? WaitlistBar.waiting : WaitlistBar.none;
}
