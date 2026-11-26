import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {getFirestore, FieldValue, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {Sender, sendToUser} from './notify';
import {
  isBlocked, isNoShow, nextBlockMs, noShowActions, noShowBlockPush, noShowWarnPush, WINDOW_MS, BLOCK_AT,
} from './attendancePolicy';

const HOUR = 3600_000;
/** Organizers get this long after the end to take attendance before anyone is recorded. */
const GRACE_MS = 6 * HOUR;

/** `users/{uid}/noShows/{eventId}`: server-only record of one missed event. */
const noShowRef = (db: Firestore, uid: string, eventId: string) =>
  db.doc(`users/${uid}/noShows/${eventId}`);

async function countRecent(db: Firestore, uid: string, nowMs: number): Promise<number> {
  const snap = await db.collection(`users/${uid}/noShows`)
    .where('at', '>', Timestamp.fromMillis(nowMs - WINDOW_MS)).get();
  return snap.size;
}

/**
 * Records a no-show for every player of ended events who held a valid (never
 * used) ticket, but only for events where the organizer took attendance (at
 * least one ticket is `used`), then applies the policy: a warning on the 2nd
 * in 90 days, a 14-day block on the 3rd. Each (event, player) is recorded once.
 */
export async function runAttendance(
  db: Firestore, sender: Sender, nowMsArg?: number,
): Promise<{recorded: number; blocked: number}> {
  const nowMs = nowMsArg ?? Date.now();
  const ended = await db.collection('liveSessions')
    .where('eventEndDate', '>', Timestamp.fromMillis(nowMs - 48 * HOUR))
    .where('eventEndDate', '<=', Timestamp.fromMillis(nowMs - GRACE_MS))
    .get();
  let recorded = 0;
  let blocked = 0;
  for (const ev of ended.docs) {
    try {
      const tickets = await db.collection('tickets').where('sessionId', '==', ev.id).get();
      const anyoneCheckedIn = tickets.docs.some((t) => t.get('status') === 'used');
      if (!anyoneCheckedIn) continue;
      for (const t of tickets.docs) {
        if (!isNoShow(t.get('status'), anyoneCheckedIn)) continue;
        const uid = String(t.get('userId'));
        let created = true;
        try {
          await noShowRef(db, uid, ev.id).create({
            eventId: ev.id, title: String(ev.get('title') ?? ''), at: FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if ((e as {code?: number}).code !== 6) throw e;
          created = false; // recorded by an earlier run that may have died before the block
        }
        if (created) recorded++;
        const count = await countRecent(db, uid, nowMs);
        const act = noShowActions(count);
        if (act.block) {
          const userRef = db.doc(`users/${uid}`);
          const user = await userRef.get();
          if (!user.exists) continue;
          const current: number | undefined = user.get('blockedUntil')?.toMillis?.();
          // A retry only repairs a missing block; it never extends or re-notifies.
          if (!created && isBlocked(current, nowMs)) continue;
          const until = nextBlockMs(current, nowMs);
          await userRef.update({blockedUntil: Timestamp.fromMillis(until)});
          blocked++;
          await sendToUser(db, sender, uid, noShowBlockPush(until)).catch((e) => console.error('noshow push', e));
        } else if (created && act.warn) {
          await sendToUser(db, sender, uid, noShowWarnPush(String(ev.get('title') ?? 'Tu evento')))
            .catch((e) => console.error('noshow push', e));
        }
      }
    } catch (e) {
      console.error('attendance failed', ev.id, e);
    }
  }
  return {recorded, blocked};
}

/**
 * The organizer marked someone present after the fact: forget that no-show
 * and lift the block when fewer than BLOCK_AT remain in the window.
 */
export async function forgiveNoShow(
  db: Firestore, uid: string, eventId: string, nowMs: number,
): Promise<boolean> {
  const ref = noShowRef(db, uid, eventId);
  const userRef = db.doc(`users/${uid}`);
  return db.runTransaction(async (tx) => {
    if (!(await tx.get(ref)).exists) return false;
    const recent = await tx.get(
      db.collection(`users/${uid}/noShows`).where('at', '>', Timestamp.fromMillis(nowMs - WINDOW_MS)),
    );
    const left = recent.docs.filter((d) => d.id !== eventId).length;
    const user = await tx.get(userRef);
    tx.delete(ref);
    if (left < BLOCK_AT && user.exists) tx.update(userRef, {blockedUntil: FieldValue.delete()});
    return true;
  });
}

/** Door staff scan a ticket (client write status -> used): forgive that event's no-show too. */
export const forgiveOnScan = onDocumentUpdated('tickets/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.status === 'used' || after.status !== 'used') return;
  if (typeof after.userId !== 'string' || typeof after.sessionId !== 'string') return;
  await forgiveNoShow(getFirestore(), after.userId, after.sessionId, Date.now());
});

/** Hourly: record no-shows of events that ended 6 to 48 h ago. */
export const recordAttendance = onSchedule({schedule: 'every 60 minutes', timeoutSeconds: 300}, async () => {
  await runAttendance(getFirestore(), getMessaging());
});
