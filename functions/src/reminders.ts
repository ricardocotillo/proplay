import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {getFirestore, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {claim, dropTokenElsewhere, hasDevices, sendToUser, Sender} from './notify';
import {claimId, creditApprovedPush, dueReminders, reminderPush} from './reminderPolicy';

const HOUR = 3600_000;
/** Players notified at once per event (one multicast each). */
const CONCURRENCY = 20;

/**
 * Sends the reminders that are due. Looks at events starting within the next
 * 25 h and, per player with a device, claims (kind, event, player) once and
 * pushes. Claiming per player means: a player who enables push later still
 * gets it in a later run, one failed send never blocks the others, and a
 * crash loses at most the player being sent.
 */
export async function runReminders(
  db: Firestore, sender: Sender, nowMs: number,
): Promise<{events: number; sent: number}> {
  const snap = await db.collection('liveSessions')
    .where('eventDate', '>', Timestamp.fromMillis(nowMs))
    .where('eventDate', '<=', Timestamp.fromMillis(nowMs + 25 * HOUR))
    .get();
  let events = 0;
  let sent = 0;
  for (const doc of snap.docs) {
    const s = doc.data();
    const eventMs: number | undefined = s.eventDate?.toMillis?.();
    if (eventMs === undefined) continue;
    const uids: string[] = (Array.isArray(s.players) ? s.players : [])
      .map((p: {uid?: unknown}) => p?.uid)
      .filter((u: unknown): u is string => typeof u === 'string' && u.length > 0);
    if (uids.length === 0) continue;
    for (const kind of dueReminders(eventMs, nowMs)) {
      const push = reminderPush(kind, s.title ?? 'Tu evento', eventMs, doc.id);
      let any = false;
      for (let i = 0; i < uids.length; i += CONCURRENCY) {
        const counts = await Promise.all(uids.slice(i, i + CONCURRENCY).map(async (uid) => {
          try {
            if (!(await hasDevices(db, uid))) return 0; // not claimed: may enable later
            // Already at the door: "starts soon" is noise.
            if (kind === 'two_hours' && await isCheckedIn(db, doc.id, uid)) return 0;
            if (!(await claim(db, claimId(kind, `${doc.id}_${uid}`)))) return 0;
            const n = await sendToUser(db, sender, uid, push);
            any = true;
            return n;
          } catch (e) {
            console.error(`reminder ${kind} ${doc.id} ${uid} failed`, e);
            return 0;
          }
        }));
        sent += counts.reduce((a, b) => a + b, 0);
      }
      if (any) events++;
    }
  }
  return {events, sent};
}

async function isCheckedIn(db: Firestore, eventId: string, uid: string): Promise<boolean> {
  return (await db.doc(`tickets/${eventId}_${uid}`).get()).get('status') === 'used';
}

/** Every 10 minutes: free-cancel deadline and 2 h reminders. */
export const sendReminders = onSchedule({schedule: 'every 10 minutes', timeoutSeconds: 300}, async () => {
  await runReminders(getFirestore(), getMessaging(), Date.now());
});

/** A top-up goes pending -> approved: tell the buyer. */
export const notifyCreditApproved = onDocumentUpdated('creditHistory/{id}', async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status === 'approved' || after.status !== 'approved') return;
  if (after.entryType !== 'purchase' || typeof after.userId !== 'string') return;
  const db = getFirestore();
  if (!(await claim(db, claimId('credit_approved', event.params.id)))) return;
  await sendToUser(db, getMessaging(), after.userId, creditApprovedPush(Number(after.creditAmount) || 0));
});

/** A browser registers its token: forget it under any other account. */
export const claimDeviceToken = onDocumentCreated('users/{uid}/fcmTokens/{token}', async (event) => {
  await dropTokenElsewhere(getFirestore(), event.params.uid, event.params.token);
});
