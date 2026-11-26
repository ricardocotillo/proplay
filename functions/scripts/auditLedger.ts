// Read-only: list creditHistory rows a client may have forged before the
// PR 5 rules (spend/refund rows not shaped like the functions' own, future
// dates, saldo worth more than paid). Review each before deploying the rules;
// this script changes nothing.
// Usage (owner, from functions/):
//   gcloud auth application-default login
//   npx tsx scripts/auditLedger.ts
// Against the emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx tsx scripts/auditLedger.ts
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {ledgerSuspicion} from '../src/ledgerAudit';

async function main() {
  initializeApp({projectId: process.env.GCLOUD_PROJECT ?? 'proplay-eac23'});
  const snap = await getFirestore().collection('creditHistory').get();
  const now = Date.now();
  let flagged = 0;
  for (const doc of snap.docs) {
    const reasons = ledgerSuspicion(doc.id, doc.data(), now);
    if (reasons.length === 0) continue;
    flagged++;
    const d = doc.data();
    console.log(
      `${doc.id}\tuser=${d.userId}\ttype=${d.entryType}\tstatus=${d.status}` +
      `\tamount=${d.creditAmount}\t${reasons.join('; ')}`,
    );
  }
  console.log(`\n${flagged} of ${snap.size} rows flagged.`);
}

main().catch((e) => { console.error(e); process.exit(1); });
