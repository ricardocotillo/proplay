// Emulator test: reviewCreditPurchase, cancelEvent and removePlayer (compiled
// callables' .run against the Firestore emulator), with real joins for spends.
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
const {cancelEvent, removePlayer} = req(FN + '/lib/organizer.js');
const {reviewCreditPurchase} = req(FN + '/lib/reviewCreditPurchase.js');

const H = 3600 * 1000;
let n = 0;
const results = [];

const run = (fn, uid, data) => fn.run({
  auth: uid ? {uid, token: {}} : undefined, data, rawRequest: {}, acceptsStreaming: false,
});
const credits = async (uid) => (await db.doc(`users/${uid}`).get()).data().credits;
const exists = async (path) => (await db.doc(path).get()).exists;
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

const user = (uid, data = {}) => db.doc(`users/${uid}`).set({
  credits: '30.00', firstName: 'Ana', lastName: 'Pérez', profileImageUrl: null,
  documentType: 'dni', documentNumber: '12345678', superUser: false, ...data,
});

/** Event owned by `o{n}` (group owner) with players `p{n}a`, `p{n}b` joined for real. */
async function seedEvent({hoursAhead = 48, cost = 10} = {}) {
  const k = ++n;
  const id = `e${k}`, owner = `o${k}`, a = `p${k}a`, b = `p${k}b`, g = `g${k}`;
  await Promise.all([user(owner), user(a), user(b), user(`m${k}`)]);
  await db.doc(`groups/${g}/members/${owner}`).set({role: 'owner'});
  await db.doc(`groups/${g}/members/m${k}`).set({role: 'member'});
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: g, isPrivate: false, costPerPlayer: cost, maxPlayers: 10,
    sport: 'fútbol', creatorId: 'someone',
    eventDate: Timestamp.fromMillis(Date.now() + 72 * H),
    eventEndDate: Timestamp.fromMillis(Date.now() + 74 * H),
    locationAddress: 'Av. X 123', players: [], playerCount: 0,
  });
  await run(joinSession, a, {sessionId: id});
  await run(joinSession, b, {sessionId: id});
  if (hoursAhead !== 72) {
    await db.doc(`liveSessions/${id}`).update({
      eventDate: Timestamp.fromMillis(Date.now() + hoursAhead * H),
    });
  }
  return {id, owner, a, b, member: `m${k}`};
}

// ---- reviewCreditPurchase ----
async function seedPurchase(amount = 20) {
  const k = ++n;
  const buyer = `b${k}`, admin = `s${k}`;
  await Promise.all([user(buyer, {credits: '5.00'}), user(admin, {superUser: true})]);
  const ref = await db.collection('creditHistory').add({
    userId: buyer, creditAmount: amount, amountPaid: amount * 1.05, status: 'pending',
    entryType: 'purchase', createdAt: Timestamp.now(),
  });
  return {buyer, admin, entryId: ref.id};
}

await t('approve credits the buyer once and marks the row', async () => {
  const {buyer, admin, entryId} = await seedPurchase();
  assert.deepEqual(await run(reviewCreditPurchase, admin, {entryId, approve: true}),
    {status: 'approved', balanceAfter: 25});
  assert.equal(await credits(buyer), '25.00');
  const row = (await db.doc(`creditHistory/${entryId}`).get()).data();
  assert.equal(row.status, 'approved');
  assert.equal(row.balanceBefore, 5);
  assert.equal(row.reviewedBy, admin);
  await rejects(run(reviewCreditPurchase, admin, {entryId, approve: true}),
    'failed-precondition', /ya fue revisada/);
  assert.equal(await credits(buyer), '25.00');
});

await t('two approvals at once credit once', async () => {
  const {buyer, admin, entryId} = await seedPurchase();
  const out = await Promise.allSettled([
    run(reviewCreditPurchase, admin, {entryId, approve: true}),
    run(reviewCreditPurchase, admin, {entryId, approve: true}),
  ]);
  assert.equal(out.filter((o) => o.status === 'fulfilled').length, 1);
  assert.equal(await credits(buyer), '25.00');
});

await t('reject leaves the balance and blocks a later approve', async () => {
  const {buyer, admin, entryId} = await seedPurchase();
  assert.deepEqual(await run(reviewCreditPurchase, admin, {entryId, approve: false}),
    {status: 'rejected'});
  assert.equal(await credits(buyer), '5.00');
  await rejects(run(reviewCreditPurchase, admin, {entryId, approve: true}),
    'failed-precondition', /ya fue revisada/);
});

await t('non-superUser, signed-out and bad input are refused', async () => {
  const {buyer, entryId} = await seedPurchase();
  await rejects(run(reviewCreditPurchase, buyer, {entryId, approve: true}), 'permission-denied');
  await rejects(run(reviewCreditPurchase, null, {entryId, approve: true}), 'unauthenticated');
  await rejects(run(reviewCreditPurchase, buyer, {entryId, approve: 'yes'}), 'invalid-argument');
  await rejects(run(reviewCreditPurchase, buyer, {entryId: 'a/b', approve: true}), 'invalid-argument');
  assert.equal(await credits(buyer), '5.00');
});

await t('a spend row cannot be approved', async () => {
  const {admin} = await seedPurchase();
  const ref = await db.collection('creditHistory').add({
    userId: admin, creditAmount: 10, status: 'pending', entryType: 'spend',
  });
  await rejects(run(reviewCreditPurchase, admin, {entryId: ref.id, approve: true}),
    'failed-precondition', /no es válida/);
});

// ---- cancelEvent ----
await t('cancel event refunds every player once, deletes tickets and event', async () => {
  const {id, owner, a, b} = await seedEvent();
  assert.equal(await credits(a), '20.00');
  assert.deepEqual(await run(cancelEvent, owner, {sessionId: id}), {refunded: 2, total: 20});
  assert.equal(await credits(a), '30.00');
  assert.equal(await credits(b), '30.00');
  assert.equal(await exists(`liveSessions/${id}`), false);
  assert.equal(await exists(`tickets/${id}_${a}`), false);
  const refunds = await db.collection('creditHistory')
    .where('sourceId', '==', id).where('entryType', '==', 'refund').get();
  assert.equal(refunds.size, 2);
  await rejects(run(cancelEvent, owner, {sessionId: id}), 'not-found');
});

await t('cancel inside 24 h still refunds (organizer cancelled)', async () => {
  const {id, owner, a} = await seedEvent({hoursAhead: 2});
  await run(cancelEvent, owner, {sessionId: id});
  assert.equal(await credits(a), '30.00');
});

await t('a player who already left with a refund is not refunded twice', async () => {
  const {id, owner, a, b} = await seedEvent();
  await run(cancelParticipation, a, {sessionId: id});
  assert.equal(await credits(a), '30.00');
  assert.deepEqual(await run(cancelEvent, owner, {sessionId: id}), {refunded: 1, total: 10});
  assert.equal(await credits(a), '30.00');
  assert.equal(await credits(b), '30.00');
});

await t('group admin, creator and superUser may cancel; member and player may not', async () => {
  const e1 = await seedEvent();
  await rejects(run(cancelEvent, e1.member, {sessionId: e1.id}), 'permission-denied');
  await rejects(run(cancelEvent, e1.a, {sessionId: e1.id}), 'permission-denied');
  await rejects(run(cancelEvent, null, {sessionId: e1.id}), 'unauthenticated');
  assert.equal(await exists(`liveSessions/${e1.id}`), true);

  await db.doc(`groups/g${n}/members/${e1.member}`).update({role: 'admin'});
  await run(cancelEvent, e1.member, {sessionId: e1.id});

  const e2 = await seedEvent();
  await db.doc(`liveSessions/${e2.id}`).update({creatorId: e2.member});
  await run(cancelEvent, e2.member, {sessionId: e2.id});

  const e3 = await seedEvent();
  await user('root', {superUser: true});
  await run(cancelEvent, 'root', {sessionId: e3.id});
});

await t('a started event cannot be cancelled', async () => {
  const {id, owner, a} = await seedEvent({hoursAhead: -1});
  await rejects(run(cancelEvent, owner, {sessionId: id}), 'failed-precondition', /empezó/);
  assert.equal(await credits(a), '20.00');
});

// ---- removePlayer ----
await t('remove player frees the seat, deletes the ticket, refunds in full', async () => {
  const {id, owner, a, b} = await seedEvent({hoursAhead: 2});
  assert.deepEqual(await run(removePlayer, owner, {sessionId: id, userId: a}),
    {refunded: true, amount: 10});
  assert.equal(await credits(a), '30.00');
  assert.equal(await credits(b), '20.00');
  const s = (await db.doc(`liveSessions/${id}`).get()).data();
  assert.deepEqual(s.players.map((p) => p.uid), [b]);
  assert.equal(s.playerCount, 1);
  assert.equal(await exists(`tickets/${id}_${a}`), false);
  await rejects(run(removePlayer, owner, {sessionId: id, userId: a}),
    'failed-precondition', /ya no está/);
});

await t('remove refuses a used ticket, a member caller and a started event', async () => {
  const {id, owner, a, member} = await seedEvent();
  await rejects(run(removePlayer, member, {sessionId: id, userId: a}), 'permission-denied');
  await db.doc(`tickets/${id}_${a}`).update({status: 'used'});
  await rejects(run(removePlayer, owner, {sessionId: id, userId: a}),
    'failed-precondition', /ya fue usado/);
  const e = await seedEvent({hoursAhead: -1});
  await rejects(run(removePlayer, e.owner, {sessionId: e.id, userId: e.a}),
    'failed-precondition', /empezó/);
  assert.equal(await credits(a), '20.00');
});

await t('remove on a free event refunds nothing', async () => {
  const {id, owner, a} = await seedEvent({cost: 0});
  assert.deepEqual(await run(removePlayer, owner, {sessionId: id, userId: a}),
    {refunded: false, amount: 0});
  assert.equal(await credits(a), '30.00');
});

const failed = results.filter(([, ok]) => !ok);
console.log(`\n${results.length - failed.length}/${results.length} passed`);
process.exit(failed.length ? 1 : 0);
