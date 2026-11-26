import {
  DocumentReference, FieldValue, Firestore, Timestamp, Transaction,
} from 'firebase-admin/firestore';
import {claim, Sender, sendToUser} from './notify';
import {claimId, lateCancelRefundPush, waitlistOfferPush} from './reminderPolicy';
import {formatCredits, isPaidRefund, refundAmount, refundDocId} from './refundPolicy';
import {roundCents} from './joinPolicy';
import {
  Entry, freeSeats, isActiveOffer, LateCancel, minutesLeft, offerExpiryMs, pickLateCancel,
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

/** Most waiting people checked for saldo when a seat frees (bounds the reads). */
const OFFER_SCAN = 10;

/**
 * After a seat freed (cancel, removal, expired or declined offer): who gets
 * it. The first person in line who can still pay `cost`; people short of saldo
 * keep their place but are skipped. Nothing is offered once the event started.
 * Does tx reads only: call it before the transaction's first write, then
 * apply with [applyOffer].
 */
export async function planOffer(
  tx: Transaction, db: Firestore, wl: WaitlistEntry[],
  c: {maxPlayers: number; playersAfter: number; eventMs: number; nowMs: number; cost: number},
): Promise<OfferPlan> {
  if (c.eventMs <= c.nowMs) return null;
  if (freeSeats(c.maxPlayers, c.playersAfter, holdsOf(wl, c.nowMs)) <= 0) return null;
  const line = wl
    .filter((e) => e.status === 'waiting')
    .sort((x, y) => x.joinedAtMs - y.joinedAtMs || (x.uid < y.uid ? -1 : 1))
    .slice(0, OFFER_SCAN);
  for (const e of line) {
    const user = await tx.get(db.doc(`users/${e.uid}`));
    const balance = parseFloat(user.get('credits') ?? '0') || 0;
    if (user.exists && balance >= roundCents(c.cost)) {
      return {ref: e.ref, uid: e.uid, expiresMs: offerExpiryMs(c.nowMs, c.eventMs)};
    }
  }
  return null;
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

/**
 * A player who cancels inside the no-refund window: remember their spend.
 * Keyed by the spend, so cancel, rejoin, cancel again keeps both entitlements.
 */
export function recordLateCancel(
  tx: Transaction, db: Firestore, sessionId: string, uid: string, spendId: string,
): void {
  tx.set(db.doc(`liveSessions/${sessionId}/lateCancels/${spendId}`), {
    uid, spendId, createdAt: FieldValue.serverTimestamp(), refunded: false,
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
    uid: String(d.get('uid')),
    spendId: d.id,
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
  const lateRef = db.doc(`liveSessions/${sessionId}/lateCancels/${row.spendId}`);
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
