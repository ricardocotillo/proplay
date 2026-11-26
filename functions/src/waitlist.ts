import {
  DocumentReference, FieldValue, Firestore, Timestamp, Transaction,
} from 'firebase-admin/firestore';
import {claim, Sender, sendToUser} from './notify';
import {claimId, lateCancelRefundPush, waitlistOfferPush} from './reminderPolicy';
import {formatCredits, isPaidRefund, refundAmount, refundDocId} from './refundPolicy';
import {roundCents} from './joinPolicy';
import {
  Entry, freeSeats, isActiveOffer, LateCancel, minutesLeft, offerExpiryMs, pickLateCancel, pickNext,
} from './waitlistPolicy';

/** `liveSessions/{id}/waitlist/{uid}`: server-written; the user reads only their own. */
export type WaitlistEntry = Entry & {ref: DocumentReference};

/** Reads the whole waitlist of an event (small) inside the transaction. */
export async function readWaitlist(tx: Transaction, db: Firestore, sessionId: string): Promise<WaitlistEntry[]> {
  const snap = await tx.get(db.collection(`liveSessions/${sessionId}/waitlist`));
  return snap.docs.map((d) => ({
    ref: d.ref,
    uid: d.id,
    status: String(d.get('status')),
    joinedAtMs: d.get('joinedAt')?.toMillis?.() ?? 0,
    offerExpiresAtMs: d.get('offerExpiresAt')?.toMillis?.(),
  }));
}

/** Seats held by live offers; `exceptUid`'s own hold doesn't count against them. */
export const holdsOf = (wl: WaitlistEntry[], nowMs: number, exceptUid?: string): number =>
  wl.filter((e) => e.uid !== exceptUid && isActiveOffer(e, nowMs)).length;

export type OfferPlan = {ref: DocumentReference; uid: string; expiresMs: number} | null;

/**
 * After a seat freed (cancel, removal, expired or declined offer): who gets
 * it. Pure on the already-read waitlist; the caller applies it with
 * [applyOffer] after all of its reads.
 */
export function planOffer(
  wl: WaitlistEntry[],
  c: {maxPlayers: number; playersAfter: number; eventMs: number; nowMs: number},
): OfferPlan {
  if (freeSeats(c.maxPlayers, c.playersAfter, holdsOf(wl, c.nowMs)) <= 0) return null;
  const next = pickNext(wl);
  if (!next) return null;
  const ref = wl.find((e) => e.uid === next.uid)!.ref;
  return {ref, uid: next.uid, expiresMs: offerExpiryMs(c.nowMs, c.eventMs)};
}

export function applyOffer(tx: Transaction, plan: OfferPlan, nowMs: number): void {
  if (!plan) return;
  tx.update(plan.ref, {
    status: 'offered',
    offeredAt: Timestamp.fromMillis(nowMs),
    offerExpiresAt: Timestamp.fromMillis(plan.expiresMs),
  });
}

/** Tell the person offered the seat. Never throws: the seat is already held. */
export async function notifyOffer(
  db: Firestore, sender: Sender, plan: OfferPlan, sessionId: string, title: string, nowMs: number,
): Promise<void> {
  if (!plan) return;
  try {
    if (!(await claim(db, claimId('waitlist_offer', `${sessionId}_${plan.uid}_${plan.expiresMs}`)))) return;
    await sendToUser(db, sender, plan.uid, waitlistOfferPush(title, sessionId, minutesLeft(plan.expiresMs, nowMs)));
  } catch (e) {
    console.error('waitlist offer push failed', sessionId, plan.uid, e);
  }
}

/** A player who cancels inside the no-refund window: remember their spend. */
export function recordLateCancel(
  tx: Transaction, db: Firestore, sessionId: string, uid: string, spendId: string,
): void {
  tx.set(db.doc(`liveSessions/${sessionId}/lateCancels/${uid}`), {
    spendId, createdAt: FieldValue.serverTimestamp(), refunded: false,
  });
}

export type LateRefundPlan = {
  uid: string; spendRef: DocumentReference; lateRef: DocumentReference;
  refundRef: DocumentReference; userRef: DocumentReference;
  amount: number; balance: number; sessionId: string; title: string; groupId: string;
} | null;

/** Late cancellers of an event that were not paid back yet. Reads only. */
export async function readLateCancels(tx: Transaction, db: Firestore, sessionId: string): Promise<LateCancel[]> {
  const snap = await tx.get(db.collection(`liveSessions/${sessionId}/lateCancels`));
  return snap.docs.map((d) => ({
    uid: d.id,
    spendId: String(d.get('spendId')),
    createdAtMs: d.get('createdAt')?.toMillis?.() ?? 0,
    refunded: d.get('refunded') === true,
  }));
}

type SessionLite = {title?: string; groupId?: string; costPerPlayer?: unknown};

/**
 * What a late canceller is owed: their spend, capped at the event price,
 * once. A row with nothing to pay (spend gone, already refunded, no user)
 * still gets a plan with amount 0 so the row is closed. Reads only.
 */
export async function planLateRefund(
  tx: Transaction, db: Firestore, sessionId: string, row: LateCancel, session: SessionLite,
): Promise<NonNullable<LateRefundPlan>> {
  const spendRef = db.doc(`creditHistory/${row.spendId}`);
  const refundRef = db.doc(`creditHistory/${refundDocId(row.spendId)}`);
  const userRef = db.doc(`users/${row.uid}`);
  const [spend, refund, user] = await Promise.all([tx.get(spendRef), tx.get(refundRef), tx.get(userRef)]);
  const lateRef = db.doc(`liveSessions/${sessionId}/lateCancels/${row.uid}`);
  const amount = roundCents(refundAmount(Number(spend.get('creditAmount')) || 0, session.costPerPlayer));
  const nothing = !spend.exists || spend.get('refundedAt') != null || isPaidRefund(refund.data(), row.uid) ||
    !user.exists || amount <= 0;
  return {
    uid: row.uid, spendRef, lateRef, refundRef, userRef,
    amount: nothing ? 0 : amount,
    balance: nothing ? 0 : parseFloat(user.get('credits') ?? '0') || 0,
    sessionId, title: session.title ?? '', groupId: session.groupId ?? '',
  };
}

/** A waitlist fill gives the oldest late canceller their saldo back. Reads only. */
export async function readLateRefund(
  tx: Transaction, db: Firestore, sessionId: string, exceptUid: string, session: SessionLite,
): Promise<LateRefundPlan> {
  const row = pickLateCancel(await readLateCancels(tx, db, sessionId), exceptUid);
  return row ? planLateRefund(tx, db, sessionId, row, session) : null;
}

export function applyLateRefund(tx: Transaction, plan: LateRefundPlan): void {
  if (!plan) return;
  tx.update(plan.lateRef, {refunded: true, refundedAt: FieldValue.serverTimestamp()});
  if (plan.amount <= 0) return;
  const after = roundCents(plan.balance + plan.amount);
  tx.update(plan.userRef, {credits: formatCredits(after)});
  tx.update(plan.spendRef, {refundedAt: FieldValue.serverTimestamp()});
  tx.set(plan.refundRef, {
    userId: plan.uid,
    creditAmount: plan.amount,
    amountPaid: 0.0,
    createdAt: FieldValue.serverTimestamp(),
    status: 'completed',
    entryType: 'refund',
    direction: 'credit',
    sourceType: 'session',
    sourceId: plan.sessionId,
    sessionId: plan.sessionId,
    sessionTitle: plan.title,
    groupId: plan.groupId,
    balanceBefore: plan.balance,
    balanceAfter: after,
    notes: `Reembolso: tu cupo fue tomado desde la lista de espera (${plan.title})`,
  });
}

export async function notifyLateRefund(db: Firestore, sender: Sender, plan: LateRefundPlan): Promise<void> {
  if (!plan || plan.amount <= 0) return;
  try {
    await sendToUser(db, sender, plan.uid, lateCancelRefundPush(plan.amount, plan.title));
  } catch (e) {
    console.error('late refund push failed', plan.sessionId, plan.uid, e);
  }
}
