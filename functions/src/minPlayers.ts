import {onSchedule} from 'firebase-functions/v2/scheduler';
import {getFirestore, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {claim, Sender, sendToUser} from './notify';
import {cancelEventTx} from './organizer';
import {claimId} from './reminderPolicy';
import {
  CHECK_FROM_MS, CHECK_TO_MS, minCancelOrganizerPush, minCancelPlayerPush, shouldAutoCancel,
} from './minPlayersPolicy';
import {notifyLateRefund, readLateCancels} from './waitlist';

const SKIP = new Error('skip');

/**
 * Cancels events with a minimum that are short of players in the hour after
 * the 24 h mark: everyone is refunded in full (same transaction as the
 * organizer's "Cancelar evento"), the waitlist ends, and players, the
 * organizer and the waitlist are told. The underfilled check is repeated
 * inside the transaction, so a late join wins.
 */
export async function runAutoCancel(
  db: Firestore, sender: Sender, nowMsArg?: number,
): Promise<{cancelled: number; failed: number}> {
  const nowMs = nowMsArg ?? Date.now();
  const snap = await db.collection('liveSessions')
    .where('eventDate', '>', Timestamp.fromMillis(nowMs + CHECK_FROM_MS))
    .where('eventDate', '<=', Timestamp.fromMillis(nowMs + CHECK_TO_MS))
    .get();
  let cancelled = 0;
  let failed = 0;
  for (const doc of snap.docs) {
    const s = doc.data();
    const held = Array.isArray(s.players) ? s.players.length : 0;
    if (!shouldAutoCancel({
      eventMs: s.eventDate?.toMillis?.() ?? 0, nowMs, min: s.minPlayers, max: s.maxPlayers, players: held,
    })) continue;
    // Late cancellers (not paid back yet) still count: leaving inside the
    // window must not be a way to force the cancel and walk away refunded.
    const late = (await doc.ref.collection('lateCancels').get()).docs.filter((d) => d.get('refunded') !== true).length;
    if (!shouldAutoCancel({
      eventMs: s.eventDate?.toMillis?.() ?? 0, nowMs, min: s.minPlayers, max: s.maxPlayers, players: held + late,
    })) continue;
    try {
      const min = s.minPlayers as number;
      const out = await cancelEventTx(db, doc.id, async (tx) => {
        const fresh = await tx.get(doc.ref);
        const d = fresh.data();
        const list: {uid?: string}[] = Array.isArray(d?.players) ? d!.players : [];
        const lateNow = (await readLateCancels(tx, db, doc.id)).filter((r) => !r.refunded).length;
        if (!d || !shouldAutoCancel({
          eventMs: d.eventDate?.toMillis?.() ?? 0, nowMs, min: d.minPlayers, max: d.maxPlayers,
          players: list.length + lateNow,
        })) throw SKIP;
        return {sessionRef: doc.ref, session: d, players: list};
      }, (x) => `Reembolso: evento cancelado por falta de jugadores (${x.title ?? ''})`);
      cancelled++;
      await Promise.all(out.late.map((l) => notifyLateRefund(db, sender, l)));
      const told = new Set<string>();
      const tell = async (uid: string, push: ReturnType<typeof minCancelPlayerPush>) => {
        if (told.has(uid)) return;
        told.add(uid);
        try {
          if (await claim(db, claimId('min_cancel', `${doc.id}_${uid}`))) await sendToUser(db, sender, uid, push);
        } catch (e) {
          console.error('min-players push failed', doc.id, uid, e);
        }
      };
      // The creator first: if they are also a player, one message tells them both.
      if (out.creatorId) await tell(out.creatorId, minCancelOrganizerPush(out.title, min, held));
      for (const r of out.refundedBy) await tell(r.uid, minCancelPlayerPush(out.title, min, r.amount));
      for (const uid of out.waitlistUids) await tell(uid, minCancelPlayerPush(out.title, min, 0));
    } catch (e) {
      if (e !== SKIP) {
        failed++;
        console.error('auto-cancel failed', doc.id, e);
      }
    }
  }
  return {cancelled, failed};
}

/** Every 10 min: cancel events that are short of their minimum. */
export const autoCancelUnderfilled = onSchedule({schedule: 'every 10 minutes', timeoutSeconds: 300}, async () => {
  const out = await runAutoCancel(getFirestore(), getMessaging());
  // Fail the run so it shows in the logs and Cloud Scheduler retries it.
  if (out.failed > 0) throw new Error(`auto-cancel failed for ${out.failed} event(s)`);
});
