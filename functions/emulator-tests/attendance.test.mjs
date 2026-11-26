// Emulator test: runAttendance (no-shows), the join block and the forgive path.
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
const {joinWaitlist} = req(FN + '/lib/waitlistCallables.js');
const {runAttendance, forgiveNoShow, retractAttendance} = req(FN + '/lib/attendance.js');

const H = 3600 * 1000, D = 24 * H;
let n = 0;
const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}
const run = (fn, uid, data) => fn.run({auth: {uid, token: {}}, data, rawRequest: {}, acceptsStreaming: false});
const user = (uid) => db.doc(`users/${uid}`).set({
  credits: '30.00', firstName: 'Ana', lastName: 'Pérez', profileImageUrl: null,
  documentType: 'dni', documentNumber: '12345678', superUser: false,
});
const sender = () => {
  const sent = [];
  return {sent, async sendEachForMulticast(m) { sent.push(m); return {responses: m.tokens.map(() => ({success: true}))}; }};
};
const enable = (uid) => db.doc(`users/${uid}/fcmTokens/${uid}-t`).set({createdAt: Timestamp.now(), platform: 'web', token: `${uid}-t`});
const noShows = async (uid) => (await db.collection(`users/${uid}/noShows`).get()).size;
const blockedUntil = async (uid) => (await db.doc(`users/${uid}`).get()).data().blockedUntil?.toMillis();

/** An event that ended `endedHoursAgo` hours ago, tickets: `used` for the first, `valid` for the others. */
async function ended({endedHoursAgo = 8, used = 1, valid = 2} = {}) {
  const id = `a${++n}`;
  await db.doc(`liveSessions/${id}`).set({
    title: 'Pichanga', groupId: 'g', isPrivate: false, costPerPlayer: 10, maxPlayers: 20, players: [], playerCount: 0,
    eventDate: Timestamp.fromMillis(Date.now() - (endedHoursAgo + 2) * H),
    eventEndDate: Timestamp.fromMillis(Date.now() - endedHoursAgo * H),
  });
  const present = [], absent = [];
  for (let i = 0; i < used + valid; i++) {
    const u = `u${n}x${i}`; await user(u); await enable(u);
    const isUsed = i < used;
    await db.doc(`tickets/${id}_${u}`).set({sessionId: id, userId: u, status: isUsed ? 'used' : 'valid'});
    (isUsed ? present : absent).push(u);
  }
  return {id, present, absent};
}

await t('players who never showed are recorded when attendance was taken; present ones are not', async () => {
  const {present, absent} = await ended();
  const out = await runAttendance(db, sender(), Date.now());
  assert.ok(out.recorded >= 2);
  for (const u of absent) assert.equal(await noShows(u), 1);
  for (const u of present) assert.equal(await noShows(u), 0);
});

await t('an event where nobody was checked in records nothing', async () => {
  const {absent} = await ended({used: 0, valid: 3});
  await runAttendance(db, sender(), Date.now());
  for (const u of absent) assert.equal(await noShows(u), 0);
});

await t('events outside the 6 to 48 h window are skipped', async () => {
  const recent = await ended({endedHoursAgo: 3});
  const old = await ended({endedHoursAgo: 60});
  await runAttendance(db, sender(), Date.now());
  assert.equal(await noShows(recent.absent[0]), 0);
  assert.equal(await noShows(old.absent[0]), 0);
});

await t('running twice records once and warns once', async () => {
  const {absent} = await ended({used: 1, valid: 1});
  // the 2nd no-show of this user warns: give them one old one first
  const u = absent[0];
  await db.doc(`users/${u}/noShows/old1`).set({eventId: 'old1', at: Timestamp.fromMillis(Date.now() - 10 * D)});
  const s = sender();
  await runAttendance(db, s, Date.now());
  await runAttendance(db, s, Date.now());
  assert.equal(await noShows(u), 2);
  const warns = s.sent.filter((m) => m.tokens.includes(`${u}-t`) && /2 ausencias/.test(m.notification.body));
  assert.equal(warns.length, 1);
  assert.equal(await blockedUntil(u), undefined);
});

await t('the 3rd no-show in 90 days blocks joining for 14 days, with a push', async () => {
  const {absent, id} = await ended({used: 1, valid: 1});
  const u = absent[0];
  for (const k of ['p1', 'p2']) await db.doc(`users/${u}/noShows/${k}`).set({eventId: k, at: Timestamp.fromMillis(Date.now() - 20 * D)});
  const s = sender();
  const out = await runAttendance(db, s, Date.now());
  assert.ok(out.blocked >= 1);
  const until = await blockedUntil(u);
  assert.ok(Math.abs(until - (Date.now() + 14 * D)) < 60_000);
  assert.ok(s.sent.some((m) => m.tokens.includes(`${u}-t`) && /3 ausencias/.test(m.notification.body)));
  // the block is enforced on join and on the waitlist
  await db.doc(`liveSessions/open${id}`).set({
    title: 'Otro', groupId: 'g', isPrivate: false, costPerPlayer: 10, maxPlayers: 5, players: [], playerCount: 0,
    eventDate: Timestamp.fromMillis(Date.now() + 5 * D), eventEndDate: Timestamp.fromMillis(Date.now() + 5 * D + 2 * H),
  });
  for (const fn of [joinSession, joinWaitlist]) {
    try { await run(fn, u, {sessionId: `open${id}`}); assert.fail('expected block'); } catch (e) {
      assert.equal(e.code, 'failed-precondition');
      assert.match(e.message, /No puedes unirte a nuevos eventos hasta el/);
    }
  }
});

await t('no-shows older than 90 days do not count', async () => {
  const {absent} = await ended({used: 1, valid: 1});
  const u = absent[0];
  for (const k of ['o1', 'o2', 'o3']) await db.doc(`users/${u}/noShows/${k}`).set({eventId: k, at: Timestamp.fromMillis(Date.now() - 100 * D)});
  await runAttendance(db, sender(), Date.now());
  assert.equal(await blockedUntil(u), undefined);
});

await t('an expired block lets the user join again', async () => {
  const u = `exp${++n}`; await user(u);
  await db.doc(`users/${u}`).update({blockedUntil: Timestamp.fromMillis(Date.now() - H)});
  await db.doc(`liveSessions/ok${n}`).set({
    title: 'Libre', groupId: 'g', isPrivate: false, costPerPlayer: 10, maxPlayers: 5, players: [], playerCount: 0,
    eventDate: Timestamp.fromMillis(Date.now() + 5 * D), eventEndDate: Timestamp.fromMillis(Date.now() + 5 * D + 2 * H),
  });
  assert.equal((await run(joinSession, u, {sessionId: `ok${n}`})).alreadyJoined, false);
});

await t('marking someone present afterwards forgives that no-show and lifts the block below 3', async () => {
  const {absent, id} = await ended({used: 1, valid: 1});
  const u = absent[0];
  for (const k of ['p1', 'p2']) await db.doc(`users/${u}/noShows/${k}`).set({eventId: k, at: Timestamp.fromMillis(Date.now() - 20 * D)});
  await runAttendance(db, sender(), Date.now());
  assert.ok(await blockedUntil(u));
  assert.equal(await forgiveNoShow(db, u, id, Date.now()), true);
  assert.equal(await noShows(u), 2);
  assert.equal(await blockedUntil(u), undefined);
  assert.equal(await forgiveNoShow(db, u, id, Date.now()), false); // nothing left to forgive
});

await t('a retry after a crash repairs a missing block once, without extending it', async () => {
  const {absent, id} = await ended({used: 1, valid: 1});
  const u = absent[0];
  for (const k of ['r1', 'r2']) await db.doc(`users/${u}/noShows/${k}`).set({eventId: k, at: Timestamp.fromMillis(Date.now() - 5 * D)});
  await db.doc(`users/${u}/noShows/${id}`).set({eventId: id, at: Timestamp.now()}); // recorded, block lost
  const s = sender();
  await runAttendance(db, s, Date.now());
  const first = await blockedUntil(u);
  assert.ok(first);
  await runAttendance(db, s, Date.now() + H);
  assert.equal(await blockedUntil(u), first);
});

await t('a deleted user doc does not abort the rest of the event', async () => {
  const {absent} = await ended({used: 1, valid: 2});
  for (const k of ['d1', 'd2']) await db.doc(`users/${absent[0]}/noShows/${k}`).set({eventId: k, at: Timestamp.fromMillis(Date.now() - 5 * D)});
  await db.doc(`users/${absent[0]}`).delete();
  await runAttendance(db, sender(), Date.now());
  assert.equal(await noShows(absent[1]), 1);
});

await t('undoing the last check-in forgives the whole event', async () => {
  const {present, absent, id} = await ended({used: 1, valid: 2});
  await runAttendance(db, sender(), Date.now());
  for (const u of absent) assert.equal(await noShows(u), 1);
  assert.equal(await retractAttendance(db, id, Date.now()), 0); // someone is still checked in
  await db.doc(`tickets/${id}_${present[0]}`).update({status: 'valid'});
  assert.equal(await retractAttendance(db, id, Date.now()), 2);
  for (const u of absent) assert.equal(await noShows(u), 0);
  await runAttendance(db, sender(), Date.now()); // nobody checked in: still nothing recorded
  for (const u of absent) assert.equal(await noShows(u), 0);
});

await t('forgive then re-record does not warn or block-notify twice', async () => {
  const {absent, id} = await ended({used: 1, valid: 1});
  const u = absent[0];
  await db.doc(`users/${u}/noShows/w1`).set({eventId: 'w1', at: Timestamp.fromMillis(Date.now() - 5 * D)});
  const s = sender();
  await runAttendance(db, s, Date.now());
  const mine = () => s.sent.filter((m) => m.tokens.includes(`${u}-t`)).length;
  assert.equal(mine(), 1); // 2nd absence: warning
  await forgiveNoShow(db, u, id, Date.now());
  await runAttendance(db, s, Date.now());
  assert.equal(await noShows(u), 2); // recorded again
  assert.equal(mine(), 1); // same event, same player: no second push
});

const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
