// Emulator test: firestore.rules (guests/publicEvents, ticket create/revive/validate, identity-document rules, known open holes).
// Run: npm run test:emulator (from functions/).
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp, writeBatch, serverTimestamp} from 'firebase/firestore';

const RULES = fileURLToPath(new URL('../../firestore.rules', import.meta.url));
const env = await initializeTestEnvironment({
  projectId: 'demo-proplay-rules',
  firestore: {rules: fs.readFileSync(RULES, 'utf8'), host: '127.0.0.1', port: Number(process.env.FIRESTORE_EMULATOR_HOST?.split(':')[1] ?? 8085)},
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'groups/g1'), {name: 'G'});
  await setDoc(doc(d, 'groups/g1/members/owner1'), {role: 'owner'});
  await setDoc(doc(d, 'liveSessions/s1'), {groupId: 'g1', isPrivate: false, costPerPlayer: 10, players: [{uid: 'alice', firstName: 'Ana'}]});
  await setDoc(doc(d, 'liveSessions/priv'), {groupId: 'g1', isPrivate: true, costPerPlayer: 10});
  await setDoc(doc(d, 'publicEvents/s1'), {title: 'Pichanga', playerCount: 1});
  await setDoc(doc(d, 'liveSessions/legacy'), {groupId: 'g1', costPerPlayer: 10, playerCount: 0});
  await setDoc(doc(d, 'liveSessions/priv2'), {groupId: 'g1', isPrivate: true, costPerPlayer: 10});
  await setDoc(doc(d, 'groups/g1/members/admin1'), {role: 'admin'});
  await setDoc(doc(d, 'groups/g2'), {name: 'G2'});
  await setDoc(doc(d, 'groups/g2/members/mallory'), {role: 'owner'});
  await setDoc(doc(d, 'users/owner1'), {credits: '0.00'});
  await setDoc(doc(d, 'users/alice'), {credits: '5.00', documentType: 'dni', documentNumber: '12345678'});
  for (const u of ['bob','c1','c2','c3','c4','c5','c6','c7','c8','u9','u10','v1','v2','zed'])
    await setDoc(doc(d, 'users/' + u), {credits: '0.00', documentType: 'dni', documentNumber: '12345678'});
});

const ts = () => Timestamp.now();
const ticket = (uid, extra = {}) => ({
  sessionId: 's1', groupId: 'g1', userId: uid, validationToken: 'tok-' + Math.random(), status: 'valid',
  createdAt: ts(), usedAt: null, validatedBy: null, eventTitle: 'P', eventDate: ts(), eventEndDate: ts(),
  eventLocationAddress: null, eventLocationLat: null, eventLocationLng: null, sport: 'fútbol',
  userFirstName: 'A', userLastName: 'B', userProfileImageUrl: null, userDocumentType: 'dni', userDocumentNumber: '12345678', ...extra,
});

const anon = env.unauthenticatedContext().firestore();
const alice = env.authenticatedContext('alice').firestore();
const bob = env.authenticatedContext('bob').firestore();
const owner = env.authenticatedContext('owner1').firestore();
const as = (uid) => env.authenticatedContext(uid).firestore();

const results = [];
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', String(e.message).split('\n')[0]); }
}
const seedTicket = (id, data) => env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'tickets/' + id), data));

// --- publicEvents / guests ---
await t('guest CAN read publicEvents', () => assertSucceeds(getDoc(doc(anon, 'publicEvents/s1'))));
await t('guest cannot write publicEvents', () => assertFails(setDoc(doc(anon, 'publicEvents/x'), {a: 1})));
await t('signed-in cannot write publicEvents', () => assertFails(setDoc(doc(alice, 'publicEvents/x'), {a: 1})));
await t('signed-in cannot delete publicEvents', () => assertFails(deleteDoc(doc(alice, 'publicEvents/s1'))));
await t('guest CANNOT read liveSessions (players[] stays private)', () => assertFails(getDoc(doc(anon, 'liveSessions/s1'))));
await t('guest cannot read tickets', async () => { await seedTicket('s1_alice', ticket('alice')); await assertFails(getDoc(doc(anon, 'tickets/s1_alice'))); });
await t('guest cannot read users', () => assertFails(getDoc(doc(anon, 'users/alice'))));
await t('signed-in reads public liveSession (unchanged)', () => assertSucceeds(getDoc(doc(bob, 'liveSessions/s1'))));
await t('non-member cannot read private liveSession (unchanged)', () => assertFails(getDoc(doc(bob, 'liveSessions/priv'))));

// --- ticket create ---
await t('join: create ticket with pricePaid == cost', () => assertSucceeds(setDoc(doc(bob, 'tickets/s1_bob'), ticket('bob', {pricePaid: 10}))));
await t('join: create ticket with pricePaid < cost', () => assertSucceeds(setDoc(doc(as('c1'), 'tickets/s1_c1'), ticket('c1', {pricePaid: 4.5}))));
await t('join: create legacy ticket WITHOUT pricePaid (old app)', () => assertSucceeds(setDoc(doc(as('c2'), 'tickets/s1_c2'), ticket('c2'))));
await t('forged pricePaid 500 denied', () => assertFails(setDoc(doc(as('c3'), 'tickets/s1_c3'), ticket('c3', {pricePaid: 500}))));
await t('negative pricePaid denied', () => assertFails(setDoc(doc(as('c4'), 'tickets/s1_c4'), ticket('c4', {pricePaid: -1}))));
await t('string pricePaid denied', () => assertFails(setDoc(doc(as('c5'), 'tickets/s1_c5'), ticket('c5', {pricePaid: '5'}))));
await t('ticket with extra key cancelledAt denied', () => assertFails(setDoc(doc(as('c6'), 'tickets/s1_c6'), ticket('c6', {cancelledAt: ts()}))));
await t('ticket with extra key refunded denied', () => assertFails(setDoc(doc(as('c7'), 'tickets/s1_c7'), ticket('c7', {refunded: true}))));
await t('ticket as someone else denied', () => assertFails(setDoc(doc(bob, 'tickets/s1_zed'), ticket('zed'))));
await t('ticket with status used on create denied', () => assertFails(setDoc(doc(as('c8'), 'tickets/s1_c8'), ticket('c8', {status: 'used'}))));

// --- H1: revive / tamper ---
await seedTicket('s1_u9', {...ticket('u9'), status: 'used', usedAt: ts(), validatedBy: 'owner1'});
await t('H1: holder cannot revive a USED ticket', () => assertFails(setDoc(doc(as('u9'), 'tickets/s1_u9'), ticket('u9'))));
await seedTicket('s1_u10', ticket('u10', {pricePaid: 10}));
await t('holder can re-issue own still-valid ticket (rejoin after admin removal)', () => assertSucceeds(setDoc(doc(as('u10'), 'tickets/s1_u10'), ticket('u10', {pricePaid: 10}))));
await t('holder cannot mark own ticket cancelled', () => assertFails(updateDoc(doc(as('u10'), 'tickets/s1_u10'), {status: 'cancelled'})));
await t('holder cannot delete own ticket (function does it)', () => assertFails(deleteDoc(doc(as('u10'), 'tickets/s1_u10'))));
await t('after function deletes ticket, holder can create a fresh one (rejoin)', async () => {
  await env.withSecurityRulesDisabled((c) => deleteDoc(doc(c.firestore(), 'tickets/s1_u10')));
  await assertSucceeds(setDoc(doc(as('u10'), 'tickets/s1_u10'), ticket('u10', {pricePaid: 10})));
});

// --- validation ---
await seedTicket('s1_v1', ticket('v1'));
await t('group owner validates: valid -> used', () => assertSucceeds(updateDoc(doc(owner, 'tickets/s1_v1'), {status: 'used', usedAt: ts(), validatedBy: 'owner1'})));
await seedTicket('s1_v2', ticket('v2'));
await t('random user cannot validate a ticket', () => assertFails(updateDoc(doc(bob, 'tickets/s1_v2'), {status: 'used', usedAt: ts(), validatedBy: 'bob'})));
await t('owner cannot set status cancelled', () => assertFails(updateDoc(doc(owner, 'tickets/s1_v2'), {status: 'cancelled'})));
await t('other user cannot read someone else ticket', () => assertFails(getDoc(doc(bob, 'tickets/s1_v2'))));


// --- isPrivate / groupId hardening on liveSessions ---
const mallory = env.authenticatedContext('mallory').firestore(); // owner of ANOTHER group (g2)
const admin1 = env.authenticatedContext('admin1').firestore();   // admin (not owner) of g1
await t('non-owner cannot make a private event public', () => assertFails(updateDoc(doc(bob, 'liveSessions/priv'), {isPrivate: false})));
await t('non-owner cannot make a public event private', () => assertFails(updateDoc(doc(bob, 'liveSessions/s1'), {isPrivate: true})));
await t('owner of ANOTHER group cannot flip isPrivate', () => assertFails(updateDoc(doc(mallory, 'liveSessions/priv'), {isPrivate: false})));
await t('group admin (not owner) cannot flip isPrivate', () => assertFails(updateDoc(doc(admin1, 'liveSessions/priv'), {isPrivate: false})));
await t('bypass step 1: non-owner cannot re-point groupId to a group they own', () => assertFails(updateDoc(doc(mallory, 'liveSessions/priv2'), {groupId: 'g2'})));
await t('bypass in one write: re-point groupId AND flip isPrivate denied', () => assertFails(updateDoc(doc(mallory, 'liveSessions/priv2'), {groupId: 'g2', isPrivate: false})));
await t('nobody can change groupId, not even the group owner', () => assertFails(updateDoc(doc(owner, 'liveSessions/priv2'), {groupId: 'g2'})));
await t('group owner CAN flip isPrivate', () => assertSucceeds(updateDoc(doc(owner, 'liveSessions/priv2'), {isPrivate: false})));
await t('join-style update (players + playerCount) on a private event still works for a non-owner', () => assertSucceeds(updateDoc(doc(bob, 'liveSessions/priv'), {players: [{uid: 'bob'}], playerCount: 1})));
await t('join-style update on a public event still works', () => assertSucceeds(updateDoc(doc(bob, 'liveSessions/s1'), {players: [{uid: 'bob'}], playerCount: 1})));
await t('legacy doc without isPrivate: join-style update still works', () => assertSucceeds(updateDoc(doc(bob, 'liveSessions/legacy'), {playerCount: 1})));
await t('legacy doc without isPrivate: a non-owner cannot ADD isPrivate:false', () => assertFails(updateDoc(doc(bob, 'liveSessions/legacy'), {isPrivate: false})));
await t('owner can still create a session for their group', () => assertSucceeds(setDoc(doc(owner, 'liveSessions/new1'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5})));
await t('non-owner cannot create a session for a group they do not own', () => assertFails(setDoc(doc(bob, 'liveSessions/new2'), {groupId: 'g1', isPrivate: false})));

// --- accepted pre-existing holes (should still be open; documenting, NOT regressions) ---
await t('[known hole] user can still edit own credits', () => assertSucceeds(updateDoc(doc(alice, 'users/alice'), {credits: '999.00'})));
await t('[known hole] any signed-in user can still update players/playerCount/title of any liveSession', () => assertSucceeds(updateDoc(doc(bob, 'liveSessions/s1'), {playerCount: 0})));


// --- identity-document rules from the other task must still hold in the merged file ---
const newUser = (n) => ({credits: '0.00', superUser: false, documentType: 'dni', documentNumber: n, firstName: 'N'});
await t('[theirs] register: users doc + documents lock in one batch', async () => {
  const db = as('reg1'); const b = writeBatch(db);
  b.set(doc(db, 'users/reg1'), newUser('11111111'));
  b.set(doc(db, 'documents/dni_11111111'), {uid: 'reg1', createdAt: serverTimestamp()});
  await assertSucceeds(b.commit());
});
await t('[theirs] register without the documents lock denied', () => assertFails(setDoc(doc(as('reg2'), 'users/reg2'), newUser('22222222'))));
await t('[theirs] register with credits 50.00 denied', async () => {
  const db = as('reg3'); const b = writeBatch(db);
  b.set(doc(db, 'users/reg3'), {...newUser('33333333'), credits: '50.00'});
  b.set(doc(db, 'documents/dni_33333333'), {uid: 'reg3', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});
await t('[theirs] register as superUser denied', async () => {
  const db = as('reg4'); const b = writeBatch(db);
  b.set(doc(db, 'users/reg4'), {...newUser('44444444'), superUser: true});
  b.set(doc(db, 'documents/dni_44444444'), {uid: 'reg4', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});
await t('[theirs] user cannot change own document number', () => assertFails(updateDoc(doc(alice, 'users/alice'), {documentNumber: '99999999'})));
await t('[theirs] documents collection cannot be listed or deleted by clients', () => assertFails(deleteDoc(doc(alice, 'documents/dni_11111111'))));
await t('[theirs] ticket with FORGED document snapshot denied', () => assertFails(setDoc(doc(as('v1'), 'tickets/s1_v1b'), ticket('v1', {userDocumentNumber: '00000000'}))));
await t('[COMPAT] ticket WITHOUT userDocument* (our current client) denied for a user who has a document', async () => {
  const t0 = ticket('bob'); delete t0.userDocumentType; delete t0.userDocumentNumber; delete t0.pricePaid;
  await assertFails(setDoc(doc(bob, 'tickets/s1_bob_nodoc'), t0));
});

await env.cleanup();
const failed = results.filter((r) => !r).length;
console.log(`\nrules: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
