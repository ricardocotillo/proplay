// Emulator test: waitlist (join, offer on a freed seat, hold, confirm via
// joinSession, decline, expiry) and the late-cancel refund.
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
const {joinWaitlist, leaveWaitlist, expireOffers, cleanupEnded} = req(FN + '/lib/waitlistCallables.js');

const H = 3600 * 1000;
let n = 0;
const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}
const run = (fn, uid, data) => fn.run({
  auth: uid ? {uid, token: {}} : undefined, data, rawRequest: {}, acceptsStreaming: false,
});
const rejects = async (p, code, msg) => {
  try { await p; } catch (e) {
    assert.equal(e.code, code, `code ${e.code}: ${e.message}`);
    if (msg) assert.match(e.message, msg);
    return;
  }
  assert.fail('expected rejection ' + code);
};
const user = (uid, credits = '30.00') => db.doc(`users/${uid}`).set({
  credits, firstName: 'Ana', lastName: 'Pérez', profileImageUrl: null,
  documentType: 'dni', documentNumber: '12345678', superUser: false,
});
const credits = async (uid) => (await db.doc(`users/${uid}`).get()).data().credits;
const entry = async (id, uid) => (await db.doc(`liveSessions/${id}/waitlist/${uid}`).get()).data();
const session = async (id) => (await db.doc(`liveSessions/${id}`).get()).data();
const uids = async (id) => (await session(id)).players.map((p) => p.uid).sort();

/** A full event (2 seats, S/ 10) with players p1, p2 who joined for real. */
async function fullEvent({hoursAhead = 72, cost = 10} = {}) {
  const k = ++n;
  const id = `w${k}`, owner = `o${k}`, p1 = `p${k}a`, p2 = `p${k}b`, g = `g${k}`;
  await Promise.all([user(owner), user(p1), user(p2)]);
  await db.doc(`groups/${g}/members/${owner}`).set({role: 'owner'});
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: g, isPrivate: false, costPerPlayer: cost, maxPlayers: 2, sport: 'fútbol',
    creatorId: owner, eventDate: Timestamp.fromMillis(Date.now() + 72 * H),
    eventEndDate: Timestamp.fromMillis(Date.now() + 74 * H), players: [], playerCount: 0,
  });
  await run(joinSession, p1, {sessionId: id});
  await run(joinSession, p2, {sessionId: id});
  if (hoursAhead !== 72) {
    await db.doc(`liveSessions/${id}`).update({eventDate: Timestamp.fromMillis(Date.now() + hoursAhead * H)});
  }
  return {id, owner, p1, p2, g};
}
const waiter = async (id, credits = '30.00') => {
  const w = `ww${++n}`;
  await user(w, credits);
  await run(joinWaitlist, w, {sessionId: id});
  return w;
};

await t('join the waitlist of a full event; duplicate is idempotent; nothing is charged', async () => {
  const {id} = await fullEvent();
  const w = `ww${++n}`; await user(w);
  assert.deepEqual(await run(joinWaitlist, w, {sessionId: id}), {status: 'waiting'});
  assert.deepEqual(await run(joinWaitlist, w, {sessionId: id}), {status: 'already'});
  assert.equal((await entry(id, w)).status, 'waiting');
  assert.equal(await credits(w), '30.00');
});

await t('waitlist is refused when seats are free, no saldo, a player, started or private', async () => {
  const {id, g, p1} = await fullEvent();
  const free = `f${++n}`; await user(free);
  await db.doc(`liveSessions/${id}`).update({maxPlayers: 3});
  await rejects(run(joinWaitlist, free, {sessionId: id}), 'failed-precondition', /Aún hay cupos/);
  await db.doc(`liveSessions/${id}`).update({maxPlayers: 2});
  const poor = `pp${++n}`; await user(poor, '3.00');
  await rejects(run(joinWaitlist, poor, {sessionId: id}), 'failed-precondition', /saldo/);
  await rejects(run(joinWaitlist, p1, {sessionId: id}), 'failed-precondition', /ya estás inscrito/i);
  await rejects(run(joinWaitlist, null, {sessionId: id}), 'unauthenticated');
  const started = await fullEvent({hoursAhead: -1});
  const w = `st${++n}`; await user(w);
  await rejects(run(joinWaitlist, w, {sessionId: started.id}), 'failed-precondition', /empezó/);
  await db.doc(`liveSessions/${id}`).update({isPrivate: true});
  await rejects(run(joinWaitlist, w, {sessionId: id}), 'permission-denied');
  void g;
});

await t('a freed seat is held for the first in line; others cannot take it; confirming joins and pays', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id);
  const w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id});
  assert.equal((await entry(id, w1)).status, 'offered');
  assert.ok((await entry(id, w1)).offerExpiresAt.toMillis() - Date.now() > 25 * 60_000);
  assert.equal((await entry(id, w2)).status, 'waiting');
  const stranger = `sx${++n}`; await user(stranger);
  await rejects(run(joinSession, stranger, {sessionId: id}), 'failed-precondition', /lleno/);
  await rejects(run(joinSession, w2, {sessionId: id}), 'failed-precondition', /lleno/);
  const out = await run(joinSession, w1, {sessionId: id});
  assert.equal(out.alreadyJoined, false);
  assert.equal(await credits(w1), '20.00');
  assert.equal(await entry(id, w1), undefined);
  assert.equal((await session(id)).playerCount, 2);
  assert.ok((await uids(id)).includes(w1));
  assert.equal((await entry(id, w2)).status, 'waiting');
});

await t('declining an offer passes the seat to the next person', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id);
  const w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id});
  await run(leaveWaitlist, w1, {sessionId: id});
  assert.equal(await entry(id, w1), undefined);
  assert.equal((await entry(id, w2)).status, 'offered');
  assert.deepEqual(await run(leaveWaitlist, w1, {sessionId: id}), {left: true}); // idempotent
});

await t('leaving while only waiting changes nothing for the others', async () => {
  const {id} = await fullEvent();
  const w1 = await waiter(id);
  const w2 = await waiter(id);
  await run(leaveWaitlist, w2, {sessionId: id});
  assert.equal((await entry(id, w1)).status, 'waiting');
});

await t('an expired offer is dropped and the next person is offered the seat', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id);
  const w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id});
  await db.doc(`liveSessions/${id}/waitlist/${w1}`).update({offerExpiresAt: Timestamp.fromMillis(Date.now() - 1000)});
  // while expired but not yet swept, the seat is not held any more
  const out = await expireOffers(db, {sendEachForMulticast: async () => ({responses: []})}, Date.now());
  assert.ok(out.expired >= 1);
  assert.equal(await entry(id, w1), undefined);
  assert.equal((await entry(id, w2)).status, 'offered');
  assert.deepEqual(await expireOffers(db, {sendEachForMulticast: async () => ({responses: []})}, Date.now()).then((o) => o.expired), 0);
});

await t('organizer removal also offers the seat', async () => {
  const {id, owner, p1} = await fullEvent();
  const w1 = await waiter(id);
  await run(removePlayer, owner, {sessionId: id, userId: p1});
  assert.equal((await entry(id, w1)).status, 'offered');
});

await t('late cancel: no refund now, paid back when the waitlist fills the seat, once', async () => {
  const {id, p1} = await fullEvent({hoursAhead: 5});
  const w1 = await waiter(id);
  const out = await run(cancelParticipation, p1, {sessionId: id});
  assert.deepEqual(out, {refunded: false, amount: 0});
  assert.equal(await credits(p1), '20.00');
  const late = async (u) => (await db.collection(`liveSessions/${id}/lateCancels`).where('uid', '==', u).get()).docs.map((d) => d.data());
  assert.deepEqual((await late(p1)).map((r) => r.refunded), [false]);
  await run(joinSession, w1, {sessionId: id});
  assert.equal(await credits(p1), '30.00');
  assert.deepEqual((await late(p1)).map((r) => r.refunded), [true]);
  const refunds = await db.collection('creditHistory').where('userId', '==', p1).where('entryType', '==', 'refund').get();
  assert.equal(refunds.size, 1);
  // a later direct join does not refund anyone again
  await run(cancelParticipation, w1, {sessionId: id}); // also late
  const direct = `dj${++n}`; await user(direct);
  await run(joinSession, direct, {sessionId: id});
  assert.equal(await credits(p1), '30.00');
});

await t('late cancel with nobody on the waitlist stays non-refundable', async () => {
  const {id, p1} = await fullEvent({hoursAhead: 5});
  await run(cancelParticipation, p1, {sessionId: id});
  const direct = `dj${++n}`; await user(direct);
  await run(joinSession, direct, {sessionId: id});
  assert.equal(await credits(p1), '20.00');
});

await t('two late cancels are paid back oldest first, one per waitlist fill', async () => {
  const {id, p1, p2} = await fullEvent({hoursAhead: 5});
  const w1 = await waiter(id), w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id});
  await new Promise((r) => setTimeout(r, 20));
  await run(cancelParticipation, p2, {sessionId: id});
  await run(joinSession, w1, {sessionId: id});
  assert.equal(await credits(p1), '30.00');
  assert.equal(await credits(p2), '20.00');
  await run(joinSession, w2, {sessionId: id});
  assert.equal(await credits(p2), '30.00');
});

await t('cancel event ends the waitlist and pays back late cancellers', async () => {
  const {id, owner, p1, p2} = await fullEvent({hoursAhead: 5});
  const w1 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id}); // late, w1 now offered
  await run(cancelEvent, owner, {sessionId: id});
  assert.equal(await credits(p1), '30.00'); // late canceller paid back
  assert.equal(await credits(p2), '30.00'); // current player refunded
  assert.equal(await credits(w1), '30.00'); // never charged
  assert.equal((await db.collection(`liveSessions/${id}/waitlist`).get()).size, 0);
  assert.equal((await db.collection(`liveSessions/${id}/lateCancels`).get()).size, 0);
});

await t('cancel event: a late canceller who rejoined is refunded for both spends', async () => {
  const {id, owner, p1} = await fullEvent({hoursAhead: 5});
  const w1 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id}); // late: -10 kept
  await run(joinSession, w1, {sessionId: id}); // fills, p1 paid back (+10)
  assert.equal(await credits(p1), '30.00');
  await run(cancelEvent, owner, {sessionId: id});
  assert.equal(await credits(w1), '30.00');
});

const noPush = {sendEachForMulticast: async () => ({responses: []})};

await t('declining after the hold expired (before the sweep) still offers the next person', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id), w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id});
  await db.doc(`liveSessions/${id}/waitlist/${w1}`).update({offerExpiresAt: Timestamp.fromMillis(Date.now() - 1000)});
  await run(leaveWaitlist, w1, {sessionId: id});
  assert.equal(await entry(id, w1), undefined);
  assert.equal((await entry(id, w2)).status, 'offered');
});

await t('cancel late, rejoin, cancel late again: every cancel keeps its own row', async () => {
  const {id, p1} = await fullEvent({hoursAhead: 5});
  const w1 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id}); // late #1 (spend A), w1 offered
  await run(joinSession, w1, {sessionId: id}); // fill: p1 paid back for A
  assert.equal(await credits(p1), '30.00');
  await run(joinWaitlist, p1, {sessionId: id});
  await run(cancelParticipation, w1, {sessionId: id}); // late (w1's spend), p1 offered
  await run(joinSession, p1, {sessionId: id}); // fill: w1 paid back; p1 now has spend B
  assert.equal(await credits(w1), '30.00');
  await run(cancelParticipation, p1, {sessionId: id}); // late #2 of p1 (spend B), nobody waiting
  const rows = (await db.collection(`liveSessions/${id}/lateCancels`).get()).docs;
  assert.equal(rows.length, 3);
  assert.equal(rows.every((d) => d.id === d.data().spendId), true);
  assert.deepEqual(rows.filter((d) => d.data().uid === p1).map((d) => d.data().refunded).sort(), [false, true]);
});

await t('an offer skips people who can no longer pay and keeps their place', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id), w2 = await waiter(id);
  await db.doc(`users/${w1}`).update({credits: '2.00'});
  await run(cancelParticipation, p1, {sessionId: id});
  assert.equal((await entry(id, w1)).status, 'waiting');
  assert.equal((await entry(id, w2)).status, 'offered');
});

await t('no offer is made once the event has started', async () => {
  const {id, p1} = await fullEvent();
  const w1 = await waiter(id), w2 = await waiter(id);
  await run(cancelParticipation, p1, {sessionId: id}); // w1 offered
  await db.doc(`liveSessions/${id}`).update({eventDate: Timestamp.fromMillis(Date.now() - 1000)});
  await run(leaveWaitlist, w1, {sessionId: id});
  assert.equal((await entry(id, w2)).status, 'waiting');
});

await t('the waitlist is capped per event', async () => {
  const {id} = await fullEvent();
  const batch = db.batch();
  for (let i = 0; i < 50; i++) batch.set(db.doc(`liveSessions/${id}/waitlist/cap${i}`), {status: 'waiting', joinedAt: Timestamp.now()});
  await batch.commit();
  const w = `ww${++n}`; await user(w);
  await rejects(run(joinWaitlist, w, {sessionId: id}), 'failed-precondition', /llena/);
});

await t('cleanup removes waitlist and late-cancel rows of events that ended', async () => {
  const {id: past} = await fullEvent();
  const {id: future} = await fullEvent();
  await db.doc(`liveSessions/${past}`).update({eventDate: Timestamp.fromMillis(Date.now() - 2 * 3600_000)});
  await db.doc(`liveSessions/${past}/waitlist/x`).set({status: 'waiting', joinedAt: Timestamp.now()});
  await db.doc(`liveSessions/${past}/lateCancels/s1`).set({uid: 'u', spendId: 's1', refunded: false});
  await db.doc(`liveSessions/${future}/waitlist/y`).set({status: 'waiting', joinedAt: Timestamp.now()});
  assert.ok((await cleanupEnded(db, Date.now())) >= 2);
  assert.equal((await db.collection(`liveSessions/${past}/waitlist`).get()).size, 0);
  assert.equal((await db.collection(`liveSessions/${past}/lateCancels`).get()).size, 0);
  assert.equal((await db.collection(`liveSessions/${future}/waitlist`).get()).size, 1);
  void noPush;
});

const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
