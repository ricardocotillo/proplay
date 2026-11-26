import {onSchedule} from 'firebase-functions/v2/scheduler';
import {getFirestore, Firestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {claim, Sender, sendToUser} from './notify';
import {cancelEventTx} from './organizer';
import {claimId} from './reminderPolicy';
import {
  CHECK_FROM_MS, CHECK_TO_MS, minCancelOrganizerPush, minCancelPlayerPush, shouldAutoCancel,
} from './minPlayersPolicy';
import {notifyLateRefund} from './waitlist';

const SKIP = new Error('skip');

/**
 * Cancels events with a minimum that are short of players in the hour after
 * the 24 h mark: everyone is refunded in full (same transaction as the
 * organizer's "Cancelar evento"), the waitlist ends, and players, the
 * organizer and the waitlist are told. The underfilled check is repeated
 * inside the transaction, so a late join wins.
 */
export async function runAutoCancel(
  db: Firestore, sender: Sender, nowMs: number,
): Promise<{cancelled: number}> {
  const snap = await db.collection('liveSessions')
    .where('eventDate', '>', Timestamp.fromMillis(nowMs + CHECK_FROM_MS))
    .where('eventDate', '<=', Timestamp.fromMillis(nowMs + CHECK_TO_MS))
    .get();
  let cancelled = 0;
  for (const doc of snap.docs) {
    const s = doc.data();
    const players = Array.isArray(s.players) ? s.players.length : 0;
    if (!shouldAutoCancel({eventMs: s.eventDate?.toMillis?.() ?? 0, nowMs, min: s.minPlayers, players})) continue;
    try {
      const min = s.minPlayers as number;
      const out = await cancelEventTx(db, doc.id, async (tx) => {
        const fresh = await tx.get(doc.ref);
        const d = fresh.data();
        const list: {uid?: string}[] = Array.isArray(d?.players) ? d!.players : [];
        if (!d || !shouldAutoCancel({
          eventMs: d.eventDate?.toMillis?.() ?? 0, nowMs, min: d.minPlayers, players: list.length,
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
      for (const r of out.refundedBy) await tell(r.uid, minCancelPlayerPush(out.title, min, r.amount));
      for (const uid of out.waitlistUids) await tell(uid, minCancelPlayerPush(out.title, min, 0));
      if (out.creatorId) await tell(out.creatorId, minCancelOrganizerPush(out.title, min, players));
    } catch (e) {
      if (e !== SKIP) console.error('auto-cancel failed', doc.id, e);
    }
  }
  return {cancelled};
}

/** Every 10 min: cancel events that are short of their minimum. */
export const autoCancelUnderfilled = onSchedule({schedule: 'every 10 minutes', timeoutSeconds: 300}, async () => {
  await runAutoCancel(getFirestore(), getMessaging(), Date.now());
});
