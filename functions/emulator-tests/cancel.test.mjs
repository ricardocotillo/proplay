// Emulator test: cancelParticipation (calls the compiled callable's .run against the Firestore emulator).
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
const {cancelParticipation} = req(FN + '/lib/cancelParticipation.js');

const H = 3600 * 1000;
let n = 0;
const results = [];

async function seed({
  hoursAhead = 48, cost = 10, credits = '20.00', inPlayers = true,
  ticket = {status: 'valid', validationToken: 'tok', pricePaid: 10}, // null = no ticket
  spends = [{creditAmount: 10}],
} = {}) {
  const id = `c${++n}`;
  const uid = `u${n}`;
  await db.doc(`users/${uid}`).set({credits});
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: 'g1', isPrivate: false, costPerPlayer: cost,
    eventDate: Timestamp.fromMillis(Date.now() + hoursAhead * H),
    players: inPlayers ? [{uid}, {uid: 'other'}] : [{uid: 'other'}],
    playerCount: inPlayers ? 2 : 1,
  });
  if (ticket) await db.doc(`tickets/${id}_${uid}`).set({userId: uid, sessionId: id, ...ticket});
  let i = 0;
  for (const s of spends) {
    await db.doc(`creditHistory/sp${n}_${i++}`).set({
      userId: uid, sourceId: id, entryType: 'spend', direction: 'debit',
      createdAt: Timestamp.fromMillis(Date.now() - (10 - i) * 1000), ...s,
    });
  }
  return {id, uid, spendId: `sp${n}_0`};
}
const call = (uid, id) => cancelParticipation.run({
  auth: uid ? {uid, token: {}} : undefined, data: {sessionId: id}, rawRequest: {}, acceptsStreaming: false,
});
const credits = async (uid) => (await db.doc(`users/${uid}`).get()).data().credits;
const refundRows = async (uid) =>
  (await db.collection('creditHistory').where('userId', '==', uid).where('entryType', '==', 'refund').get()).size;
const rejects = async (p, code) => {
  try { await p; } catch (e) { assert.equal(e.code, code, `code ${e.code}: ${e.message}`); return; }
  assert.fail('expected rejection ' + code);
};

async function t(name, fn) {
  try { await fn(); results.push([name, true]); console.log('PASS', name); }
  catch (e) { results.push([name, false]); console.log('FAIL', name, '\n   ', e.message); }
}

await t('refunds in full at 48 h: credits, seat, ticket, ledger', async () => {
  const {id, uid, spendId} = await seed();
  assert.deepEqual(await call(uid, id), {refunded: true, amount: 10});
  assert.equal(await credits(uid), '30.00');
  const s = (await db.doc(`liveSessions/${id}`).get()).data();
  assert.equal(s.playerCount, 1);
  assert.ok(!s.players.some((p) => p.uid === uid));
  assert.ok(!(await db.doc(`tickets/${id}_${uid}`).get()).exists);
  assert.equal(await refundRows(uid), 1);
  assert.ok((await db.doc(`creditHistory/${spendId}`).get()).data().refundedAt);
});

await t('second cancel after success is rejected, no second refund', async () => {
  const {id, uid} = await seed();
  await call(uid, id);
  await rejects(call(uid, id), 'failed-precondition');
  assert.equal(await credits(uid), '30.00');
  assert.equal(await refundRows(uid), 1);
});

await t('two concurrent cancels refund exactly once', async () => {
  const {id, uid} = await seed();
  const r = await Promise.allSettled([call(uid, id), call(uid, id)]);
  assert.equal(r.filter((x) => x.status === 'fulfilled').length, 1);
  assert.equal(await credits(uid), '30.00');
  assert.equal(await refundRows(uid), 1);
});

await t('23 h 59 m: seat freed, ticket deleted, NO refund', async () => {
  const {id, uid} = await seed({hoursAhead: 23.98});
  assert.deepEqual(await call(uid, id), {refunded: false, amount: 0});
  assert.equal(await credits(uid), '20.00');
  assert.equal(await refundRows(uid), 0);
  assert.ok(!(await db.doc(`tickets/${id}_${uid}`).get()).exists);
});

await t('24 h 1 m: refunded', async () => {
  const {id, uid} = await seed({hoursAhead: 24.02});
  assert.equal((await call(uid, id)).refunded, true);
});

await t('event already started: rejected, seat kept', async () => {
  const {id, uid} = await seed({hoursAhead: -1});
  await rejects(call(uid, id), 'failed-precondition');
  assert.equal((await db.doc(`liveSessions/${id}`).get()).data().playerCount, 2);
});

await t('used ticket: rejected', async () => {
  const {id, uid} = await seed({ticket: {status: 'used', validationToken: 't'}});
  await rejects(call(uid, id), 'failed-precondition');
  assert.equal(await credits(uid), '20.00');
});

await t('user not in players: rejected', async () => {
  const {id, uid} = await seed({inPlayers: false});
  await rejects(call(uid, id), 'failed-precondition');
  assert.equal(await credits(uid), '20.00');
});

await t('unauthenticated: rejected', async () => {
  const {id} = await seed();
  await rejects(call(undefined, id), 'unauthenticated');
});

await t('missing sessionId: invalid-argument', async () => {
  await rejects(call('u1', ''), 'invalid-argument');
});

await t('unknown session: not-found', async () => {
  await rejects(call('u1', 'does-not-exist'), 'not-found');
});

await t('forged pricePaid 500 on a S/10 event refunds 10', async () => {
  const {id, uid} = await seed({ticket: {status: 'valid', validationToken: 'x', pricePaid: 500}});
  assert.equal((await call(uid, id)).amount, 10);
  assert.equal(await credits(uid), '30.00');
});

await t('forged spend row of 500 is capped to event price', async () => {
  const {id, uid} = await seed({spends: [{creditAmount: 500}]});
  assert.equal((await call(uid, id)).amount, 10);
});

await t('legacy: no ticket, spend row present: refund works', async () => {
  const {id, uid} = await seed({ticket: null});
  assert.equal((await call(uid, id)).refunded, true);
  assert.equal(await credits(uid), '30.00');
});

await t('player with no spend row: seat freed, no refund', async () => {
  const {id, uid} = await seed({spends: []});
  assert.deepEqual(await call(uid, id), {refunded: false, amount: 0});
  assert.equal(await credits(uid), '20.00');
});

await t('free event (cost 0): no refund row, no error', async () => {
  const {id, uid} = await seed({cost: 0, spends: [{creditAmount: 0}], ticket: {status: 'valid', validationToken: 'f', pricePaid: 0}});
  assert.deepEqual(await call(uid, id), {refunded: false, amount: 0});
  assert.equal(await refundRows(uid), 0);
});

await t('credits stay 2-decimal strings (15.50 + 7.25)', async () => {
  const {id, uid} = await seed({cost: 7.25, credits: '15.50', spends: [{creditAmount: 7.25}], ticket: {status: 'valid', validationToken: 'd', pricePaid: 7.25}});
  await call(uid, id);
  assert.equal(await credits(uid), '22.75');
});

await t('cancel, rejoin (new spend), cancel again: second refund works', async () => {
  const {id, uid} = await seed();
  await call(uid, id);
  await db.doc(`liveSessions/${id}`).update({players: [{uid}, {uid: 'other'}], playerCount: 2});
  await db.doc(`tickets/${id}_${uid}`).set({userId: uid, status: 'valid', validationToken: 'new'});
  await db.doc(`creditHistory/sp_re_${id}`).set({userId: uid, sourceId: id, entryType: 'spend', creditAmount: 10, createdAt: Timestamp.now()});
  assert.equal((await call(uid, id)).refunded, true);
  assert.equal(await refundRows(uid), 2);
});

const failed = results.filter((r) => !r[1]).length;
console.log(`\nfunction: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
