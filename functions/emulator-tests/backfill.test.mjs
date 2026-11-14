// Emulator test: scripts/backfillPublicEvents.ts (batch boundary, idempotency, no leaks). Needs Firestore emulator WITHOUT the Functions emulator.
// Run: npm run test:emulator (from functions/). Needs its own clean Firestore emulator: other tests leave public liveSessions behind.
import {createRequire} from 'node:module';
import {execFileSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const FN = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const req = createRequire(FN + '/package.json');
const {initializeApp} = req('firebase-admin/app');
const {getFirestore, Timestamp} = req('firebase-admin/firestore');
initializeApp({projectId: 'demo-proplay'});
const db = getFirestore();

const base = (over = {}) => ({
  templateId: 't1', groupId: 'g1', title: 'E', eventDate: Timestamp.fromMillis(Date.now() + 48 * 3600e3),
  eventEndDate: Timestamp.fromMillis(Date.now() + 49 * 3600e3), status: 'OPEN', playerCount: 0, maxPlayers: 10,
  costPerPlayer: 10, isPrivate: false, sport: 'fútbol', minAge: 18, maxAge: 60, desiredGender: 'any',
  district: 'Miraflores', ...over,
});
const run = () => execFileSync('npx', ['tsx', 'scripts/backfillPublicEvents.ts'], {
  cwd: FN, env: {...process.env, GCLOUD_PROJECT: 'demo-proplay'}, encoding: 'utf8',
});
const count = async () => (await db.collection('publicEvents').count().get()).data().count;

const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}

await db.doc('groups/g1').set({name: 'Club Lima'});
// 450 public (crosses the 400-doc batch boundary), 1 private, 1 legacy without isPrivate, 1 public with players
let batch = db.batch();
for (let i = 0; i < 450; i++) {
  batch.set(db.doc(`liveSessions/pub${i}`), base({title: `E${i}`}));
  if ((i + 1) % 200 === 0) { await batch.commit(); batch = db.batch(); }
}
await batch.commit();
await db.doc('liveSessions/priv1').set(base({isPrivate: true}));
const legacy = base(); delete legacy.isPrivate;
await db.doc('liveSessions/legacy1').set(legacy);
await db.doc('liveSessions/withPlayers').set(base({players: [{uid: 'u1', firstName: 'Ana'}], playerCount: 1, receiptUrl: 'secret'}));

await t('empty publicEvents before the run', async () => assert.equal(await count(), 0));

let out;
await t('backfill runs and reports 451 public sessions written', async () => {
  out = run();
  console.log('   ' + out.trim().split('\n').join('\n   '));
  assert.match(out, /Public liveSessions found: 451/);
  assert.match(out, /publicEvents written: 451/);
});
await t('exactly 451 projections (450 + withPlayers); private and legacy skipped', async () => {
  assert.equal(await count(), 451);
  assert.ok(!(await db.doc('publicEvents/priv1').get()).exists);
  assert.ok(!(await db.doc('publicEvents/legacy1').get()).exists);
});
await t('first and last doc across the batch boundary are present with groupName', async () => {
  for (const id of ['pub0', 'pub399', 'pub400', 'pub449']) {
    const s = await db.doc(`publicEvents/${id}`).get();
    assert.ok(s.exists, id);
    assert.equal(s.data().groupName, 'Club Lima');
    assert.equal(s.data().district, 'Miraflores');
  }
});
await t('no players / secrets leaked by the backfill', async () => {
  const p = (await db.doc('publicEvents/withPlayers').get()).data();
  const flat = JSON.stringify(p);
  assert.equal(p.playerCount, 1);
  for (const leak of ['players', 'Ana', 'secret', 'receiptUrl']) assert.ok(!flat.includes(leak), leak);
});
await t('idempotent: a second run keeps 451 and repairs a stale projection', async () => {
  await db.doc('publicEvents/pub5').update({title: 'STALE', playerCount: 99});
  run();
  assert.equal(await count(), 451);
  const p = (await db.doc('publicEvents/pub5').get()).data();
  assert.equal(p.title, 'E5');
  assert.equal(p.playerCount, 0);
});
await t('does not delete extra projections (documents current behavior)', async () => {
  await db.doc('publicEvents/orphan').set({title: 'orphan'});
  run();
  assert.ok((await db.doc('publicEvents/orphan').get()).exists);
});

const failed = results.filter((r) => !r).length;
console.log(`\nbackfill: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
