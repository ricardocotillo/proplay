/// Why an event cannot be joined right now. Display only: the join
/// transaction (`SessionService.joinSession`) re-checks all of it.
enum JoinBlock { none, past, blocked, full, credits }

/// First reason that blocks a join, in the order the user can act on:
/// a past event is final, a pause lifts on its date, a full event may free
/// up, missing credits can be topped up.
/// [balance] is null for guests (credits are not checked).
JoinBlock joinBlock({
  required DateTime eventDate,
  required int playerCount,
  required int maxPlayers,
  required double cost,
  required DateTime now,
  double? balance,

  /// Joining is paused until then (3 no-shows in 90 days).
  DateTime? blockedUntil,
}) {
  if (!eventDate.isAfter(now)) return JoinBlock.past;
  if (blockedUntil != null && blockedUntil.isAfter(now))
    return JoinBlock.blocked;
  // Same rule as the join transaction: no seats (0) means full.
  if (playerCount >= maxPlayers) return JoinBlock.full;
  if (balance != null && balance < cost) return JoinBlock.credits;
  return JoinBlock.none;
}
