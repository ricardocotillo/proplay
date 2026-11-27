// Emulator test: changeDocument (compiled callable's .run against the Firestore emulator).
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
const {changeDocument} = req(FN + '/lib/changeDocument.js');

const D = 24 * 3600 * 1000;
let n = 0;
const results = [];

const run = (fn, uid, data) => fn.run({
  auth: uid ? {uid, token: {}} : undefined, data, rawRequest: {}, acceptsStreaming: false,
});
const change = (uid, type, number) => run(changeDocument, uid, {documentType: type, documentNumber: number});
const rejects = async (p, code, msg) => {
  try { await p; } catch (e) {
    assert.equal(e.code, code, `code ${e.code}: ${e.message}`);
    if (msg) assert.match(e.message, msg);
    return;
  }
  assert.fail('expected rejection ' + code);
};
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}

/** A fresh 8-digit number per call. */
const num = () => String(10000000 + ++n);
/** A user with a document and its lock. */
async function user(extra = {}) {
  const uid = `cd${++n}`;
  const number = num();
  await db.doc(`users/${uid}`).set({
    credits: '0.00', firstName: 'Ana', lastName: 'Pérez', superUser: false,
    documentType: 'dni', documentNumber: number, ...extra,
  });
  await db.doc(`documents/dni_${number}`).set({uid, createdAt: Timestamp.now()});
  return {uid, number};
}
const getUser = async (uid) => (await db.doc(`users/${uid}`).get()).data();
const lock = async (key) => (await db.doc(`documents/${key}`).get());

await t('success: lock swapped, profile updated, cooldown stamped', async () => {
  const {uid, number} = await user();
  const next = num();
  const out = await change(uid, 'dni', next);
  assert.deepEqual(out, {documentType: 'dni', documentNumber: next});
  assert.equal((await lock(`dni_${number}`)).exists, false);
  assert.equal((await lock(`dni_${next}`)).get('uid'), uid);
  const u = await getUser(uid);
  assert.equal(u.documentNumber, next);
  assert.ok(u.documentChangedAt);
});

await t('a second change inside 30 days is refused; nothing changes', async () => {
  const {uid} = await user();
  const a = num(), b = num();
  await change(uid, 'dni', a);
  await rejects(change(uid, 'dni', b), 'failed-precondition', /30 días/);
  assert.equal((await getUser(uid)).documentNumber, a);
  assert.equal((await lock(`dni_${b}`)).exists, false);
});

await t('cooldown boundary: 29 days refused, 31 days allowed', async () => {
  const {uid} = await user({documentChangedAt: Timestamp.fromMillis(Date.now() - 29 * D)});
  await rejects(change(uid, 'dni', num()), 'failed-precondition', /30 días/);
  await db.doc(`users/${uid}`).update({documentChangedAt: Timestamp.fromMillis(Date.now() - 31 * D)});
  const next = num();
  await change(uid, 'dni', next);
  assert.equal((await getUser(uid)).documentNumber, next);
});

await t('a number owned by another account is refused with the support contact', async () => {
  const {uid, number} = await user();
  const other = await user();
  await rejects(change(uid, 'dni', other.number), 'failed-precondition', /ricardo@cotillo\.dev/);
  const u = await getUser(uid);
  assert.equal(u.documentNumber, number);
  assert.equal(u.documentChangedAt, undefined);
  assert.equal((await lock(`dni_${number}`)).get('uid'), uid);
  assert.equal((await lock(`dni_${other.number}`)).get('uid'), other.uid);
});

await t('same document as the current one is refused', async () => {
  const {uid, number} = await user();
  await rejects(change(uid, 'dni', number), 'failed-precondition', /ya es tu documento/);
});

await t('a legacy account without a document is refused', async () => {
  const uid = `cd${++n}`;
  await db.doc(`users/${uid}`).set({credits: '0.00', documentType: '', documentNumber: ''});
  await rejects(change(uid, 'dni', num()), 'failed-precondition', /registra tu documento/);
});

await t('bad input and missing auth', async () => {
  const {uid} = await user();
  await rejects(change(uid, 'dni', '1234'), 'invalid-argument');
  await rejects(change(uid, 'passport', 'X12345678'), 'invalid-argument');
  await rejects(run(changeDocument, uid, {documentType: 'dni'}), 'invalid-argument');
  await rejects(change(undefined, 'dni', num()), 'unauthenticated');
});

await t('lowercase CE is normalized; DNI to CE swaps the lock key', async () => {
  const {uid, number} = await user();
  await change(uid, 'ce', 'ab1234567');
  const u = await getUser(uid);
  assert.equal(u.documentType, 'ce');
  assert.equal(u.documentNumber, 'AB1234567');
  assert.equal((await lock('ce_AB1234567')).get('uid'), uid);
  assert.equal((await lock(`dni_${number}`)).exists, false);
});

await t('tickets issued before the change keep the old document', async () => {
  const {uid, number} = await user();
  await db.doc(`tickets/s_${uid}`).set({
    sessionId: 's', userId: uid, status: 'valid', userDocumentType: 'dni', userDocumentNumber: number,
  });
  await change(uid, 'dni', num());
  assert.equal((await db.doc(`tickets/s_${uid}`).get()).get('userDocumentNumber'), number);
});

await t('a missing old lock does not block the change', async () => {
  const {uid, number} = await user();
  await db.doc(`documents/dni_${number}`).delete();
  const next = num();
  await change(uid, 'dni', next);
  assert.equal((await lock(`dni_${next}`)).get('uid'), uid);
});

await t('race: two users change to the same number, one wins', async () => {
  const a = await user(), b = await user();
  const target = num();
  const res = await Promise.allSettled([change(a.uid, 'dni', target), change(b.uid, 'dni', target)]);
  assert.equal(res.filter((r) => r.status === 'fulfilled').length, 1);
  const lost = res.find((r) => r.status === 'rejected');
  assert.equal(lost.reason.code, 'failed-precondition');
  const winner = res[0].status === 'fulfilled' ? a.uid : b.uid;
  assert.equal((await lock(`dni_${target}`)).get('uid'), winner);
});

await t('the old number is claimable by someone else after the change', async () => {
  const {uid, number} = await user();
  const other = await user();
  await change(uid, 'dni', num());
  await change(other.uid, 'dni', number);
  assert.equal((await lock(`dni_${number}`)).get('uid'), other.uid);
});

const failed = results.filter((r) => !r).length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
