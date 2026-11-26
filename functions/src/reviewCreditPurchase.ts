import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {reviewError} from './adminPolicy';
import {roundCents} from './joinPolicy';
import {formatCredits} from './refundPolicy';

/**
 * A superUser approves or rejects a pending Yape top-up. Approval credits the
 * buyer and marks the row in one transaction, so a double tap or two admins
 * at once credit it once: the second call sees `status != pending`.
 */
export const reviewCreditPurchase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  const uid = request.auth.uid;
  const entryId = request.data?.entryId;
  const approve = request.data?.approve;
  if (typeof entryId !== 'string' || !entryId || entryId.includes('/') ||
      typeof approve !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Solicitud inválida.');
  }

  const db = getFirestore();
  const entryRef = db.doc(`creditHistory/${entryId}`);

  return db.runTransaction(async (tx) => {
    const caller = await tx.get(db.doc(`users/${uid}`));
    if (caller.get('superUser') !== true) {
      throw new HttpsError('permission-denied', 'No tienes permiso para hacer esto.');
    }
    const entrySnap = await tx.get(entryRef);
    const entry = entrySnap.data();
    const err = reviewError(entry);
    if (err) throw new HttpsError(err.code, err.message);

    const reviewed = {reviewedBy: uid, reviewedAt: FieldValue.serverTimestamp()};
    if (!approve) {
      tx.update(entryRef, {status: 'rejected', ...reviewed});
      return {status: 'rejected'};
    }

    const userRef = db.doc(`users/${entry!.userId}`);
    const user = await tx.get(userRef);
    if (!user.exists) {
      throw new HttpsError('failed-precondition', 'No encontramos al usuario de esta solicitud.');
    }
    const before = parseFloat(user.get('credits') ?? '0') || 0;
    const after = roundCents(before + roundCents(entry!.creditAmount as number));
    tx.update(userRef, {credits: formatCredits(after)});
    tx.update(entryRef, {
      status: 'approved', balanceBefore: before, balanceAfter: after, ...reviewed,
    });
    return {status: 'approved', balanceAfter: after};
  });
});
