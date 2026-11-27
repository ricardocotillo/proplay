import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {getFirestore, FieldValue} from 'firebase-admin/firestore';
import {hasIdentityDocument} from './joinPolicy';
import {
  cooldownMessage, DOCUMENT_TAKEN_MESSAGE, documentKey, isValidDocument, nextChangeMs,
  normalizeDocument,
} from './documentPolicy';

/**
 * Corrects the caller's identity document, at most once every 30 days since
 * the last change. One transaction: checks the cooldown, claims the new lock
 * in `documents/`, releases the old one and updates the profile. Tickets
 * already issued keep their document snapshot.
 */
export const changeDocument = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  const uid = request.auth.uid;
  const type = request.data?.documentType;
  const number = typeof request.data?.documentNumber === 'string'
    ? normalizeDocument(request.data.documentNumber) : null;
  if (!isValidDocument(type, number)) {
    throw new HttpsError('invalid-argument', 'El documento no tiene un formato válido.');
  }

  const db = getFirestore();
  const userRef = db.doc(`users/${uid}`);
  const newKey = documentKey(type, number!);
  const newLockRef = db.doc(`documents/${newKey}`);

  return db.runTransaction(async (tx) => {
    // ---- reads (all before any write) ----
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError('failed-precondition', 'No encontramos tu perfil.');
    const user = userSnap.data()!;
    if (!hasIdentityDocument(user)) {
      throw new HttpsError('failed-precondition', 'Primero registra tu documento al unirte a un evento.');
    }
    const oldKey = documentKey(user.documentType, user.documentNumber);
    if (oldKey === newKey) throw new HttpsError('failed-precondition', 'Ese ya es tu documento.');

    const until = nextChangeMs(user.documentChangedAt?.toMillis?.(), Date.now());
    if (until !== null) throw new HttpsError('failed-precondition', cooldownMessage(until));

    const oldLockRef = db.doc(`documents/${oldKey}`);
    const [newLock, oldLock] = await Promise.all([tx.get(newLockRef), tx.get(oldLockRef)]);
    if (newLock.exists) throw new HttpsError('failed-precondition', DOCUMENT_TAKEN_MESSAGE);

    // ---- writes ----
    // Release the old lock only if it is this user's (a missing or foreign lock is left alone).
    if (oldLock.exists && oldLock.get('uid') === uid) tx.delete(oldLockRef);
    tx.set(newLockRef, {uid, createdAt: FieldValue.serverTimestamp()});
    tx.update(userRef, {
      documentType: type, documentNumber: number, documentChangedAt: FieldValue.serverTimestamp(),
    });
    return {documentType: type, documentNumber: number};
  });
});
