/** How long a freed seat is held for the person it is offered to. */
export const HOLD_MS = 30 * 60_000;

export type Entry = {uid: string; status: string; joinedAtMs: number; offerExpiresAtMs?: number};

/** An offer holds a seat only until it expires. */
export const isActiveOffer = (e: Entry, nowMs: number): boolean =>
  e.status === 'offered' && (e.offerExpiresAtMs ?? 0) > nowMs;

/** Held for 30 min, but never past the start of the event. */
export const offerExpiryMs = (nowMs: number, eventMs: number): number =>
  Math.min(nowMs + HOLD_MS, eventMs);

/** Seats nobody holds: capacity minus players minus live offers. */
export const freeSeats = (maxPlayers: number, players: number, holds: number): number =>
  Math.max(0, maxPlayers - players - holds);

/** First in line: the oldest `waiting` entry (ties by uid, so it is stable). */
export const pickNext = (entries: Entry[]): Entry | undefined =>
  entries
    .filter((e) => e.status === 'waiting')
    .sort((a, b) => a.joinedAtMs - b.joinedAtMs || (a.uid < b.uid ? -1 : 1))[0];

export type LateCancel = {uid: string; spendId: string; createdAtMs: number; refunded: boolean};

/**
 * Which late cancel a waitlist fill pays back: the oldest unrefunded one,
 * never the person who is filling the seat.
 */
export const pickLateCancel = (rows: LateCancel[], exceptUid: string): LateCancel | undefined =>
  rows
    .filter((r) => !r.refunded && r.uid !== exceptUid)
    .sort((a, b) => a.createdAtMs - b.createdAtMs || (a.uid < b.uid ? -1 : 1))[0];

/** Whole minutes left on a hold, at least 1 while it is active. */
export const minutesLeft = (expiresMs: number, nowMs: number): number =>
  Math.max(1, Math.ceil((expiresMs - nowMs) / 60_000));
