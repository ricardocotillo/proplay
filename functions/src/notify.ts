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

/** Errors that mean the token is dead and should be forgotten. */
const DEAD = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
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
  const res = await sender.sendEachForMulticast({
    tokens: list,
    notification: {title: push.title, body: push.body},
    data: {path: push.path},
    // FCM requires an https link; the page opens it on click.
    webpush: {fcmOptions: {link: `${SITE}${push.path}`}},
  });
  let ok = 0;
  await Promise.all(res.responses.map(async (r, i) => {
    if (r.success) ok++;
    else if (r.error?.code && DEAD.has(r.error.code)) {
      await db.doc(`users/${uid}/fcmTokens/${list[i]}`).delete();
    }
  }));
  return ok;
}
