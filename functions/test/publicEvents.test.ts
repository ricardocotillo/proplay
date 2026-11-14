import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildPublicEvent} from '../src/publicEvents';

const base = {
  groupId: 'g1', title: 'Pichanga', sport: 'fútbol', isPrivate: false,
  playerCount: 3, maxPlayers: 10, costPerPlayer: 15, g: 'abc', l: [1, 2],
  players: [{uid: 'u1'}],
};

test('private event yields null', () => {
  assert.equal(buildPublicEvent('s1', {...base, isPrivate: true}), null);
});

test('missing isPrivate is treated as private', () => {
  const {isPrivate: _omit, ...rest} = base;
  assert.equal(buildPublicEvent('s1', rest), null);
});

test('public event copies fields, omits players, keeps g/l', () => {
  const out = buildPublicEvent('s1', base, 'Los Pibes')!;
  assert.equal('players' in out, false);
  assert.equal(out.g, 'abc');
  assert.deepEqual(out.l, [1, 2]);
  assert.equal(out.groupName, 'Los Pibes');
  assert.equal(out.title, 'Pichanga');
});

test('missing optional fields stay undefined', () => {
  const out = buildPublicEvent('s1', base)!;
  assert.equal(out.district, undefined);
  assert.equal(out.format, undefined);
  assert.equal(out.groupName, undefined);
});
