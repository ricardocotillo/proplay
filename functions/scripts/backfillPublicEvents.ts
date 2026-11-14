// One-off: copy existing public liveSessions into publicEvents.
// Usage (owner, from functions/):
//   gcloud auth application-default login
//   npx tsx scripts/backfillPublicEvents.ts
// Against the emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx tsx scripts/backfillPublicEvents.ts
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {buildPublicEvent} from '../src/publicEvents';

async function main() {
  initializeApp({projectId: process.env.GCLOUD_PROJECT ?? 'proplay-eac23'});
  const db = getFirestore();
  const snap = await db.collection('liveSessions').where('isPrivate', '==', false).get();
  console.log(`Public liveSessions found: ${snap.size}`);

  const groupNames = new Map<string, string | undefined>();
  let batch = db.batch();
  let inBatch = 0;
  let written = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const gid: string | undefined = data.groupId;
    if (gid && !groupNames.has(gid)) {
      groupNames.set(gid, (await db.doc(`groups/${gid}`).get()).data()?.name);
    }
    const projection = buildPublicEvent(doc.id, data, gid ? groupNames.get(gid) : undefined);
    if (!projection) continue;
    batch.set(db.doc(`publicEvents/${doc.id}`), projection);
    written++;
    if (++inBatch === 400) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
    }
  }
  if (inBatch > 0) await batch.commit();
  console.log(`publicEvents written: ${written}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
