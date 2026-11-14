import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {
  formatCredits,
  isRefundable,
  pickUnrefundedSpend,
  refundAmount,
  refundDocId,
  SpendRow,
} from './refundPolicy';

type Player = {uid?: string};

/**
 * Cancels the caller's spot in a live session. Frees the seat, deletes the
 * ticket and, when the event starts 24 h or more from now (server time),
 * refunds the matching ledger `spend` row (capped at the event price) once:
 * the spend is marked `refundedAt` and the refund id derives from the spend id.
 * Not allowed once the event has started.
 */
export const cancelParticipation = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión');
  }
  const uid = request.auth.uid;
  const sessionId = request.data?.sessionId;
  if (typeof sessionId !== 'string' || sessionId.length === 0) {
    throw new HttpsError('invalid-argument', 'sessionId requerido');
  }

  const db = getFirestore();
  const sessionRef = db.doc(`liveSessions/${sessionId}`);
  const ticketRef = db.doc(`tickets/${sessionId}_${uid}`);
  const userRef = db.doc(`users/${uid}`);

  return db.runTransaction(async (tx) => {
    // ---- reads (all before any write) ----
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'Evento no encontrado');
    }
    const session = sessionSnap.data()!;
    const players: Player[] = Array.isArray(session.players) ? session.players : [];
    if (!players.some((p) => p?.uid === uid)) {
      throw new HttpsError('failed-precondition', 'No participas en este evento');
    }

    const ticketSnap = await tx.get(ticketRef);
    const ticket = ticketSnap.exists ? ticketSnap.data()! : null;
    if (ticket && ticket.status !== 'valid') {
      throw new HttpsError('failed-precondition', 'El ticket ya fue usado');
    }

    if (typeof session.eventDate?.toDate !== 'function') {
      throw new HttpsError('failed-precondition', 'El evento no tiene fecha válida');
    }
    const eventDate: Date = session.eventDate.toDate();
    const now = new Date();
    if (eventDate.getTime() <= now.getTime()) {
      throw new HttpsError('failed-precondition', 'El evento ya comenzó');
    }
    const refundable = isRefundable(eventDate, now);

    let amount = 0;
    let userCredits = 0;
    let spendRef: FirebaseFirestore.DocumentReference | null = null;
    let refundRef: FirebaseFirestore.DocumentReference | null = null;
    if (refundable) {
      // The ticket's pricePaid and token are client-written, so the refund is
      // keyed to the ledger `spend` row instead and each row refunds once.
      const spends = await tx.get(
        db
          .collection('creditHistory')
          .where('userId', '==', uid)
          .where('sourceId', '==', sessionId)
          .where('entryType', '==', 'spend'),
      );
      const rows: SpendRow[] = spends.docs.map((d) => ({
        id: d.id,
        creditAmount: Number(d.get('creditAmount')) || 0,
        createdAtMs: d.get('createdAt')?.toMillis?.() ?? 0,
        refunded: d.get('refundedAt') != null,
      }));
      const spend = pickUnrefundedSpend(rows);
      if (spend) {
        const ref = db.doc(`creditHistory/${refundDocId(spend.id)}`);
        if (!(await tx.get(ref)).exists) {
          amount = refundAmount(spend.creditAmount, session.costPerPlayer);
          spendRef = db.doc(`creditHistory/${spend.id}`);
          refundRef = ref;
        }
      }
      if (amount > 0) {
        const userSnap = await tx.get(userRef);
        userCredits = parseFloat(userSnap.data()?.credits ?? '0') || 0;
      }
    }

    // ---- writes ----
    const remaining = players.filter((p) => p?.uid !== uid);
    tx.update(sessionRef, {players: remaining, playerCount: remaining.length});

    // Deleted (not marked cancelled): a holder cannot revive a cancelled ticket.
    if (ticket) tx.delete(ticketRef);
    if (refundRef && spendRef && amount > 0) {
      const newCredits = userCredits + amount;
      tx.update(userRef, {credits: formatCredits(newCredits)});
      tx.update(spendRef, {refundedAt: FieldValue.serverTimestamp()});
      tx.set(refundRef, {
        userId: uid,
        creditAmount: amount,
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
        balanceBefore: userCredits,
        balanceAfter: newCredits,
        notes: `Reembolso por cancelación: ${session.title ?? ''}`,
      });
    }

    return {refunded: amount > 0, amount};
  });
});
