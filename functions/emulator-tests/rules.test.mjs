// Emulator test: firestore.rules (guests/publicEvents, ticket create/revive/validate, known open holes).
// Run: npm run test:emulator (from functions/).
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, deleteDoc, Timestamp} from 'firebase/firestore';

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
  await setDoc(doc(d, 'users/owner1'), {credits: '0.00'});
  await setDoc(doc(d, 'users/alice'), {credits: '5.00'});
});

const ts = () => Timestamp.now();
const ticket = (uid, extra = {}) => ({
  sessionId: 's1', groupId: 'g1', userId: uid, validationToken: 'tok-' + Math.random(), status: 'valid',
  createdAt: ts(), usedAt: null, validatedBy: null, eventTitle: 'P', eventDate: ts(), eventEndDate: ts(),
  eventLocationAddress: null, eventLocationLat: null, eventLocationLng: null, sport: 'fútbol',
  userFirstName: 'A', userLastName: 'B', userProfileImageUrl: null, ...extra,
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

// --- accepted pre-existing holes (should still be open; documenting, NOT regressions) ---
await t('[known hole] user can still edit own credits', () => assertSucceeds(updateDoc(doc(alice, 'users/alice'), {credits: '999.00'})));
await t('[known hole] any signed-in user can update any liveSession', () => assertSucceeds(updateDoc(doc(bob, 'liveSessions/s1'), {playerCount: 0})));

await env.cleanup();
const failed = results.filter((r) => !r).length;
console.log(`\nrules: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
