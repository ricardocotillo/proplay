// Emulator test: firestore.rules (guests/publicEvents, ticket create/revive/validate, identity-document rules, known open holes).
// Run: npm run test:emulator (from functions/).
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {collection, query, where, getDocs, doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField, Timestamp, writeBatch, serverTimestamp} from 'firebase/firestore';

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
  const rich = {groupId: 'g1', isPrivate: false, title: 'Pichanga', costPerPlayer: 10, maxPlayers: 10, playerCount: 0, players: [],
    locationLat: -12.1, locationLng: -77.0, locationAddress: 'Av. X', district: 'Miraflores', format: '5v5', sport: 'fútbol', status: 'OPEN'};
  for (const id of ['f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11'])
    await setDoc(doc(d, 'liveSessions/' + id), rich);
  for (const id of ['del1', 'del2', 'del3', 'del4', 'del5'])
    await setDoc(doc(d, 'liveSessions/' + id), rich);
  await setDoc(doc(d, 'groups/g2'), {name: 'G2'});
  await setDoc(doc(d, 'groups/g2/members/mallory'), {role: 'owner'});
  await setDoc(doc(d, 'users/owner1'), {credits: '0.00'});
  // legacy accounts (no document) + an owner of a claimed document
  for (const u of ['legacy1', 'legacy2', 'legacy3', 'legacy4', 'legacy5', 'legacy6', 'legacy7'])
    await setDoc(doc(d, 'users/' + u), {credits: '0.00', firstName: 'L'});
  await setDoc(doc(d, 'users/docowner'), {credits: '0.00', documentType: 'dni', documentNumber: '55555555'});
  await setDoc(doc(d, 'documents/dni_55555555'), {uid: 'docowner', createdAt: Timestamp.now()});
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

// --- tickets are server-written (joinSession / cancel / organizer functions) ---
await t('holder cannot create a ticket (join is the joinSession function)', () => assertFails(setDoc(doc(bob, 'tickets/s1_bob'), ticket('bob', {pricePaid: 10}))));
await t('legacy ticket without pricePaid (old app) denied', () => assertFails(setDoc(doc(as('c2'), 'tickets/s1_c2'), ticket('c2'))));
await t('ticket as someone else denied', () => assertFails(setDoc(doc(bob, 'tickets/s1_zed'), ticket('zed'))));
await seedTicket('s1_u9', {...ticket('u9'), status: 'used', usedAt: ts(), validatedBy: 'owner1'});
await t('H1: holder cannot revive a USED ticket', () => assertFails(setDoc(doc(as('u9'), 'tickets/s1_u9'), ticket('u9'))));
await seedTicket('s1_u10', ticket('u10', {pricePaid: 10}));
await t('holder cannot re-issue own valid ticket', () => assertFails(setDoc(doc(as('u10'), 'tickets/s1_u10'), ticket('u10', {pricePaid: 10}))));
await t('holder cannot mark own ticket cancelled', () => assertFails(updateDoc(doc(as('u10'), 'tickets/s1_u10'), {status: 'cancelled'})));
await t('holder cannot delete own ticket (function does it)', () => assertFails(deleteDoc(doc(as('u10'), 'tickets/s1_u10'))));

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
await t('client join-style update on a private event denied', () => assertFails(updateDoc(doc(bob, 'liveSessions/priv'), {players: [{uid: 'bob'}], playerCount: 1})));
await t('client join-style update on a public event denied', () => assertFails(updateDoc(doc(bob, 'liveSessions/s1'), {players: [{uid: 'bob'}], playerCount: 1})));
await t('legacy doc: client playerCount update denied', () => assertFails(updateDoc(doc(bob, 'liveSessions/legacy'), {playerCount: 1})));
await t('legacy doc without isPrivate: a non-owner cannot ADD isPrivate:false', () => assertFails(updateDoc(doc(bob, 'liveSessions/legacy'), {isPrivate: false})));
await t('owner can still create a session for their group', () => assertSucceeds(setDoc(doc(owner, 'liveSessions/new1'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 10})));
await t('owner creates 8 weekly events in one batch', () => {
  const b = writeBatch(owner);
  for (let i = 0; i < 8; i++) b.set(doc(owner, 'liveSessions/wk' + i), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 10});
  return assertSucceeds(b.commit());
});
await t('non-owner cannot create a session for a group they do not own', () => assertFails(setDoc(doc(bob, 'liveSessions/new2'), {groupId: 'g1', isPrivate: false})));


// --- non-owners cannot edit public-facing fields (title, place, price...) ---
const fieldAttempts = {
  title: {title: 'HACKED'}, locationLat: {locationLat: 0}, locationAddress: {locationAddress: 'elsewhere'},
  costPerPlayer: {costPerPlayer: 0}, maxPlayers: {maxPlayers: 1}, district: {district: 'Callao'},
  format: {format: 'x'}, status: {status: 'CLOSED'}, sport: {sport: 'tenis'}, newField: {injected: true},
};
for (const [name, patch] of Object.entries(fieldAttempts))
  await t('non-owner cannot change ' + name, () => assertFails(updateDoc(doc(bob, 'liveSessions/f1'), patch)));
await t('non-owner cannot smuggle a title change inside a join-style write', () => assertFails(updateDoc(doc(bob, 'liveSessions/f1'), {players: [{uid: 'bob'}], playerCount: 1, title: 'HACKED'})));
await t('owner of another group cannot change the title', () => assertFails(updateDoc(doc(mallory, 'liveSessions/f1'), {title: 'HACKED'})));
await t('group admin (not owner) cannot change the title', () => assertFails(updateDoc(doc(admin1, 'liveSessions/f1'), {title: 'HACKED'})));
await t('group admin cannot remove a player from the client (removePlayer refunds)', () => assertFails(updateDoc(doc(admin1, 'liveSessions/f2'), {players: [], playerCount: 0})));
await t('client players + playerCount write denied', () => assertFails(updateDoc(doc(bob, 'liveSessions/f3'), {players: [{uid: 'bob', firstName: 'B'}], playerCount: 1})));
await t('client players-only write denied', () => assertFails(updateDoc(doc(bob, 'liveSessions/f4'), {players: [{uid: 'bob', receiptUrl: 'r', isConfirmed: true}]})));
await t('owner CAN change title', () => assertSucceeds(updateDoc(doc(owner, 'liveSessions/f5'), {title: 'Nuevo titulo'})));
await t('owner CAN change location and price', () => assertSucceeds(updateDoc(doc(owner, 'liveSessions/f6'), {locationLat: -12.2, locationAddress: 'Av. Y', costPerPlayer: 12})));
await t('owner still cannot change groupId', () => assertFails(updateDoc(doc(owner, 'liveSessions/f7'), {groupId: 'g2'})));

// --- delete: only owner/admin of the session's group ---
await t('random signed-in user cannot delete a session', () => assertFails(deleteDoc(doc(bob, 'liveSessions/del1'))));
await t('owner of ANOTHER group cannot delete a session', () => assertFails(deleteDoc(doc(mallory, 'liveSessions/del1'))));
await t('guest cannot delete a session', () => assertFails(deleteDoc(doc(anon, 'liveSessions/del1'))));
await t('group admin cannot delete a session (cancelEvent refunds)', () => assertFails(deleteDoc(doc(admin1, 'liveSessions/del2'))));
await t('group owner cannot delete a session (cancelEvent refunds)', () => assertFails(deleteDoc(doc(owner, 'liveSessions/del3'))));

// --- accepted pre-existing holes (should still be open; documenting, NOT regressions) ---
await t('user cannot edit own credits', () => assertFails(updateDoc(doc(alice, 'users/alice'), {credits: '999.00'})));
await t('nobody can write playerCount from the client', () => assertFails(updateDoc(doc(bob, 'liveSessions/s1'), {playerCount: 0})));


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

// --- documentChangedAt (30-day document cooldown) is written only by changeDocument ---
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'users/changer'), {credits: '0.00', documentType: 'dni', documentNumber: '77777771', documentChangedAt: Timestamp.now()});
  await setDoc(doc(d, 'users/fresh'), {credits: '0.00', documentType: 'dni', documentNumber: '77777772'});
});
await t('[cooldown] client cannot change documentChangedAt', () => assertFails(updateDoc(doc(as('changer'), 'users/changer'), {documentChangedAt: Timestamp.fromMillis(0)})));
await t('[cooldown] client cannot delete documentChangedAt to skip the 30 days', () => assertFails(updateDoc(doc(as('changer'), 'users/changer'), {documentChangedAt: deleteField()})));
await t('[cooldown] client cannot add documentChangedAt', () => assertFails(updateDoc(doc(as('fresh'), 'users/fresh'), {documentChangedAt: Timestamp.now()})));
await t('[cooldown] register with documentChangedAt denied', async () => {
  const db = as('reg5'); const b = writeBatch(db);
  b.set(doc(db, 'users/reg5'), {...newUser('55555551'), documentChangedAt: Timestamp.now()});
  b.set(doc(db, 'documents/dni_55555551'), {uid: 'reg5', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});
await t('[cooldown] a normal profile update leaves the field alone and succeeds', () => assertSucceeds(updateDoc(doc(as('changer'), 'users/changer'), {firstName: 'Ana'})));
await t('[theirs] ticket with FORGED document snapshot denied', () => assertFails(setDoc(doc(as('v1'), 'tickets/s1_v1b'), ticket('v1', {userDocumentNumber: '00000000'}))));
await t('[COMPAT] ticket WITHOUT userDocument* (our current client) denied for a user who has a document', async () => {
  const t0 = ticket('bob'); delete t0.userDocumentType; delete t0.userDocumentNumber; delete t0.pricePaid;
  await assertFails(setDoc(doc(bob, 'tickets/s1_bob_nodoc'), t0));
});

// --- superUser and group roles (forgeable before: self-promotion) ---
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'users/root'), {credits: '0.00', superUser: true});
  await setDoc(doc(d, 'users/plain'), {credits: '0.00', superUser: false});
  await setDoc(doc(d, 'groups/g3'), {name: 'G3', createdBy: 'carol'});
  await setDoc(doc(d, 'groups/g3/members/carol'), {role: 'owner'});
  await setDoc(doc(d, 'groups/g3/members/mem1'), {role: 'member'});
  await setDoc(doc(d, 'groups/g3/members/mem2'), {role: 'member'});
});
const carol = as('carol');
await t('user cannot make themselves superUser', () => assertFails(updateDoc(doc(as('plain'), 'users/plain'), {superUser: true})));
await t('legacy user without the field cannot add superUser: true', () => assertFails(updateDoc(doc(bob, 'users/bob'), {superUser: true})));
await t('legacy user may write superUser: false (profile save)', () => assertSucceeds(updateDoc(doc(as('c8'), 'users/c8'), {superUser: false, firstName: 'X'})));
await t('user keeps editing profile with superUser unchanged', () => assertSucceeds(updateDoc(doc(as('plain'), 'users/plain'), {superUser: false, firstName: 'Y'})));
await t('superUser can grant superUser', () => assertSucceeds(updateDoc(doc(as('root'), 'users/plain'), {superUser: true})));
await t('join by code: own member doc as member', () => assertSucceeds(setDoc(doc(as('j1'), 'groups/g3/members/j1'), {role: 'member', joinedAt: serverTimestamp()})));
await t('cannot join as admin', () => assertFails(setDoc(doc(as('j2'), 'groups/g3/members/j2'), {role: 'admin'})));
await t('cannot claim owner of a group you did not create', () => assertFails(setDoc(doc(as('j3'), 'groups/g3/members/j3'), {role: 'owner'})));
await t('cannot add someone else as member', () => assertFails(setDoc(doc(bob, 'groups/g3/members/zed'), {role: 'member'})));
await t('create group: creator claims owner', async () => {
  await assertSucceeds(setDoc(doc(as('nina'), 'groups/g4'), {name: 'G4', createdBy: 'nina'}));
  await assertSucceeds(setDoc(doc(as('nina'), 'groups/g4/members/nina'), {role: 'owner'}));
});
await t('cannot create a group in someone else\'s name', () => assertFails(setDoc(doc(bob, 'groups/g5'), {name: 'G5', createdBy: 'carol'})));
await t('member cannot rewrite createdBy', () => assertFails(updateDoc(doc(as('mem1'), 'groups/g3'), {createdBy: 'mem1'})));
await t('member can still edit group name', () => assertSucceeds(updateDoc(doc(as('mem1'), 'groups/g3'), {name: 'G3b'})));
await t('member cannot promote themselves', () => assertFails(updateDoc(doc(as('mem1'), 'groups/g3/members/mem1'), {role: 'owner'})));
await t('leave then re-claim owner is denied', async () => {
  await assertSucceeds(deleteDoc(doc(as('mem2'), 'groups/g3/members/mem2')));
  await assertFails(setDoc(doc(as('mem2'), 'groups/g3/members/mem2'), {role: 'owner'}));
});
await t('owner promotes a member to admin', () => assertSucceeds(updateDoc(doc(carol, 'groups/g3/members/mem1'), {role: 'admin'})));
await t('owner cannot set an unknown role', () => assertFails(updateDoc(doc(carol, 'groups/g3/members/mem1'), {role: 'god'})));
await t('non-owner cannot remove another member', () => assertFails(deleteDoc(doc(as('j1'), 'groups/g3/members/mem1'))));
await t('owner removes a member', () => assertSucceeds(deleteDoc(doc(carol, 'groups/g3/members/j1'))));
// --- creditHistory review (old builds approve from the client) ---
await env.withSecurityRulesDisabled(async (ctx) => {
  const d = ctx.firestore();
  await setDoc(doc(d, 'users/su1'), {credits: '0.00', superUser: true});
  await setDoc(doc(d, 'creditHistory/pend1'), {userId: 'alice', status: 'pending', entryType: 'purchase', creditAmount: 20, amountPaid: 21});
  await setDoc(doc(d, 'creditHistory/done1'), {userId: 'alice', status: 'approved', entryType: 'purchase', creditAmount: 20, amountPaid: 21});
});
await t('client approve of a pending row denied (reviewCreditPurchase only)', () => assertFails(updateDoc(doc(as('su1'), 'creditHistory/pend1'), {status: 'approved'})));
await t('old-build approve of an already-reviewed row denied (no double credit)', () => assertFails(updateDoc(doc(as('su1'), 'creditHistory/done1'), {status: 'approved'})));
await t('non-superUser cannot approve own pending row', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'creditHistory/pend2'), {userId: 'alice', status: 'pending', entryType: 'purchase', creditAmount: 20}));
  await assertFails(updateDoc(doc(alice, 'creditHistory/pend2'), {status: 'approved'}));
});

await t('non-owner cannot inflate playerCount', () => assertFails(updateDoc(doc(bob, 'liveSessions/f8'), {players: [], playerCount: 999})));
await t('non-owner cannot remove other players', () => assertFails(updateDoc(doc(bob, 'liveSessions/f9'), {players: [], playerCount: 0})));

// --- PR 5: seats, price, ledger, credits locked ---
await t('owner cannot write players directly', () => assertFails(updateDoc(doc(owner, 'liveSessions/f10'), {players: [{uid: 'x'}], playerCount: 1})));
await t('owner cannot create a session with players', () => assertFails(setDoc(doc(owner, 'liveSessions/new3'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, players: [{uid: 'x'}], playerCount: 1})));
await t('owner cannot create a session as someone else', () => assertFails(setDoc(doc(owner, 'liveSessions/new4'), {groupId: 'g1', costPerPlayer: 5, creatorId: 'zed'})));
await t('owner cannot change creatorId', () => assertFails(updateDoc(doc(owner, 'liveSessions/f11'), {creatorId: 'zed'})));
await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'liveSessions/paid1'), {groupId: 'g1', isPrivate: false, costPerPlayer: 10, playerCount: 2, players: [{uid: 'a'}, {uid: 'b'}]}));
await t('owner cannot lower the price once players joined (refund cap)', () => assertFails(updateDoc(doc(owner, 'liveSessions/paid1'), {costPerPlayer: 0})));
await t('owner cannot raise the price with players either (refund cap)', () => assertFails(updateDoc(doc(owner, 'liveSessions/paid1'), {costPerPlayer: 12})));
await t('owner still edits other fields with players', () => assertSucceeds(updateDoc(doc(owner, 'liveSessions/paid1'), {title: 'Nuevo'})));
await t('owner can lower the price with no players', () => assertSucceeds(updateDoc(doc(owner, 'liveSessions/f6'), {costPerPlayer: 1})));
const purchase = (extra = {}) => ({userId: 'alice', creditAmount: 15, amountPaid: 17, currency: 'PEN', createdAt: serverTimestamp(),
  status: 'pending', entryType: 'purchase', direction: 'credit', sourceType: 'payment', sourceId: null,
  transactionId: null, paymentMethod: 'yape', paymentGateway: 'yape', confirmationCode: '123456', ...extra});
await t('user can open own pending Yape top-up', () => assertSucceeds(setDoc(doc(alice, 'creditHistory/p_ok'), purchase())));
await t('forged spend row denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_spend'), purchase({entryType: 'spend', status: 'completed'}))));
await t('self-approved top-up denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_appr'), purchase({status: 'approved'}))));
await t('top-up worth more than paid denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_big'), purchase({creditAmount: 1000}))));
await t('top-up with refundedAt denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_ref'), purchase({refundedAt: ts()}))));
await t('top-up for someone else denied', () => assertFails(setDoc(doc(bob, 'creditHistory/p_other'), purchase())));
await t('user cannot edit own ledger row', () => assertFails(updateDoc(doc(alice, 'creditHistory/p_ok'), {creditAmount: 50})));
await t('superUser cannot edit a user balance from the client', () => assertFails(updateDoc(doc(as('root'), 'users/alice'), {credits: '100.00'})));
await t('user still edits profile fields', () => assertSucceeds(updateDoc(doc(alice, 'users/alice'), {firstName: 'Ana B'})));

// --- review gaps (PR #29) ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'liveSessions/legacyPlayers'), {groupId: 'g1', costPerPlayer: 10, players: [{uid: 'a'}]});
  await setDoc(doc(d, 'users/rich'), {credits: '50.00', documentType: 'dni', documentNumber: '12345678'});
});
await t('legacy doc with players but no playerCount: price frozen', () => assertFails(updateDoc(doc(owner, 'liveSessions/legacyPlayers'), {costPerPlayer: 0})));
await t('deleting costPerPlayer with players denied', () => assertFails(updateDoc(doc(owner, 'liveSessions/paid1'), {costPerPlayer: deleteField()})));
await t('deleting a non-zero credits field denied', () => assertFails(updateDoc(doc(as('rich'), 'users/rich'), {credits: deleteField()})));
await t('creditHistory delete denied, even own row', () => assertFails(deleteDoc(doc(alice, 'creditHistory/p_ok'))));
await t('top-up at a refund_ id denied (would block a refund)', () => assertFails(setDoc(doc(alice, 'creditHistory/refund_spend_s1_bob_tok'), purchase({creditAmount: 1, amountPaid: 1}))));
await t('top-up at a spend_ id denied', () => assertFails(setDoc(doc(alice, 'creditHistory/spend_s1_alice_tok'), purchase())));
await t('top-up with string amountPaid denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_str'), purchase({amountPaid: '17'}))));
await t('top-up without amountPaid denied', async () => {
  const p0 = purchase(); delete p0.amountPaid;
  await assertFails(setDoc(doc(alice, 'creditHistory/p_nopaid'), p0));
});
await t('top-up dated in the future denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_future'), purchase({createdAt: Timestamp.fromMillis(Date.now() + 86400000)}))));
await t('top-up as a debit denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_debit'), purchase({direction: 'debit'}))));
await t('top-up in another currency denied', () => assertFails(setDoc(doc(alice, 'creditHistory/p_usd'), purchase({currency: 'USD'}))));
await seedTicket('s1_v3', ticket('v3'));
await t('staff validation still works under the lock', () => assertSucceeds(updateDoc(doc(owner, 'tickets/s1_v3'), {status: 'used', usedAt: ts(), validatedBy: 'owner1'})));

// --- "De tus grupos" query: events of the groups the user belongs to ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'groups/gq1/members/qmember'), {role: 'member'});
  await setDoc(doc(d, 'liveSessions/gq_priv'), {groupId: 'gq1', isPrivate: true, eventDate: Timestamp.fromMillis(Date.now() + 1e7)});
  await setDoc(doc(d, 'liveSessions/gq_other'), {groupId: 'gq2', isPrivate: true, eventDate: Timestamp.fromMillis(Date.now() + 1e7)});
});
const groupEvents = (uid, ids) => getDocs(query(collection(as(uid), 'liveSessions'), where('groupId', 'in', ids), where('eventDate', '>=', Timestamp.now())));
await t('member can query upcoming events of their own groups (incl. private)', () => assertSucceeds(groupEvents('qmember', ['gq1'])));
await t('querying a group the user is not in is denied', () => assertFails(groupEvents('qmember', ['gq1', 'gq2'])));

// --- event creator reads their own event even outside the group ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'liveSessions/cr_priv'), {groupId: 'gcr', isPrivate: true, creatorId: 'ex-member', costPerPlayer: 5});
});
await t('creator reads their private event without group membership', () => assertSucceeds(getDoc(doc(as('ex-member'), 'liveSessions/cr_priv'))));
await t('a stranger still cannot read that private event', () => assertFails(getDoc(doc(as('stranger'), 'liveSessions/cr_priv'))));

// --- event creator manages tickets like an owner/admin ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'groups/gt1'), {name: 'GT', createdBy: 'gowner'});
  await setDoc(doc(d, 'groups/gt1/members/gowner'), {role: 'owner'});
  await setDoc(doc(d, 'groups/gt1/members/creator'), {role: 'member'});
  await setDoc(doc(d, 'groups/gt1/members/plainm'), {role: 'member'});
  await setDoc(doc(d, 'liveSessions/gt_s'), {groupId: 'gt1', isPrivate: false, costPerPlayer: 5, creatorId: 'creator', players: [], playerCount: 0});
  await setDoc(doc(d, 'tickets/gt_s_p1'), {...ticket('p1'), sessionId: 'gt_s', groupId: 'gt1'});
  await setDoc(doc(d, 'tickets/gt_s_p2'), {...ticket('p2'), sessionId: 'gt_s', groupId: 'gt1'});
});
const roster = (uid) => getDocs(query(collection(as(uid), 'tickets'), where('sessionId', '==', 'gt_s'), where('groupId', '==', 'gt1')));
await t('group owner reads the event roster tickets (query)', () => assertSucceeds(roster('gowner')));
await t('event creator (plain member) reads the event roster tickets (query)', () => assertSucceeds(roster('creator')));
await t('a plain member cannot read the roster tickets', () => assertFails(roster('plainm')));
// The QR scan: a token-only query can't be proven safe for an organizer (rules are not filters),
// so the QR carries the ticket id and the scanner reads that one document.
await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'tickets/gt_s_p3'), {...ticket('p3'), sessionId: 'gt_s', groupId: 'gt1', validationToken: 'qr-tok'}));
await t('[QR] organizer token-only query is denied (old QR lookup)', () => assertFails(getDocs(query(collection(as('gowner'), 'tickets'), where('validationToken', '==', 'qr-tok')))));
await t('[QR] group owner reads the scanned ticket by id', () => assertSucceeds(getDoc(doc(as('gowner'), 'tickets/gt_s_p3'))));
await t('[QR] event creator reads the scanned ticket by id', () => assertSucceeds(getDoc(doc(as('creator'), 'tickets/gt_s_p3'))));
await t('[QR] a plain member cannot read the scanned ticket by id', () => assertFails(getDoc(doc(as('plainm'), 'tickets/gt_s_p3'))));
await t('event creator validates a valid ticket', () => assertSucceeds(updateDoc(doc(as('creator'), 'tickets/gt_s_p1'), {status: 'used', usedAt: ts(), validatedBy: 'creator'})));
await t('a plain member cannot validate', () => assertFails(updateDoc(doc(as('plainm'), 'tickets/gt_s_p2'), {status: 'used', usedAt: ts(), validatedBy: 'plainm'})));
await t('the creator cannot undo a check-in from the client (checkInPlayer does)', () => assertFails(updateDoc(doc(as('creator'), 'tickets/gt_s_p1'), {status: 'valid', usedAt: null, validatedBy: null})));

// --- web push tokens ---
await t('user registers their own push token', () => assertSucceeds(setDoc(doc(alice, 'users/alice/fcmTokens/tok1'), {createdAt: serverTimestamp(), platform: 'web', token: 'tok1'})));
await t('user lists and removes their own tokens', async () => {
  await assertSucceeds(getDoc(doc(alice, 'users/alice/fcmTokens/tok1')));
  await assertSucceeds(deleteDoc(doc(alice, 'users/alice/fcmTokens/tok1')));
});
await t('nobody registers or reads a token on someone else', async () => {
  await assertFails(setDoc(doc(bob, 'users/alice/fcmTokens/tok2'), {createdAt: serverTimestamp(), platform: 'web', token: 'tok2'}));
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'users/alice/fcmTokens/tok3'), {createdAt: Timestamp.now(), platform: 'web'}));
  await assertFails(getDoc(doc(bob, 'users/alice/fcmTokens/tok3')));
  await assertFails(deleteDoc(doc(bob, 'users/alice/fcmTokens/tok3')));
});
await t('token doc with extra fields or a bad platform is denied', async () => {
  await assertFails(setDoc(doc(alice, 'users/alice/fcmTokens/tok4'), {createdAt: serverTimestamp(), platform: 'web', token: 'tok4', admin: true}));
  await assertFails(setDoc(doc(alice, 'users/alice/fcmTokens/tok5'), {createdAt: serverTimestamp(), platform: 'fax', token: 'tok5'}));
});
await t('token field must equal the doc id', () => assertFails(setDoc(doc(alice, 'users/alice/fcmTokens/tok6'), {createdAt: serverTimestamp(), platform: 'web', token: 'someone-elses'})));
await t('notificationsSent is server-only', async () => {
  await assertFails(setDoc(doc(alice, 'notificationsSent/two_hours_s1'), {at: serverTimestamp()}));
  await assertFails(getDoc(doc(alice, 'notificationsSent/two_hours_s1')));
});

// --- waitlist ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'liveSessions/wl_s/waitlist/alice'), {status: 'offered', joinedAt: Timestamp.now()});
  await setDoc(doc(d, 'liveSessions/wl_s/waitlist/bob'), {status: 'waiting', joinedAt: Timestamp.now()});
  await setDoc(doc(d, 'liveSessions/wl_s/lateCancels/zed'), {spendId: 'x', refunded: false});
});
await t('a user reads only their own waitlist entry', async () => {
  await assertSucceeds(getDoc(doc(alice, 'liveSessions/wl_s/waitlist/alice')));
  await assertFails(getDoc(doc(alice, 'liveSessions/wl_s/waitlist/bob')));
  await assertFails(getDoc(doc(anon, 'liveSessions/wl_s/waitlist/alice')));
});
await t('nobody lists the waitlist from the client', () => assertFails(getDocs(collection(alice, 'liveSessions/wl_s/waitlist'))));
await t('waitlist writes are server-only (join, accept, jump the queue)', async () => {
  await assertFails(setDoc(doc(bob, 'liveSessions/wl_s/waitlist/bob2'), {status: 'waiting', joinedAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(alice, 'liveSessions/wl_s/waitlist/alice'), {status: 'offered', offerExpiresAt: Timestamp.fromMillis(Date.now() + 1e9)}));
  await assertFails(deleteDoc(doc(alice, 'liveSessions/wl_s/waitlist/alice')));
});
await t('lateCancels is server-only', async () => {
  await assertFails(getDoc(doc(as('zed'), 'liveSessions/wl_s/lateCancels/zed')));
  await assertFails(setDoc(doc(alice, 'liveSessions/wl_s/lateCancels/alice'), {spendId: 'x', refunded: false}));
});

// --- event limits: date/min frozen with players, maximum capped ---
const T0 = Timestamp.fromMillis(Date.now() + 72 * 3600 * 1000);
const T1 = Timestamp.fromMillis(Date.now() + 96 * 3600 * 1000);
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  const base = {groupId: 'g1', isPrivate: false, title: 'E', costPerPlayer: 10, maxPlayers: 10, eventDate: T0, eventEndDate: T0};
  await setDoc(doc(d, 'liveSessions/lim_seats'), {...base, minPlayers: 4, players: [{uid: 'a'}], playerCount: 1});
  await setDoc(doc(d, 'liveSessions/lim_empty'), {...base, minPlayers: 4, players: [], playerCount: 0});
  await setDoc(doc(d, 'liveSessions/lim_nomin'), {...base, players: [{uid: 'a'}], playerCount: 1});
  await setDoc(doc(d, 'liveSessions/lim_legacy'), {...base, maxPlayers: 500, players: [], playerCount: 0});
});
const evt = (id) => doc(owner, 'liveSessions/' + id);
await t('owner cannot move the date once someone joined', async () => {
  await assertFails(updateDoc(evt('lim_seats'), {eventDate: T1}));
  await assertFails(updateDoc(evt('lim_seats'), {eventEndDate: T1}));
});
await t('owner can still move the date of an event with no players', () => assertSucceeds(updateDoc(evt('lim_empty'), {eventDate: T1, eventEndDate: T1})));
await t('with players the owner still edits title and place', () => assertSucceeds(updateDoc(evt('lim_seats'), {title: 'Nuevo', locationAddress: 'Av. Z'})));
await t('minimum can be lowered or removed after people joined, never raised', async () => {
  await assertFails(updateDoc(evt('lim_seats'), {minPlayers: 8}));
  await assertFails(updateDoc(evt('lim_nomin'), {minPlayers: 3}));
  await assertSucceeds(updateDoc(evt('lim_seats'), {minPlayers: 2}));
  await assertSucceeds(updateDoc(evt('lim_seats'), {minPlayers: deleteField()}));
});
await t('minimum is free to change on an event with no players', () => assertSucceeds(updateDoc(evt('lim_empty'), {minPlayers: 9})));
await t('maximum is capped at 60 on create and update', async () => {
  await assertSucceeds(setDoc(doc(owner, 'liveSessions/lim_new60'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 60}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_new61'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 61}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_new0'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 0}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_newstr'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: '20'}));
  await assertFails(updateDoc(evt('lim_empty'), {maxPlayers: 61}));
  await assertSucceeds(updateDoc(evt('lim_empty'), {maxPlayers: 60}));
});
await t('maximum cannot drop below the people who joined', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'liveSessions/lim_three'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 10, eventDate: T0, players: [{uid: 'a'}, {uid: 'b'}, {uid: 'c'}], playerCount: 3}));
  await assertFails(updateDoc(evt('lim_three'), {maxPlayers: 2}));
  await assertSucceeds(updateDoc(evt('lim_three'), {maxPlayers: 3}));
});
await t('create needs a maximum and a valid minimum', async () => {
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_nomax'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5}));
  const ok = {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 10};
  await assertSucceeds(setDoc(doc(owner, 'liveSessions/lim_min_ok'), {...ok, minPlayers: 4}));
  await assertSucceeds(setDoc(doc(owner, 'liveSessions/lim_min_eq'), {...ok, minPlayers: 10}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_min1'), {...ok, minPlayers: 1}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_min_dec'), {...ok, minPlayers: 2.5}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_min_str'), {...ok, minPlayers: '4'}));
  await assertFails(setDoc(doc(owner, 'liveSessions/lim_min_big'), {...ok, minPlayers: 11}));
});
await t('on update the minimum stays 2 up to the maximum; it can be removed', async () => {
  await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'liveSessions/lim_upd'), {groupId: 'g1', isPrivate: false, costPerPlayer: 5, maxPlayers: 10, minPlayers: 6, players: [], playerCount: 0}));
  await assertFails(updateDoc(evt('lim_upd'), {minPlayers: 1}));
  await assertFails(updateDoc(evt('lim_upd'), {minPlayers: 11}));
  await assertFails(updateDoc(evt('lim_upd'), {minPlayers: '6'}));
  await assertFails(updateDoc(evt('lim_upd'), {maxPlayers: 5})); // would leave min 6 above max
  await assertSucceeds(updateDoc(evt('lim_upd'), {maxPlayers: 6}));
  await assertSucceeds(updateDoc(evt('lim_upd'), {minPlayers: deleteField()}));
  await assertSucceeds(updateDoc(evt('lim_upd'), {maxPlayers: 4}));
});
await t('a legacy event over the cap can still be edited in other fields', () => assertSucceeds(updateDoc(evt('lim_legacy'), {title: 'Viejo'})));

// --- attendance policy ---
await env.withSecurityRulesDisabled(async (c) => {
  const d = c.firestore();
  await setDoc(doc(d, 'users/att1'), {credits: '0.00', documentType: 'dni', documentNumber: '12345678', blockedUntil: Timestamp.fromMillis(Date.now() + 86400000)});
  await setDoc(doc(d, 'users/att1/noShows/e1'), {eventId: 'e1', at: Timestamp.now()});
});
const att = as('att1');
await t('a user cannot lift or set their own block', async () => {
  await assertFails(updateDoc(doc(att, 'users/att1'), {blockedUntil: deleteField()}));
  await assertFails(updateDoc(doc(att, 'users/att1'), {blockedUntil: Timestamp.fromMillis(Date.now() - 1000)}));
  await assertFails(updateDoc(doc(alice, 'users/alice'), {blockedUntil: Timestamp.fromMillis(Date.now() + 1000)}));
});
await t('a user cannot delete their own doc to shed a block', () => assertFails(deleteDoc(doc(att, 'users/att1'))));
await t('a blocked user still edits their profile', () => assertSucceeds(updateDoc(doc(att, 'users/att1'), {firstName: 'Ana'})));
await t('a user reads their own no-shows, nobody else does, nobody writes them', async () => {
  await assertSucceeds(getDoc(doc(att, 'users/att1/noShows/e1')));
  await assertFails(getDoc(doc(bob, 'users/att1/noShows/e1')));
  await assertFails(setDoc(doc(att, 'users/att1/noShows/e2'), {eventId: 'e2', at: serverTimestamp()}));
  await assertFails(deleteDoc(doc(att, 'users/att1/noShows/e1')));
});

// --- legacy accounts add a document once (join gate) ---
const claim = async (uid, type, num, extra = {}) => {
  const db = as(uid); const b = writeBatch(db);
  b.update(doc(db, 'users/' + uid), {documentType: type, documentNumber: num, ...extra});
  b.set(doc(db, `documents/${type}_${num}`), {uid, createdAt: serverTimestamp()});
  return b.commit();
};
await t('[claim] legacy account claims a DNI with its lock in one batch', () => assertSucceeds(claim('legacy1', 'dni', '66666661')));
await t('[claim] legacy account claims a CE', () => assertSucceeds(claim('legacy2', 'ce', 'A12345678')));
await t('[claim] document without the lock is denied', () => assertFails(updateDoc(doc(as('legacy3'), 'users/legacy3'), {documentType: 'dni', documentNumber: '66666663'})));
await t('[claim] a number whose lock exists is denied', () => assertFails(claim('legacy4', 'dni', '55555555')));
await t('[claim] bad format is denied', () => assertFails(claim('legacy5', 'dni', '1234')));
await t('[claim] claim that also changes credits is denied', () => assertFails(claim('legacy6', 'dni', '66666666', {credits: '99.00'})));
await t('[claim] after claiming, the number cannot change again from the client', async () => {
  const db = as('legacy1'); const b = writeBatch(db);
  b.update(doc(db, 'users/legacy1'), {documentNumber: '66666667'});
  b.set(doc(db, 'documents/dni_66666667'), {uid: 'legacy1', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});
await t('[claim] a user with a document cannot swap it', async () => {
  const db = as('docowner'); const b = writeBatch(db);
  b.update(doc(db, 'users/docowner'), {documentNumber: '66666668'});
  b.set(doc(db, 'documents/dni_66666668'), {uid: 'docowner', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});
await t('[claim] nobody sets another account\'s document (even with a lock for themselves)', async () => {
  const db = as('bob'); const b = writeBatch(db);
  b.update(doc(db, 'users/legacy7'), {documentType: 'dni', documentNumber: '66666669'});
  b.set(doc(db, 'documents/dni_66666669'), {uid: 'bob', createdAt: serverTimestamp()});
  await assertFails(b.commit());
});

await env.cleanup();
const failed = results.filter((r) => !r).length;
console.log(`\nrules: ${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
