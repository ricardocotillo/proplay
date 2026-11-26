// Emulator test: runReminders / sendToUser / claim with a fake push sender.
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
const {runReminders} = req(FN + '/lib/reminders.js');
const {sendToUser, claim} = req(FN + '/lib/notify.js');

const H = 3600 * 1000;
let n = 0;
const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}

/** Fake Messaging: records sends; tokens listed in `dead` fail as unregistered. */
const fakeSender = (dead = []) => {
  const sent = [];
  return {
    sent,
    async sendEachForMulticast(m) {
      sent.push(m);
      return {responses: m.tokens.map((tk) => dead.includes(tk)
        ? {success: false, error: {code: 'messaging/registration-token-not-registered'}}
        : {success: true})};
    },
  };
};

async function seedEvent(hoursAhead, players) {
  const id = `r${++n}`;
  await db.doc(`liveSessions/${id}`).set({
    title: 'Fútbol 7', groupId: 'g', isPrivate: false,
    eventDate: Timestamp.fromMillis(Date.now() + hoursAhead * H),
    players: players.map((uid) => ({uid})), playerCount: players.length,
  });
  return id;
}
const enable = (uid, token) => db.doc(`users/${uid}/fcmTokens/${token}`).set({createdAt: Timestamp.now()});
const user = () => `ru${++n}`;

await t('2 h reminder reaches every device of every player, once', async () => {
  const a = user(), b = user(), c = user();
  await enable(a, `${a}-t1`); await enable(a, `${a}-t2`); await enable(b, `${b}-t1`);
  await enable(c, `${c}-t1`); // not a player
  const id = await seedEvent(1.5, [a, b]);
  const s = fakeSender();
  const out = await runReminders(db, s, Date.now());
  assert.ok(out.events >= 1);
  const mine = s.sent.filter((m) => m.data.path === `/events/${id}`);
  assert.equal(mine.length, 2); // one multicast per player with tokens
  const tokens = mine.flatMap((m) => m.tokens).sort();
  assert.deepEqual(tokens, [`${a}-t1`, `${a}-t2`, `${b}-t1`].sort());
  assert.match(mine[0].notification.title, /empieza pronto/);
  // second run: already claimed
  const s2 = fakeSender();
  await runReminders(db, s2, Date.now());
  assert.equal(s2.sent.filter((m) => m.data.path === `/events/${id}`).length, 0);
});

await t('free-cancel reminder fires in the hour before the deadline, not earlier or later', async () => {
  const a = user();
  await enable(a, `${a}-t1`);
  const due = await seedEvent(24.5, [a]);
  const early = await seedEvent(24.9 + 0.2, [a]); // 25.1 h: outside the query window
  const late = await seedEvent(23, [a]); // past the deadline, only the 2 h rule could apply
  const s = fakeSender();
  await runReminders(db, s, Date.now());
  const paths = s.sent.map((m) => m.data.path);
  assert.ok(paths.includes(`/events/${due}`));
  assert.ok(!paths.includes(`/events/${early}`));
  assert.ok(!paths.includes(`/events/${late}`));
  const dueMsg = s.sent.find((m) => m.data.path === `/events/${due}`);
  assert.match(dueMsg.notification.title, /cancelar gratis/);
});

await t('events with no players, started events and users without tokens send nothing', async () => {
  const a = user();
  const empty = await seedEvent(1, []);
  const past = await seedEvent(-1, [a]);
  const noTok = await seedEvent(1, [a]);
  const s = fakeSender();
  const out = await runReminders(db, s, Date.now());
  assert.ok(!s.sent.some((m) => m.data.path === `/events/${empty}`));
  assert.ok(!s.sent.some((m) => m.data.path === `/events/${past}`));
  assert.ok(!s.sent.some((m) => m.data.path === `/events/${noTok}`));
  assert.ok(out.events >= 1); // noTok was claimed (sent nowhere)
});

await t('dead tokens are deleted, live ones kept', async () => {
  const a = user();
  await enable(a, 'good'); await enable(a, 'dead');
  const ok = await sendToUser(db, fakeSender(['dead']), a, {title: 't', body: 'b', path: '/x'});
  assert.equal(ok, 1);
  const left = (await db.collection(`users/${a}/fcmTokens`).get()).docs.map((d) => d.id);
  assert.deepEqual(left, ['good']);
});

await t('claim succeeds once per id', async () => {
  const id = `claim_${++n}`;
  assert.equal(await claim(db, id), true);
  assert.equal(await claim(db, id), false);
});

const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
