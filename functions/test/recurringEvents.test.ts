import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  parseCsv, parseRows, weekMonday, occurrence, geohash, buildLiveDoc, buildTemplateDoc,
  diffFields, liveId, templateId, todayLima, addDays,
} from '../src/recurringEvents';

const HEADER = 'key,active,groupId,creatorId,title,sport,weekday,start,end,maxPlayers,totalCost,lat,lng,address,district,format';
const line = (o: Record<string, string> = {}) => {
  const v = {
    key: 'futbol-mie', active: '', groupId: 'g1', creatorId: 'u1', title: 'Fútbol', sport: 'fútbol',
    weekday: 'mie', start: '20:00', end: '21:30', maxPlayers: '10', totalCost: '120',
    lat: '-12.12', lng: '-77.03', address: '"Av. Test 1, Lima"', district: 'Miraflores', format: '5 vs 5', ...o,
  };
  return Object.values(v).join(',');
};
const parse = (...lines: string[]) => parseRows(parseCsv([HEADER, ...lines].join('\n')));

test('parseCsv handles quotes, escapes, CRLF, blank lines', () => {
  assert.deepEqual(parseCsv('a,"b, c","d""e"\r\n\r\nx,y,z\r\n'), [['a', 'b, c', 'd"e'], ['x', 'y', 'z']]);
});

test('parseRows accepts valid row with defaults', () => {
  const {rows, errors} = parse(line());
  assert.deepEqual(errors, []);
  assert.equal(rows[0].address, 'Av. Test 1, Lima');
  assert.equal(rows[0].minAge, 18);
  assert.equal(rows[0].desiredGender, 'any');
  assert.equal(rows[0].weekday, 2);
});

test('parseRows rejects bad sport, duplicate key, missing column', () => {
  assert.match(parse(line({sport: 'futbol'})).errors[0], /row 2: sport "futbol" invalid/);
  assert.match(parse(line(), line()).errors.join(), /duplicate key/);
  assert.match(parseRows(parseCsv('key,title\nx,y')).errors[0], /missing columns/);
  assert.deepEqual(parseRows([]).errors, ['empty CSV']);
});

test('inactive rows are skipped', () => {
  assert.equal(parse(line({active: 'no'})).rows.length, 0);
});

test('weekMonday normalizes to Monday', () => {
  assert.equal(weekMonday('2026-12-09'), '2026-12-07');
  assert.equal(weekMonday('2026-12-13'), '2026-12-07');
  assert.equal(weekMonday('2026-12-07'), '2026-12-07');
});

test('occurrence uses Lima time (UTC rollover) and overnight end', () => {
  const [r] = parse(line()).rows;
  const o = occurrence(r, '2026-12-07');
  assert.equal(o.date, '2026-12-09');
  assert.equal(o.start.toISOString(), '2026-12-10T01:00:00.000Z');
  const night = occurrence({...r, start: '22:00', end: '00:30'}, '2026-12-07');
  assert.equal(night.end.toISOString(), '2026-12-10T05:30:00.000Z');
});

test('geohash matches canonical vector', () => {
  assert.equal(geohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
  assert.equal(geohash(57.64911, 10.40744), 'u4pruy');
});

test('docs: cost, optional fields, ids, no players', () => {
  const [r] = parse(line()).rows;
  const {start, end} = occurrence(r, '2026-12-07');
  const live = buildLiveDoc(r, start, end);
  assert.equal(live.costPerPlayer, 12);
  assert.equal(live.status, 'OPEN');
  assert.equal('players' in live, false);
  assert.equal(live.templateId, 'rec_futbol-mie');
  assert.equal(buildTemplateDoc(r, start, end).durationInMinutes, 90);
  assert.equal(liveId(r, '2026-12-09'), 'rec_futbol-mie_2026-12-09');
  assert.equal(templateId(r), 'rec_futbol-mie');
  const bare = parse(line({district: '', format: ''})).rows[0];
  assert.equal('district' in buildLiveDoc(bare, start, end), false);
  assert.equal(buildLiveDoc({...r, totalCost: 0}, start, end).costPerPlayer, 0);
});

test('diffFields: unchanged → empty; with players skips price and low seats', () => {
  const [r] = parse(line()).rows;
  const {start, end} = occurrence(r, '2026-12-07');
  const desired = buildLiveDoc(r, start, end);
  assert.deepEqual(diffFields({...desired}, desired), {update: {}, warnings: []});

  const existing = {...desired, playerCount: 4, costPerPlayer: 10, maxPlayers: 10, players: [{}]};
  const d2 = {...desired, costPerPlayer: 15, maxPlayers: 3, minAge: 20};
  const out = diffFields(existing, d2);
  assert.deepEqual(out.update, {minAge: 20});
  assert.equal(out.warnings.length, 2);
});

test('fractional or inverted ages are rejected', () => {
  const h = 'key,groupId,creatorId,title,sport,weekday,start,end,maxPlayers,totalCost,lat,lng,address,minAge,maxAge';
  const row = (min: string, max: string) =>
    parseRows(parseCsv(`${h}\nk,g,u,T,fútbol,lun,20:00,21:00,10,100,-12,-77,A,${min},${max}`)).errors.join();
  assert.match(row('18.5', '60'), /integers/);
  assert.match(row('40', '30'), /invalid/);
  assert.equal(row('18', '60'), '');
});

test('diffFields: players lock ticket-snapshot fields; cleared optionals become null', () => {
  const [r] = parse(line()).rows;
  const {start, end} = occurrence(r, '2026-12-07');
  const desired = buildLiveDoc(r, start, end);
  const locked = diffFields({...desired, playerCount: 2, title: 'Viejo', locationAddress: 'Otra'}, desired);
  assert.deepEqual(locked.update, {});
  assert.equal(locked.warnings.length, 2);
  const free = diffFields({...desired, title: 'Viejo'}, desired);
  assert.deepEqual(free.update, {title: 'Fútbol'});

  const bare = buildLiveDoc(parse(line({district: '', format: ''})).rows[0], start, end);
  assert.deepEqual(diffFields({...bare, district: 'Miraflores', format: '5 vs 5'}, bare).update,
    {district: null, format: null});
  assert.equal(buildTemplateDoc(parse(line({district: ''})).rows[0], start, end).district, null);
});

test('todayLima uses Lima date, not UTC', () => {
  assert.equal(todayLima(new Date('2026-12-07T03:00:00Z')), '2026-12-06'); // Sun 22:00 Lima
  assert.equal(addDays('2026-12-06', 7), '2026-12-13');
});

test('maxPlayers must be 1 to 60 (a cancel refunds everyone in one transaction)', () => {
  assert.deepEqual(parse(line({maxPlayers: '60'})).errors, []);
  for (const v of ['0', '61', '2.5', 'x']) {
    assert.ok(parse(line({maxPlayers: v})).errors.length > 0, v);
  }
});
