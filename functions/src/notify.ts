import {Firestore, FieldValue} from 'firebase-admin/firestore';
import {Push} from './reminderPolicy';

/** The slice of firebase-admin `Messaging` we use (a fake in tests). */
export type Sender = {
  sendEachForMulticast(m: {
    tokens: string[];
    notification: {title: string; body: string};
    data: Record<string, string>;
    webpush?: {fcmOptions?: {link: string}};
  }): Promise<{responses: {success: boolean; error?: {code?: string}}[]}>;
};

const SITE = 'https://proplayapp.com';

/** FCM accepts at most 500 tokens per multicast. */
const BATCH = 500;

/** Errors that mean the token is dead and should be forgotten. */
const DEAD = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

/**
 * Claim a notification exactly once: `notificationsSent/{id}` is created, and
 * a second create fails. Returns true only for the caller that created it.
 */
export async function claim(db: Firestore, id: string): Promise<boolean> {
  try {
    await db.doc(`notificationsSent/${id}`).create({at: FieldValue.serverTimestamp()});
    return true;
  } catch (e) {
    if ((e as {code?: number | string}).code === 6 || (e as {code?: string}).code === 'already-exists') {
      return false;
    }
    throw e;
  }
}

/** Does this user have at least one device with push enabled? */
export async function hasDevices(db: Firestore, uid: string): Promise<boolean> {
  return !(await db.collection(`users/${uid}/fcmTokens`).limit(1).get()).empty;
}

/**
 * Push to every device a user enabled (`users/{uid}/fcmTokens`). Dead tokens
 * are deleted. Returns how many devices accepted it.
 */
export async function sendToUser(
  db: Firestore, sender: Sender, uid: string, push: Push,
): Promise<number> {
  const tokens = await db.collection(`users/${uid}/fcmTokens`).get();
  if (tokens.empty) return 0;
  const list = tokens.docs.map((d) => d.id);
  let ok = 0;
  for (let i = 0; i < list.length; i += BATCH) {
    const batch = list.slice(i, i + BATCH);
    const res = await sender.sendEachForMulticast({
      tokens: batch,
      notification: {title: push.title, body: push.body},
      data: {path: push.path},
      // FCM requires an https link; the page opens it on click.
      webpush: {fcmOptions: {link: `${SITE}${push.path}`}},
    });
    await Promise.all(res.responses.map(async (r, j) => {
      if (r.success) ok++;
      else if (r.error?.code && DEAD.has(r.error.code)) {
        await db.doc(`users/${uid}/fcmTokens/${batch[j]}`).delete();
      }
    }));
  }
  return ok;
}

/**
 * A browser has one token. When it is registered for `uid` (login after
 * someone else, or a shared browser), forget it under every other user so
 * the previous account stops getting this browser's pushes.
 */
export async function dropTokenElsewhere(db: Firestore, uid: string, token: string): Promise<number> {
  const same = await db.collectionGroup('fcmTokens').where('token', '==', token).get();
  const stale = same.docs.filter((d) => d.ref.parent.parent?.id !== uid);
  await Promise.all(stale.map((d) => d.ref.delete()));
  return stale.length;
}
