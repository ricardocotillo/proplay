import {test} from 'node:test';
import assert from 'node:assert/strict';
import {claimId, creditApprovedPush, dueReminders, reminderPush} from '../src/reminderPolicy';

const H = 3600_000;
const NOW = Date.UTC(2026, 10, 26, 12);

test('free-cancel reminder is due only in the hour before the 24 h deadline', () => {
  assert.deepEqual(dueReminders(NOW + 24 * H + 1, NOW), ['cancel_deadline']);
  assert.deepEqual(dueReminders(NOW + 25 * H, NOW), ['cancel_deadline']);
  assert.deepEqual(dueReminders(NOW + 24 * H, NOW), []);
  assert.deepEqual(dueReminders(NOW + 25 * H + 1, NOW), []);
  assert.deepEqual(dueReminders(NOW + 30 * H, NOW), []);
});

test('2 h reminder is due in the last two hours and never after the start', () => {
  assert.deepEqual(dueReminders(NOW + 2 * H, NOW), ['two_hours']);
  assert.deepEqual(dueReminders(NOW + 1, NOW), ['two_hours']);
  assert.deepEqual(dueReminders(NOW, NOW), []);
  assert.deepEqual(dueReminders(NOW - H, NOW), []);
  assert.deepEqual(dueReminders(NOW + 2 * H + 1, NOW), []);
});

test('copy is Spanish, names the event, links to its page', () => {
  const a = reminderPush('cancel_deadline', 'Fútbol 7', NOW, 'e1');
  assert.match(a.title, /cancelar gratis/);
  assert.match(a.body, /Fútbol 7/);
  assert.equal(a.path, '/events/e1');
  const b = reminderPush('two_hours', 'Fútbol 7', Date.UTC(2026, 10, 26, 23, 30), 'e1');
  assert.match(b.body, /18:30/); // Lima is UTC-5
});

test('credit approved push says saldo in S/ and opens Perfil', () => {
  const p = creditApprovedPush(20);
  assert.match(p.body, /S\/ 20\.00 más de saldo/);
  assert.equal(p.path, '/profile');
});

test('claim ids are per kind and id', () => {
  assert.equal(claimId('two_hours', 'e1'), 'two_hours_e1');
});
