import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {getFirestore, FieldValue, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {joinError} from './joinPolicy';
import {Sender} from './notify';
import {applyOffer, holdsOf, notifyOffer, OfferPlan, planOffer, readWaitlist} from './waitlist';
import {isActiveOffer} from './waitlistPolicy';

type Player = {uid?: string};

const sid = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && !v.includes('/');

const numberOr = (v: unknown) => (typeof v === 'number' ? v : NaN);

/**
 * Join the waitlist of a full event. Free: nothing is charged until a seat is
 * offered and the person confirms (joinSession). The balance is checked now
 * only so offers don't go to people who could not pay.
 */
export const joinWaitlist = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión');
  const uid = request.auth.uid;
  const sessionId = request.data?.sessionId;
  if (!sid(sessionId)) throw new HttpsError('invalid-argument', 'sessionId requerido');
  const db = getFirestore();

  return db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(db.doc(`liveSessions/${sessionId}`));
    if (!sessionSnap.exists) throw new HttpsError('not-found', 'Evento no encontrado.');
    const session = sessionSnap.data()!;
    const players: Player[] = Array.isArray(session.players) ? session.players : [];
    if (players.some((p) => p?.uid === uid)) {
      throw new HttpsError('failed-precondition', 'Ya estás inscrito en este evento.');
    }
    const nowMs = Date.now();
    const wl = await readWaitlist(tx, db, sessionId);
    if (wl.some((e) => e.uid === uid)) return {status: 'already'};

    const userSnap = await tx.get(db.doc(`users/${uid}`));
    if (!userSnap.exists) throw new HttpsError('failed-precondition', 'No encontramos tu perfil.');
    const user = userSnap.data()!;
    const isPrivate = session.isPrivate !== false;
    const isMember = isPrivate && typeof session.groupId === 'string'
      ? (await tx.get(db.doc(`groups/${session.groupId}/members/${uid}`))).exists
      : false;
    const eventDate: Date | null =
      typeof session.eventDate?.toDate === 'function' ? session.eventDate.toDate() : null;
    const maxPlayers = numberOr(session.maxPlayers);

    // Everything but the seat count: private, started, price, balance.
    const error = joinError({
      eventDateMs: eventDate?.getTime() ?? null, nowMs, isPrivate, isMember,
      playerCount: 0, maxPlayers, balance: parseFloat(user.credits ?? '0') || 0,
      cost: numberOr(session.costPerPlayer),
    });
    if (error) throw new HttpsError(error.code, error.message);
    if (players.length + holdsOf(wl, nowMs) < maxPlayers) {
      throw new HttpsError('failed-precondition', 'Aún hay cupos: únete directamente.');
    }

    tx.set(db.doc(`liveSessions/${sessionId}/waitlist/${uid}`), {
      status: 'waiting',
      joinedAt: FieldValue.serverTimestamp(),
      firstName: user.firstName ?? '',
      lastName: user.lastName ?? '',
      profileImageUrl: user.profileImageUrl ?? null,
    });
    return {status: 'waiting'};
  });
});

/** Leave the waitlist (or decline an offer: the seat goes to the next in line). */
export const leaveWaitlist = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión');
  const uid = request.auth.uid;
  const sessionId = request.data?.sessionId;
  if (!sid(sessionId)) throw new HttpsError('invalid-argument', 'sessionId requerido');
  const db = getFirestore();

  const out = await db.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(db.doc(`liveSessions/${sessionId}`));
    const wl = await readWaitlist(tx, db, sessionId);
    const mine = wl.find((e) => e.uid === uid);
    if (!mine) return {offer: null as OfferPlan, title: ''};
    const nowMs = Date.now();
    const session = sessionSnap.data();
    const rest = wl.filter((e) => e.uid !== uid);
    // A declined offer frees its seat for the next person.
    const offer = session && isActiveOffer(mine, nowMs)
      ? planOffer(rest, {
        maxPlayers: Number(session.maxPlayers) || 0,
        playersAfter: Array.isArray(session.players) ? session.players.length : 0,
        eventMs: session.eventDate?.toMillis?.() ?? 0,
        nowMs,
      })
      : null;
    tx.delete(mine.ref);
    applyOffer(tx, offer, nowMs);
    return {offer, title: String(session?.title ?? '')};
  });
  await notifyOffer(db, getMessaging(), out.offer, sessionId, out.title, Date.now());
  return {left: true};
});

/**
 * Offers whose hold ran out: drop the entry and offer the seat to the next
 * person. Run by the scheduler; safe to run twice.
 */
export async function expireOffers(
  db: Firestore, sender: Sender, nowMs: number,
): Promise<{expired: number; offered: number}> {
  const due = await db.collectionGroup('waitlist')
    .where('offerExpiresAt', '<=', Timestamp.fromMillis(nowMs)).get();
  const sessions = [...new Set(due.docs.map((d) => d.ref.parent.parent!.id))];
  let expired = 0;
  let offered = 0;
  for (const sessionId of sessions) {
    try {
      const out = await db.runTransaction(async (tx) => {
        const sessionSnap = await tx.get(db.doc(`liveSessions/${sessionId}`));
        const wl = await readWaitlist(tx, db, sessionId);
        const gone = wl.filter((e) => e.status === 'offered' && !isActiveOffer(e, nowMs));
        const rest = wl.filter((e) => !gone.includes(e));
        const session = sessionSnap.data();
        const eventMs: number = session?.eventDate?.toMillis?.() ?? 0;
        const offer = session && eventMs > nowMs
          ? planOffer(rest, {
            maxPlayers: Number(session.maxPlayers) || 0,
            playersAfter: Array.isArray(session.players) ? session.players.length : 0,
            eventMs, nowMs,
          })
          : null;
        gone.forEach((e) => tx.delete(e.ref));
        applyOffer(tx, offer, nowMs);
        return {n: gone.length, offer, title: String(session?.title ?? '')};
      });
      expired += out.n;
      if (out.offer) offered++;
      await notifyOffer(db, sender, out.offer, sessionId, out.title, nowMs);
    } catch (e) {
      console.error('expire offers failed', sessionId, e);
    }
  }
  return {expired, offered};
}

export const expireWaitlistOffers = onSchedule('every 10 minutes', async () => {
  await expireOffers(getFirestore(), getMessaging(), Date.now());
});

