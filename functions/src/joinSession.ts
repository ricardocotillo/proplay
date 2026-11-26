import {randomUUID} from 'node:crypto';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {getFirestore, FieldValue, Timestamp} from 'firebase-admin/firestore';
import {formatCredits} from './refundPolicy';
import {joinError, spendDocId} from './joinPolicy';

type Player = {uid?: string};

/**
 * Joins the caller to a live session in one transaction: checks access,
 * start time (server clock), seats and the balance read from `users/{uid}`,
 * then debits the balance, writes the ledger `spend` row, appends the player
 * (built from the user doc, never the payload) and writes the ticket.
 * Retrying after a successful join returns the existing ticket, no charge.
 */
export const joinSession = onCall(async (request) => {
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
  const userRef = db.doc(`users/${uid}`);
  const ticketId = `${sessionId}_${uid}`;
  const ticketRef = db.doc(`tickets/${ticketId}`);

  return db.runTransaction(async (tx) => {
    // ---- reads (all before any write) ----
    const sessionSnap = await tx.get(sessionRef);
    if (!sessionSnap.exists) {
      throw new HttpsError('not-found', 'Evento no encontrado.');
    }
    const session = sessionSnap.data()!;
    const players: Player[] = Array.isArray(session.players) ? session.players : [];
    if (players.some((p) => p?.uid === uid)) {
      return {ticketId, alreadyJoined: true};
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError('failed-precondition', 'No encontramos tu perfil.');
    }
    const user = userSnap.data()!;

    const isPrivate = session.isPrivate === true;
    const isMember = isPrivate && typeof session.groupId === 'string'
      ? (await tx.get(db.doc(`groups/${session.groupId}/members/${uid}`))).exists
      : false;

    const balance = parseFloat(user.credits ?? '0') || 0;
    const cost = Number(session.costPerPlayer) || 0;
    const eventDate: Date | null =
      typeof session.eventDate?.toDate === 'function' ? session.eventDate.toDate() : null;
    const error = joinError({
      eventDateMs: eventDate?.getTime() ?? null,
      nowMs: Date.now(),
      isPrivate,
      isMember,
      playerCount: players.length,
      maxPlayers: Number(session.maxPlayers) || 0,
      balance,
      cost,
    });
    if (error) throw new HttpsError(error.code, error.message);

    // ---- writes ----
    const token = randomUUID();
    const newBalance = balance - cost;
    tx.update(userRef, {credits: formatCredits(newBalance)});

    tx.set(db.doc(`creditHistory/${spendDocId(sessionId, uid, token)}`), {
      userId: uid,
      creditAmount: cost,
      amountPaid: 0.0,
      createdAt: FieldValue.serverTimestamp(),
      status: 'completed',
      entryType: 'spend',
      direction: 'debit',
      sourceType: 'session',
      sourceId: sessionId,
      sessionId,
      sessionTitle: session.title ?? '',
      groupId: session.groupId ?? '',
      balanceBefore: balance,
      balanceAfter: newBalance,
      notes: `Unirse a pichanga: ${session.title ?? ''}`,
    });

    const updatedPlayers = [
      ...players,
      {
        uid,
        firstName: user.firstName ?? '',
        lastName: user.lastName ?? '',
        profileImageUrl: user.profileImageUrl ?? null,
        // serverTimestamp() is not allowed inside arrays.
        joinedAt: Timestamp.now(),
        receiptUrl: null,
        isConfirmed: false,
      },
    ];
    tx.update(sessionRef, {players: updatedPlayers, playerCount: updatedPlayers.length});

    tx.set(ticketRef, {
      sessionId,
      groupId: session.groupId ?? '',
      userId: uid,
      validationToken: token,
      status: 'valid',
      createdAt: FieldValue.serverTimestamp(),
      usedAt: null,
      validatedBy: null,
      pricePaid: cost,
      eventTitle: session.title ?? '',
      eventDate: session.eventDate,
      eventEndDate: session.eventEndDate ?? session.eventDate,
      eventLocationAddress: session.locationAddress ?? null,
      eventLocationLat: session.locationLat ?? null,
      eventLocationLng: session.locationLng ?? null,
      sport: session.sport ?? '',
      userFirstName: user.firstName ?? '',
      userLastName: user.lastName ?? '',
      userProfileImageUrl: user.profileImageUrl ?? null,
      userDocumentType: user.documentType ?? '',
      userDocumentNumber: user.documentNumber ?? '',
    });

    return {ticketId, alreadyJoined: false};
  });
});
