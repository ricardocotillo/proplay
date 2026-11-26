// Emulator test: runAutoCancel (events short of their minimum, 24 h mark).
// Run: npm run test:emulator (from functions/).
import {createRequire} from 'node:module';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';

const FN = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const req = createRequire(FN + '/package.json');
const {initializeApp} = req('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = req('firebase-admin/firestore');
initializeApp({projectId: 'demo-proplay'});
const db = getFirestore();
const {joinSession} = req(FN + '/lib/joinSession.js');
const {cancelParticipation} = req(FN + '/lib/cancelParticipation.js');
const {joinWaitlist} = req(FN + '/lib/waitlistCallables.js');
const {runAutoCancel} = req(FN + '/lib/minPlayers.js');

const H = 3600 * 1000;
let n = 0;
const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}
const run = (fn, uid, data) => fn.run({auth: {uid, token: {}}, data, rawRequest: {}, acceptsStreaming: false});
const user = (uid, credits = '30.00') => db.doc(`users/${uid}`).set({
  credits, firstName: 'Ana', lastName: 'Pérez', profileImageUrl: null,
  documentType: 'dni', documentNumber: '12345678', superUser: false,
});
const credits = async (uid) => (await db.doc(`users/${uid}`).get()).data().credits;
const exists = async (path) => (await db.doc(path).get()).exists;

/** Sender that records pushes; every user has one device. */
const sender = () => {
  const sent = [];
  return {sent, async sendEachForMulticast(m) { sent.push(m); return {responses: m.tokens.map(() => ({success: true}))}; }};
};
const enable = (uid) => db.doc(`users/${uid}/fcmTokens/${uid}-t`).set({createdAt: Timestamp.now(), platform: 'web', token: `${uid}-t`});

/** Event 23.5 h away (inside the check window), `joined` real players, minimum `min`. */
async function seed({min = 4, joined = 2, hours = 23.5, maxPlayers = 10} = {}) {
  const k = ++n;
  const id = `m${k}`, owner = `o${k}`;
  await user(owner); await enable(owner);
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: `g${k}`, isPrivate: false, costPerPlayer: 10, maxPlayers, minPlayers: min,
    sport: 'fútbol', creatorId: owner,
    eventDate: Timestamp.fromMillis(Date.now() + 72 * H), eventEndDate: Timestamp.fromMillis(Date.now() + 74 * H),
    players: [], playerCount: 0,
  });
  const ps = [];
  for (let i = 0; i < joined; i++) {
    const p = `p${k}x${i}`; await user(p); await enable(p);
    await run(joinSession, p, {sessionId: id}); ps.push(p);
  }
  await db.doc(`liveSessions/${id}`).update({eventDate: Timestamp.fromMillis(Date.now() + hours * H)});
  return {id, owner, ps};
}

await t('an underfilled event is cancelled: everyone refunded, tickets gone, all told', async () => {
  const {id, owner, ps} = await seed({min: 4, joined: 2});
  const s = sender();
  assert.ok((await runAutoCancel(db, s, Date.now())).cancelled >= 1);
  assert.equal(await exists(`liveSessions/${id}`), false);
  for (const p of ps) {
    assert.equal(await credits(p), '30.00');
    assert.equal(await exists(`tickets/${id}_${p}`), false);
  }
  const bodies = s.sent.map((m) => m.notification.body);
  assert.ok(bodies.some((b) => /mínimo de 4 jugadores.*S\/ 10\.00/.test(b)));
  const toOwner = s.sent.filter((m) => m.tokens.includes(`${owner}-t`));
  assert.equal(toOwner.length, 1);
  assert.match(toOwner[0].notification.title, /Cancelamos tu evento/);
  // ledger says why
  const refunds = await db.collection('creditHistory').where('userId', '==', ps[0]).where('entryType', '==', 'refund').get();
  assert.match(refunds.docs[0].data().notes, /falta de jugadores/);
});

await t('an event that reached its minimum stays', async () => {
  const {id} = await seed({min: 2, joined: 2});
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${id}`), true);
});

await t('events without a minimum, or with an invalid one, are never auto-cancelled', async () => {
  const a = await seed({min: 4, joined: 1});
  await db.doc(`liveSessions/${a.id}`).update({minPlayers: 1});
  const b = await seed({min: 4, joined: 1});
  await db.doc(`liveSessions/${b.id}`).update({minPlayers: FieldValue.delete()});
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${a.id}`), true);
  assert.equal(await exists(`liveSessions/${b.id}`), true);
});

await t('only the two hours after the 24 h mark are checked', async () => {
  const early = await seed({min: 4, joined: 1, hours: 30});
  const late = await seed({min: 4, joined: 1, hours: 12});
  const inside = await seed({min: 4, joined: 1, hours: 22.5});
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${early.id}`), true);
  assert.equal(await exists(`liveSessions/${late.id}`), true);
  assert.equal(await exists(`liveSessions/${inside.id}`), false);
});

await t('running twice cancels once and pushes once', async () => {
  const {id, ps} = await seed({min: 4, joined: 1});
  const s = sender();
  await runAutoCancel(db, s, Date.now());
  const first = s.sent.length;
  await runAutoCancel(db, s, Date.now());
  assert.equal(s.sent.length, first);
  assert.equal(await credits(ps[0]), '30.00');
  assert.equal(await exists(`liveSessions/${id}`), false);
});

await t('a join between the query and the cancel wins (re-checked inside the transaction)', async () => {
  const {id} = await seed({min: 3, joined: 2});
  const late = `late${++n}`; await user(late);
  await run(joinSession, late, {sessionId: id}); // now 3 of 3
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${id}`), true);
});

await t('waitlisted people are told, never charged; late cancellers are paid back', async () => {
  const {id, ps} = await seed({min: 4, joined: 4, maxPlayers: 4, hours: 72});
  const w = `w${++n}`; await user(w); await enable(w);
  await run(joinWaitlist, w, {sessionId: id});
  await run(cancelParticipation, ps[0], {sessionId: id}); // early: refunded, w offered
  await db.doc(`liveSessions/${id}`).update({eventDate: Timestamp.fromMillis(Date.now() + 23.5 * H)});
  await run(cancelParticipation, ps[1], {sessionId: id}); // late: no refund, still counted
  assert.equal(await credits(ps[1]), '20.00');
  const s = sender();
  await runAutoCancel(db, s, Date.now()); // 2 players + 1 late = 3 < 4
  assert.equal(await exists(`liveSessions/${id}`), false);
  assert.equal(await credits(ps[1]), '30.00'); // late canceller paid back
  assert.equal(await credits(ps[2]), '30.00');
  assert.equal(await credits(ps[3]), '30.00');
  assert.equal(await credits(w), '30.00');
  assert.ok(s.sent.some((m) => m.tokens.includes(`${w}-t`) && /No se te cobró nada/.test(m.notification.body)));
  assert.equal((await db.collection(`liveSessions/${id}/waitlist`).get()).size, 0);
});

await t('a player cannot force the cancel by leaving inside the window', async () => {
  const {id, ps} = await seed({min: 3, joined: 3});
  await run(cancelParticipation, ps[0], {sessionId: id}); // late cancel: no refund, now 2 players + 1 late
  assert.equal(await credits(ps[0]), '20.00');
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${id}`), true); // still counted: the event plays
  assert.equal(await credits(ps[0]), '20.00'); // and the leaver is not refunded
});

await t('a late cancel replaced from the waitlist stops counting', async () => {
  const {id, ps} = await seed({min: 3, joined: 3, maxPlayers: 3});
  const w = `w${++n}`; await user(w);
  await run(joinWaitlist, w, {sessionId: id});
  await run(cancelParticipation, ps[0], {sessionId: id}); // late, w offered
  await run(joinSession, w, {sessionId: id}); // fill: ps[0] paid back, row refunded
  assert.equal(await credits(ps[0]), '30.00');
  await runAutoCancel(db, sender(), Date.now()); // 3 players again: stays
  assert.equal(await exists(`liveSessions/${id}`), true);
});

await t('a minimum above the maximum is ignored by the server', async () => {
  const {id} = await seed({min: 4, joined: 1, maxPlayers: 10});
  await db.doc(`liveSessions/${id}`).update({minPlayers: 50});
  await runAutoCancel(db, sender(), Date.now());
  assert.equal(await exists(`liveSessions/${id}`), true);
});

await t('the creator who is also a player gets one message, the organizer one', async () => {
  const {id, owner} = await seed({min: 4, joined: 0});
  await run(joinSession, owner, {sessionId: id});
  const s = sender();
  await runAutoCancel(db, s, Date.now());
  const mine = s.sent.filter((m) => m.tokens.includes(`${owner}-t`));
  assert.equal(mine.length, 1);
  assert.match(mine[0].notification.title, /Cancelamos tu evento/);
  assert.equal(await credits(owner), '30.00');
  void id;
});

const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
