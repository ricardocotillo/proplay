// Emulator test: joinSession (calls the compiled callable's .run against the Firestore emulator),
// plus join -> cancelParticipation -> rejoin end to end.
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
const {joinSession} = req(FN + '/lib/joinSession.js');
const {cancelParticipation} = req(FN + '/lib/cancelParticipation.js');

const H = 3600 * 1000;
let n = 0;
const results = [];

async function seed({
  hoursAhead = 48, cost = 10, credits = '20.00', maxPlayers = 10, players = [{uid: 'other'}],
  isPrivate = false, member = false,
} = {}) {
  const id = `j${++n}`;
  const uid = `ju${n}`;
  await db.doc(`users/${uid}`).set({
    credits, firstName: 'Ana', lastName: 'Pérez', profileImageUrl: null,
    documentType: 'dni', documentNumber: '12345678',
  });
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: `g${n}`, isPrivate, costPerPlayer: cost, maxPlayers, sport: 'fútbol',
    eventDate: Timestamp.fromMillis(Date.now() + hoursAhead * H),
    eventEndDate: Timestamp.fromMillis(Date.now() + (hoursAhead + 2) * H),
    locationAddress: 'Av. X 123', players, playerCount: players.length,
  });
  if (member) await db.doc(`groups/g${n}/members/${uid}`).set({role: 'member'});
  return {id, uid};
}
const run = (fn, uid, id) => fn.run({
  auth: uid ? {uid, token: {}} : undefined, data: {sessionId: id}, rawRequest: {}, acceptsStreaming: false,
});
const join = (uid, id) => run(joinSession, uid, id);
const cancel = (uid, id) => run(cancelParticipation, uid, id);
const credits = async (uid) => (await db.doc(`users/${uid}`).get()).data().credits;
const spends = async (uid) =>
  (await db.collection('creditHistory').where('userId', '==', uid).where('entryType', '==', 'spend').get()).docs;
const session = async (id) => (await db.doc(`liveSessions/${id}`).get()).data();
const rejects = async (p, code, msg) => {
  try { await p; } catch (e) {
    assert.equal(e.code, code, `code ${e.code}: ${e.message}`);
    if (msg) assert.match(e.message, msg);
    return;
  }
  assert.fail('expected rejection ' + code);
};

async function t(name, fn) {
  try { await fn(); results.push([name, true]); console.log('PASS', name); }
  catch (e) { results.push([name, false]); console.log('FAIL', name, '\n   ', e.message); }
}

await t('happy path: debit once, one spend, one player, one ticket', async () => {
  const {id, uid} = await seed();
  assert.deepEqual(await join(uid, id), {ticketId: `${id}_${uid}`, alreadyJoined: false});
  assert.equal(await credits(uid), '10.00');
  const rows = await spends(uid);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].data().creditAmount, 10);
  const s = await session(id);
  assert.equal(s.playerCount, 2);
  const me = s.players.find((p) => p.uid === uid);
  assert.equal(me.firstName, 'Ana');
  const ticket = (await db.doc(`tickets/${id}_${uid}`).get()).data();
  assert.equal(ticket.status, 'valid');
  assert.equal(ticket.pricePaid, 10);
  assert.equal(ticket.userDocumentNumber, '12345678');
  assert.ok(rows[0].id.endsWith(ticket.validationToken));
});

await t('retry after success returns the ticket without charging again', async () => {
  const {id, uid} = await seed();
  await join(uid, id);
  assert.deepEqual(await join(uid, id), {ticketId: `${id}_${uid}`, alreadyJoined: true});
  assert.equal(await credits(uid), '10.00');
  assert.equal((await spends(uid)).length, 1);
});

await t('insufficient balance is rejected with the S/ message', async () => {
  const {id, uid} = await seed({credits: '9.50'});
  await rejects(join(uid, id), 'failed-precondition', /saldo suficiente.*S\/ 10\.00.*S\/ 9\.50/);
  assert.equal(await credits(uid), '9.50');
});

await t('full event is rejected', async () => {
  const {id, uid} = await seed({maxPlayers: 1});
  await rejects(join(uid, id), 'failed-precondition', /lleno/);
});

await t('started event is rejected (server clock)', async () => {
  const {id, uid} = await seed({hoursAhead: -1});
  await rejects(join(uid, id), 'failed-precondition', /empezó/);
});

await t('private event: non-member rejected, member allowed', async () => {
  const a = await seed({isPrivate: true});
  await rejects(join(a.uid, a.id), 'permission-denied');
  const b = await seed({isPrivate: true, member: true});
  assert.equal((await join(b.uid, b.id)).alreadyJoined, false);
});

await t('unknown session and unauthenticated are rejected', async () => {
  const {uid} = await seed();
  await rejects(join(uid, 'nope'), 'not-found');
  await rejects(join(null, 'nope'), 'unauthenticated');
});

await t('two concurrent joins for the last seat: exactly one wins', async () => {
  const {id, uid} = await seed({maxPlayers: 2});
  const other = `${uid}_b`;
  await db.doc(`users/${other}`).set({credits: '20.00', firstName: 'B', lastName: 'C'});
  const r = await Promise.allSettled([join(uid, id), join(other, id)]);
  assert.equal(r.filter((x) => x.status === 'fulfilled').length, 1);
  assert.equal((await session(id)).playerCount, 2);
});

await t('balance comes from the server doc, not the client', async () => {
  const {id, uid} = await seed({credits: '15.00'});
  await db.doc(`users/${uid}`).update({credits: '30.00'}); // e.g. an approval landed
  await join(uid, id);
  assert.equal(await credits(uid), '20.00');
});

await t('join -> cancel refunds that spend -> rejoin charges again', async () => {
  const {id, uid} = await seed({credits: '25.00'});
  await join(uid, id);
  assert.deepEqual(await cancel(uid, id), {refunded: true, amount: 10});
  assert.equal(await credits(uid), '25.00');
  await join(uid, id);
  assert.equal(await credits(uid), '15.00');
  assert.equal((await spends(uid)).length, 2);
});

const failed = results.filter((r) => !r[1]).length;
console.log(`\njoin: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
