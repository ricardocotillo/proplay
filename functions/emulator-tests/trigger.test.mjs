// Emulator test: mirrorPublicEvent trigger through the Functions emulator.
// Run: npm run test:emulator (from functions/).
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const FN = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const req = createRequire(FN + '/package.json');
const {initializeApp} = req('firebase-admin/app');
const {getFirestore, Timestamp} = req('firebase-admin/firestore');
initializeApp({projectId: 'demo-proplay'});
const db = getFirestore();

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, what, ms = 25000) {
  const end = Date.now() + ms;
  let last;
  while (Date.now() < end) {
    try { const v = await fn(); if (v) return v; } catch (e) { last = e; }
    await sleep(300);
  }
  throw new Error(`timeout waiting for: ${what}` + (last ? ` (${last.message})` : ''));
}
const pub = async (id) => { const s = await db.doc(`publicEvents/${id}`).get(); return s.exists ? s.data() : null; };
const gone = (id) => async () => (await pub(id)) === null;
const base = (over = {}) => ({
  templateId: 't1', groupId: 'g1', title: 'Pichanga', eventDate: Timestamp.fromMillis(Date.now() + 48 * 3600e3),
  eventEndDate: Timestamp.fromMillis(Date.now() + 49 * 3600e3), status: 'OPEN', playerCount: 0, maxPlayers: 10,
  costPerPlayer: 10, isPrivate: false, sport: 'fútbol', minAge: 18, maxAge: 60, desiredGender: 'any',
  locationLat: -12.1, locationLng: -77.0, locationAddress: 'Av. X', district: 'Miraflores', format: '5v5',
  g: '6mc2yq', l: [-12.1, -77.0], ...over,
});

const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}

await db.doc('groups/g1').set({name: 'Club Lima'});

await t('public create: projection appears with public fields + groupName', async () => {
  await db.doc('liveSessions/a1').set(base());
  const p = await waitFor(() => pub('a1'), 'a1 projection');
  assert.equal(p.id, 'a1');
  assert.equal(p.title, 'Pichanga');
  assert.equal(p.groupName, 'Club Lima');
  assert.equal(p.district, 'Miraflores');
  assert.equal(p.format, '5v5');
  assert.equal(p.g, '6mc2yq');
  assert.deepEqual(p.l, [-12.1, -77.0]);
  assert.equal(p.costPerPlayer, 10);
  assert.equal(p.isPrivate, false);
});

await t('players[] and unlisted fields never reach publicEvents', async () => {
  await db.doc('liveSessions/a2').set(base({
    players: [{uid: 'u1', firstName: 'Ana', lastName: 'Perez', profileImageUrl: 'http://x/img.jpg', receiptUrl: 'r'}],
    playerCount: 1, receiptUrl: 'secret', internalNote: 'private note',
  }));
  const p = await waitFor(() => pub('a2'), 'a2 projection');
  assert.equal(p.playerCount, 1);
  const flat = JSON.stringify(p);
  for (const leak of ['players', 'Ana', 'Perez', 'profileImageUrl', 'receiptUrl', 'secret', 'internalNote', 'u1']) {
    assert.ok(!flat.includes(leak), `leaked: ${leak}`);
  }
});

await t('join (players + playerCount update) updates the projection, still no players', async () => {
  await db.doc('liveSessions/a1').update({players: [{uid: 'u9', firstName: 'Zed'}], playerCount: 1});
  const p = await waitFor(async () => { const x = await pub('a1'); return x?.playerCount === 1 ? x : null; }, 'playerCount 1');
  assert.ok(!('players' in p));
  assert.ok(!JSON.stringify(p).includes('Zed'));
});

await t('public -> private deletes the projection', async () => {
  await db.doc('liveSessions/a1').update({isPrivate: true});
  await waitFor(gone('a1'), 'a1 removed');
});

await t('private -> public brings it back', async () => {
  await db.doc('liveSessions/a1').update({isPrivate: false});
  await waitFor(() => pub('a1'), 'a1 back');
});

await t('private create: no projection', async () => {
  await db.doc('liveSessions/p1').set(base({isPrivate: true}));
  await sleep(4000);
  assert.equal(await pub('p1'), null);
});

await t('legacy doc without isPrivate: treated private, no projection', async () => {
  const d = base(); delete d.isPrivate;
  await db.doc('liveSessions/l1').set(d);
  await sleep(4000);
  assert.equal(await pub('l1'), null);
});

await t('delete liveSession deletes the projection', async () => {
  await db.doc('liveSessions/a2').delete();
  await waitFor(gone('a2'), 'a2 removed');
});

await t('missing group: still projected, no groupName field', async () => {
  await db.doc('liveSessions/n1').set(base({groupId: 'no-such-group'}));
  const p = await waitFor(() => pub('n1'), 'n1 projection');
  assert.ok(!('groupName' in p));
});

await t('old event without district/format: projected without those keys', async () => {
  const d = base(); delete d.district; delete d.format;
  await db.doc('liveSessions/o1').set(d);
  const p = await waitFor(() => pub('o1'), 'o1 projection');
  assert.ok(!('district' in p) && !('format' in p));
});

await t('rapid burst of 8 updates converges to the last value', async () => {
  await db.doc('liveSessions/r1').set(base());
  await waitFor(() => pub('r1'), 'r1 projection');
  for (let i = 1; i <= 8; i++) await db.doc('liveSessions/r1').update({playerCount: i});
  await waitFor(async () => (await pub('r1'))?.playerCount === 8, 'playerCount 8');
});

await t('delete of a session with no projection does not break the trigger', async () => {
  await db.doc('liveSessions/p1').delete();
  await db.doc('liveSessions/z1').set(base());
  await waitFor(() => pub('z1'), 'z1 projection after odd delete');
});

const failed = results.filter((r) => !r).length;
console.log(`\ntrigger: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
