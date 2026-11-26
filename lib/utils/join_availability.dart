/// Why an event cannot be joined right now. Display only: the join
/// transaction (`SessionService.joinSession`) re-checks all of it.
enum JoinBlock { none, past, full, credits }

/// First reason that blocks a join, in the order the user can act on:
/// a past or full event is final, missing credits can be topped up.
/// [balance] is null for guests (credits are not checked).
JoinBlock joinBlock({
  required DateTime eventDate,
  required int playerCount,
  required int maxPlayers,
  required double cost,
  required DateTime now,
  double? balance,
}) {
  if (!eventDate.isAfter(now)) return JoinBlock.past;
  // Same rule as the join transaction: no seats (0) means full.
  if (playerCount >= maxPlayers) return JoinBlock.full;
  if (balance != null && balance < cost) return JoinBlock.credits;
  return JoinBlock.none;
}
