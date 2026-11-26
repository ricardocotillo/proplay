import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {getFirestore, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {claim, sendToUser, Sender} from './notify';
import {claimId, creditApprovedPush, dueReminders, reminderPush} from './reminderPolicy';

const HOUR = 3600_000;

/**
 * Sends the reminders that are due. Looks at events starting within the next
 * 25 h, claims each (event, kind) once, and pushes every player.
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
    const players: {uid?: string}[] = Array.isArray(s.players) ? s.players : [];
    if (players.length === 0) continue;
    for (const kind of dueReminders(eventMs, nowMs)) {
      if (!(await claim(db, claimId(kind, doc.id)))) continue;
      events++;
      const push = reminderPush(kind, s.title ?? 'Tu evento', eventMs, doc.id);
      for (const p of players) {
        if (typeof p?.uid === 'string') sent += await sendToUser(db, sender, p.uid, push);
      }
    }
  }
  return {events, sent};
}

/** Every 10 minutes: free-cancel deadline and 2 h reminders. */
export const sendReminders = onSchedule('every 10 minutes', async () => {
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
