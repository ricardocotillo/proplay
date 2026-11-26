import {onCall, HttpsError, CallableRequest} from 'firebase-functions/v2/https';
import {
  getFirestore, FieldValue, Firestore, Transaction, DocumentData, DocumentReference,
} from 'firebase-admin/firestore';
import {canManageEvent} from './adminPolicy';
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

/** Reads the session and checks the caller may manage it and it hasn't started. */
async function loadManaged(tx: Transaction, db: Firestore, sessionId: string, uid: string) {
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
  const start = session.eventDate?.toDate?.();
  if (!(start instanceof Date) || start.getTime() <= Date.now()) {
    throw new HttpsError('failed-precondition', 'Este evento ya empezó o terminó.');
  }
  const players: Player[] = Array.isArray(session.players) ? session.players : [];
  return {sessionRef, session, players};
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

  return db.runTransaction(async (tx) => {
    const {sessionRef, session, players} = await loadManaged(tx, db, sessionId, uid);
    const tickets = await tx.get(db.collection('tickets').where('sessionId', '==', sessionId));
    const uids = [...new Set(players.map((p) => p?.uid).filter(id))];
    // ponytail: one transaction, fine for pickup sizes (4 writes per player);
    // batch per player if events grow past ~100 players.
    const refunds = await planRefunds(tx, db, sessionId, session, uids);

    applyRefunds(tx, db, sessionId, session, refunds,
      `Reembolso: evento cancelado (${session.title ?? ''})`);
    tickets.docs.forEach((d) => tx.delete(d.ref));
    tx.delete(sessionRef);
    return {
      refunded: refunds.length,
      total: roundCents(refunds.reduce((s, r) => s + r.amount, 0)),
    };
  });
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

  return db.runTransaction(async (tx) => {
    const {sessionRef, session, players} = await loadManaged(tx, db, sessionId, uid);
    if (!players.some((p) => p?.uid === userId)) {
      throw new HttpsError('failed-precondition', 'Este jugador ya no está en el evento.');
    }
    const ticket = await tx.get(ticketRef);
    if (ticket.exists && ticket.get('status') !== 'valid') {
      throw new HttpsError('failed-precondition', 'El ticket de este jugador ya fue usado.');
    }
    const refunds = await planRefunds(tx, db, sessionId, session, [userId]);

    applyRefunds(tx, db, sessionId, session, refunds,
      `Reembolso: el organizador te retiró de ${session.title ?? ''}`);
    const remaining = players.filter((p) => p?.uid !== userId);
    tx.update(sessionRef, {players: remaining, playerCount: remaining.length});
    if (ticket.exists) tx.delete(ticketRef);
    return {refunded: refunds.length > 0, amount: refunds[0]?.amount ?? 0};
  });
});
