import {onCall, HttpsError, CallableRequest} from 'firebase-functions/v2/https';
import {
  getFirestore, FieldValue, Firestore, Transaction, DocumentData, DocumentReference,
} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {canManageEvent} from './adminPolicy';
import {
  applyLateRefund, applyOffer, notifyLateRefund, notifyOffer, planLateRefund, planOffer,
  readLateCancels, readWaitlist,
} from './waitlist';
import {roundCents} from './joinPolicy';
import {
  formatCredits, isPaidRefund, pickUnrefundedSpend, refundAmount, refundDocId, SpendRow,
} from './refundPolicy';

type Player = {uid?: string};
type Refund = {uid: string; amount: number; balance: number; spendId: string};

const id = (v: unknown): v is string => typeof v === 'string' && v.length > 0 && !v.includes('/');

const callerOf = (request: CallableRequest): string => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  return request.auth.uid;
};

/** Reads the session and checks the caller may manage it. */
async function loadSession(tx: Transaction, db: Firestore, sessionId: string, uid: string) {
  const sessionRef = db.doc(`liveSessions/${sessionId}`);
  const snap = await tx.get(sessionRef);
  if (!snap.exists) throw new HttpsError('not-found', 'Evento no encontrado.');
  const session = snap.data()!;
  const groupId = session.groupId;
  const [caller, member] = await Promise.all([
    tx.get(db.doc(`users/${uid}`)),
    id(groupId) ? tx.get(db.doc(`groups/${groupId}/members/${uid}`)) : Promise.resolve(null),
  ]);
  if (!canManageEvent({
    uid, creatorId: session.creatorId, memberRole: member?.get('role'),
    superUser: caller.get('superUser') === true,
  })) {
    throw new HttpsError('permission-denied', 'No tienes permiso para gestionar este evento.');
  }
  const players: Player[] = Array.isArray(session.players) ? session.players : [];
  return {sessionRef, session, players};
}

/** Same, and the event must not have started (cancel, remove). */
async function loadManaged(tx: Transaction, db: Firestore, sessionId: string, uid: string) {
  const loaded = await loadSession(tx, db, sessionId, uid);
  const start = loaded.session.eventDate?.toDate?.();
  if (!(start instanceof Date) || start.getTime() <= Date.now()) {
    throw new HttpsError('failed-precondition', 'Este evento ya empezó o terminó.');
  }
  return loaded;
}

/**
 * What each player is owed: their latest unrefunded `spend` row, capped at the
 * price, once (same rule as cancelParticipation, without the 24 h window: the
 * organizer cancelled, not the player). Reads only.
 */
async function planRefunds(
  tx: Transaction, db: Firestore, sessionId: string, session: DocumentData, uids: string[],
): Promise<Refund[]> {
  if (uids.length === 0) return [];
  const spends = await tx.get(
    db.collection('creditHistory')
      .where('sourceId', '==', sessionId)
      .where('entryType', '==', 'spend'),
  );
  const picked: {uid: string; spend: SpendRow}[] = [];
  for (const uid of uids) {
    const rows: SpendRow[] = spends.docs
      .filter((d) => d.get('userId') === uid)
      .map((d) => ({
        id: d.id,
        creditAmount: Number(d.get('creditAmount')) || 0,
        createdAtMs: d.get('createdAt')?.toMillis?.() ?? 0,
        refunded: d.get('refundedAt') != null,
      }));
    const spend = pickUnrefundedSpend(rows);
    if (spend && refundAmount(spend.creditAmount, session.costPerPlayer) > 0) {
      picked.push({uid, spend});
    }
  }
  if (picked.length === 0) return [];
  const refundSnaps = await tx.getAll(
    ...picked.map((p) => db.doc(`creditHistory/${refundDocId(p.spend.id)}`)),
  );
  const owed = picked.filter((p, i) => !isPaidRefund(refundSnaps[i].data(), p.uid));
  if (owed.length === 0) return [];
  const users = await tx.getAll(...owed.map((p) => db.doc(`users/${p.uid}`)));
  return owed.flatMap((p, i) => users[i].exists ? [{
    uid: p.uid,
    spendId: p.spend.id,
    amount: roundCents(refundAmount(p.spend.creditAmount, session.costPerPlayer)),
    balance: parseFloat(users[i].get('credits') ?? '0') || 0,
  }] : []);
}

function applyRefunds(
  tx: Transaction, db: Firestore, sessionId: string, session: DocumentData,
  refunds: Refund[], notes: string,
) {
  for (const r of refunds) {
    const after = roundCents(r.balance + r.amount);
    tx.update(db.doc(`users/${r.uid}`), {credits: formatCredits(after)});
    tx.update(db.doc(`creditHistory/${r.spendId}`), {refundedAt: FieldValue.serverTimestamp()});
    tx.set(db.doc(`creditHistory/${refundDocId(r.spendId)}`), {
      userId: r.uid,
      creditAmount: r.amount,
      amountPaid: 0.0,
      createdAt: FieldValue.serverTimestamp(),
      status: 'completed',
      entryType: 'refund',
      direction: 'credit',
      sourceType: 'session',
      sourceId: sessionId,
      sessionId,
      sessionTitle: session.title ?? '',
      groupId: session.groupId ?? '',
      balanceBefore: r.balance,
      balanceAfter: after,
      notes,
    });
  }
}

/**
 * Organizer cancels an event before it starts: every player gets their price
 * back, tickets are deleted, the event is deleted (the mirror trigger drops
 * the public copy).
 */
export const cancelEvent = onCall(async (request) => {
  const uid = callerOf(request);
  const sessionId = request.data?.sessionId;
  if (!id(sessionId)) throw new HttpsError('invalid-argument', 'Solicitud inválida.');
  const db = getFirestore();

  const out = await db.runTransaction(async (tx) => {
    const {sessionRef, session, players} = await loadManaged(tx, db, sessionId, uid);
    const tickets = await tx.get(db.collection('tickets').where('sessionId', '==', sessionId));
    const uids = [...new Set(players.map((p) => p?.uid).filter(id))];
    // ponytail: one transaction, fine for pickup sizes (4 writes per player);
    // batch per player if events grow past ~100 players.
    const refunds = await planRefunds(tx, db, sessionId, session, uids);
    // The waitlist ends with the event, and people who cancelled late (no
    // refund, waiting for a waitlist fill) are paid back now.
    const waitlist = await readWaitlist(tx, db, sessionId);
    const lateAll = await readLateCancels(tx, db, sessionId);
    const lateRows = lateAll.filter((r) => !r.refunded);
    const late = await Promise.all(lateRows.map((r) => planLateRefund(tx, db, sessionId, r, session)));
    // Same user refunded twice (late cancel, then rejoined): build on the first balance.
    for (const l of late) {
      const r = refunds.find((x) => x.uid === l.uid);
      if (r && l.amount > 0) l.balance = roundCents(r.balance + r.amount);
    }

    applyRefunds(tx, db, sessionId, session, refunds,
      `Reembolso: evento cancelado (${session.title ?? ''})`);
    late.forEach((l) => applyLateRefund(tx, l));
    tickets.docs.forEach((d) => tx.delete(d.ref));
    waitlist.forEach((w) => tx.delete(w.ref));
    lateAll.forEach((r) => tx.delete(db.doc(`liveSessions/${sessionId}/lateCancels/${r.spendId}`)));
    tx.delete(sessionRef);
    return {
      refunded: refunds.length,
      total: roundCents(refunds.reduce((s, r) => s + r.amount, 0)),
      late,
    };
  });
  await Promise.all(out.late.map((l) => notifyLateRefund(db, getMessaging(), l)));
  return {refunded: out.refunded, total: out.total};
});

/**
 * Organizer removes a player before the event starts: seat freed, ticket
 * deleted, price refunded in full. A used ticket can't be removed.
 */
export const removePlayer = onCall(async (request) => {
  const uid = callerOf(request);
  const sessionId = request.data?.sessionId;
  const userId = request.data?.userId;
  if (!id(sessionId) || !id(userId)) {
    throw new HttpsError('invalid-argument', 'Solicitud inválida.');
  }
  // Leaving yourself goes through cancelParticipation (24 h refund window).
  if (userId === uid) {
    throw new HttpsError('failed-precondition', 'Usa «Cancelar inscripción» para salir del evento.');
  }
  const db = getFirestore();
  const ticketRef: DocumentReference = db.doc(`tickets/${sessionId}_${userId}`);

  const out = await db.runTransaction(async (tx) => {
    const {sessionRef, session, players} = await loadManaged(tx, db, sessionId, uid);
    if (!players.some((p) => p?.uid === userId)) {
      throw new HttpsError('failed-precondition', 'Este jugador ya no está en el evento.');
    }
    const ticket = await tx.get(ticketRef);
    if (ticket.exists && ticket.get('status') !== 'valid') {
      throw new HttpsError('failed-precondition', 'El ticket de este jugador ya fue usado.');
    }
    const refunds = await planRefunds(tx, db, sessionId, session, [userId]);
    const remaining = players.filter((p) => p?.uid !== userId);
    const waitlist = await readWaitlist(tx, db, sessionId);
    const nowMs = Date.now();
    const offer = await planOffer(tx, db, waitlist, {
      maxPlayers: Number(session.maxPlayers) || 0,
      playersAfter: remaining.length,
      eventMs: session.eventDate.toMillis(),
      nowMs,
      cost: Number(session.costPerPlayer) || 0,
    });

    applyRefunds(tx, db, sessionId, session, refunds,
      `Reembolso: el organizador te retiró de ${session.title ?? ''}`);
    tx.update(sessionRef, {players: remaining, playerCount: remaining.length});
    applyOffer(tx, offer, nowMs);
    if (ticket.exists) tx.delete(ticketRef);
    return {
      refunded: refunds.length > 0, amount: refunds[0]?.amount ?? 0,
      offer, title: String(session.title ?? ''),
    };
  });
  await notifyOffer(db, getMessaging(), out.offer, sessionId, out.title, Date.now());
  return {refunded: out.refunded, amount: out.amount};
});

/**
 * Organizer marks a player present (ticket `used`) or absent (back to `valid`)
 * from the roster. Idempotent. Works any time: check-in happens while the
 * event is on. A ticket validated by QR shows as present too.
 */
export const checkInPlayer = onCall(async (request) => {
  const uid = callerOf(request);
  const sessionId = request.data?.sessionId;
  const userId = request.data?.userId;
  const present = request.data?.present;
  if (!id(sessionId) || !id(userId) || typeof present !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Solicitud inválida.');
  }
  const db = getFirestore();
  const ticketRef = db.doc(`tickets/${sessionId}_${userId}`);

  return db.runTransaction(async (tx) => {
    const {players} = await loadSession(tx, db, sessionId, uid);
    if (!players.some((p) => p?.uid === userId)) {
      throw new HttpsError('failed-precondition', 'Este jugador ya no está en el evento.');
    }
    const ticket = await tx.get(ticketRef);
    if (!ticket.exists) {
      throw new HttpsError('failed-precondition', 'Este jugador no tiene ticket.');
    }
    const used = ticket.get('status') === 'used';
    if (present && !used) {
      tx.update(ticketRef, {
        status: 'used', usedAt: FieldValue.serverTimestamp(), validatedBy: uid,
      });
    } else if (!present && used) {
      tx.update(ticketRef, {status: 'valid', usedAt: null, validatedBy: null});
    }
    return {present};
  });
});
