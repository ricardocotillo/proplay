import {onSchedule} from 'firebase-functions/v2/scheduler';
import {getFirestore, FieldValue, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {Sender, sendToUser} from './notify';
import {
  isNoShow, nextBlockMs, noShowActions, noShowBlockPush, noShowWarnPush, WINDOW_MS, BLOCK_AT,
} from './attendancePolicy';

const HOUR = 3600_000;

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
    .where('eventEndDate', '<=', Timestamp.fromMillis(nowMs - HOUR))
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
        try {
          await noShowRef(db, uid, ev.id).create({
            eventId: ev.id, title: String(ev.get('title') ?? ''), at: FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if ((e as {code?: number}).code === 6) continue; // already recorded
          throw e;
        }
        recorded++;
        const count = await countRecent(db, uid, nowMs);
        const act = noShowActions(count);
        if (act.block) {
          const user = await db.doc(`users/${uid}`).get();
          const until = nextBlockMs(user.get('blockedUntil')?.toMillis?.(), nowMs);
          await db.doc(`users/${uid}`).update({blockedUntil: Timestamp.fromMillis(until)});
          blocked++;
          await sendToUser(db, sender, uid, noShowBlockPush(until)).catch((e) => console.error('noshow push', e));
        } else if (act.warn) {
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
  if (!(await ref.get()).exists) return false;
  await ref.delete();
  if ((await countRecent(db, uid, nowMs)) < BLOCK_AT) {
    await db.doc(`users/${uid}`).update({blockedUntil: FieldValue.delete()});
  }
  return true;
}

/** Hourly: record no-shows of events that ended 1 to 48 h ago. */
export const recordAttendance = onSchedule({schedule: 'every 60 minutes', timeoutSeconds: 300}, async () => {
  await runAttendance(getFirestore(), getMessaging());
});
