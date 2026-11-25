// Pure logic for scripts/createRecurringEvents.ts. No Firebase imports.

// Mirrors kSports in lib/utils/sports.dart. Keep accents exact.
export const SPORTS = ['fútbol', 'baloncesto', 'voleibol'] as const;
// Mirrors create_session_screen.dart (any | male | female, ages 18-80).
export const GENDERS = ['any', 'male', 'female'] as const;
export const DEFAULT_MIN_AGE = 18;
export const DEFAULT_MAX_AGE = 80;
const WEEKDAYS = ['lun', 'mar', 'mie', 'jue', 'vie', 'sab', 'dom'];
const LIMA_OFFSET = '-05:00'; // Peru: no DST.

export interface Row {
  key: string;
  groupId: string;
  creatorId: string;
  title: string;
  sport: string;
  weekday: number; // 0 = Monday
  start: string;
  end: string;
  maxPlayers: number;
  totalCost: number;
  isPrivate: boolean;
  minAge: number;
  maxAge: number;
  desiredGender: string;
  lat: number;
  lng: number;
  address: string;
  district?: string;
  format?: string;
}

/** RFC4180-ish: quotes, "" escape, CRLF, blank lines skipped. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  const s = text.replace(/^﻿/, '');
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quoted) {
      if (c === '"') {
        if (s[i + 1] === '"') { cell += '"'; i++; } else quoted = false;
      } else cell += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(cell); cell = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && s[i + 1] === '\n') i++;
      row.push(cell); cell = '';
      if (row.some((v) => v.trim() !== '')) rows.push(row);
      row = [];
    } else cell += c;
  }
  row.push(cell);
  if (row.some((v) => v.trim() !== '')) rows.push(row);
  return rows;
}

const TIME = /^([01]?\d|2[0-3]):[0-5]\d$/;
const NO = new Set(['no', 'false', '0']);
const YES = new Set(['yes', 'si', 'sí', 'true', '1']);

/** Header + records → validated rows (inactive rows dropped) and errors. */
export function parseRows(records: string[][]): {rows: Row[]; errors: string[]} {
  const errors: string[] = [];
  const rows: Row[] = [];
  if (records.length === 0) return {rows, errors: ['empty CSV']};
  const header = records[0].map((h) => h.trim());
  const required = ['key', 'groupId', 'creatorId', 'title', 'sport', 'weekday', 'start',
    'end', 'maxPlayers', 'totalCost', 'lat', 'lng', 'address'];
  const missing = required.filter((h) => !header.includes(h));
  if (missing.length) return {rows, errors: [`missing columns: ${missing.join(', ')}`]};

  const seen = new Set<string>();
  records.slice(1).forEach((rec, idx) => {
    const n = idx + 2; // 1-based incl. header
    const g = (name: string) => (rec[header.indexOf(name)] ?? '').trim().normalize('NFC');
    const errs: string[] = [];
    const active = g('active').toLowerCase();
    if (NO.has(active)) return;

    const key = g('key');
    if (!/^[a-z0-9-]+$/.test(key)) errs.push(`key "${key}" must match [a-z0-9-]+`);
    else if (seen.has(key)) errs.push(`duplicate key "${key}"`);
    seen.add(key);

    for (const f of ['groupId', 'creatorId', 'title', 'address']) if (!g(f)) errs.push(`${f} required`);
    const sport = g('sport');
    if (!(SPORTS as readonly string[]).includes(sport)) errs.push(`sport "${sport}" invalid`);

    const wd = g('weekday').toLowerCase();
    let weekday = WEEKDAYS.indexOf(wd);
    if (weekday < 0 && /^[1-7]$/.test(wd)) weekday = Number(wd) - 1;
    if (weekday < 0) errs.push(`weekday "${wd}" invalid`);

    for (const f of ['start', 'end']) if (!TIME.test(g(f))) errs.push(`${f} "${g(f)}" must be HH:mm`);

    const num = (f: string, dflt?: number) => {
      const raw = g(f);
      if (raw === '' && dflt !== undefined) return dflt;
      const v = Number(raw);
      if (raw === '' || !Number.isFinite(v)) { errs.push(`${f} "${raw}" not a number`); return NaN; }
      return v;
    };
    const maxPlayers = num('maxPlayers');
    if (!Number.isInteger(maxPlayers) || maxPlayers < 1) errs.push('maxPlayers must be integer >= 1');
    const totalCost = num('totalCost');
    if (totalCost < 0) errs.push('totalCost must be >= 0');
    const minAge = num('minAge', DEFAULT_MIN_AGE);
    const maxAge = num('maxAge', DEFAULT_MAX_AGE);
    if (!Number.isInteger(minAge) || !Number.isInteger(maxAge)) errs.push('minAge/maxAge must be integers');
    else if (minAge < 0 || minAge > maxAge) errs.push('minAge/maxAge invalid (0 <= min <= max)');
    const lat = num('lat');
    const lng = num('lng');
    if (!(lat >= -90 && lat <= 90)) errs.push('lat out of range');
    if (!(lng >= -180 && lng <= 180)) errs.push('lng out of range');

    const gender = g('desiredGender') || 'any';
    if (!(GENDERS as readonly string[]).includes(gender)) errs.push(`desiredGender "${gender}" invalid`);

    const priv = g('isPrivate').toLowerCase();
    if (priv !== '' && !NO.has(priv) && !YES.has(priv)) errs.push(`isPrivate "${priv}" invalid`);

    if (errs.length) { errors.push(...errs.map((e) => `row ${n}: ${e}`)); return; }
    rows.push({
      key, groupId: g('groupId'), creatorId: g('creatorId'), title: g('title'), sport,
      weekday, start: g('start'), end: g('end'), maxPlayers, totalCost,
      isPrivate: YES.has(priv), minAge, maxAge, desiredGender: gender, lat, lng,
      address: g('address'),
      ...(g('district') ? {district: g('district')} : {}),
      ...(g('format') ? {format: g('format')} : {}),
    });
  });
  return {rows, errors};
}

/** Monday (YYYY-MM-DD) of the week containing the given date. */
export function weekMonday(dateStr: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) throw new Error(`bad date "${dateStr}"`);
  const d = new Date(`${dateStr}T00:00:00Z`);
  if (Number.isNaN(d.getTime())) throw new Error(`bad date "${dateStr}"`);
  d.setUTCDate(d.getUTCDate() - ((d.getUTCDay() + 6) % 7));
  return d.toISOString().slice(0, 10);
}

/** Today's date (YYYY-MM-DD) in Lima. */
export function todayLima(now = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {timeZone: 'America/Lima'}).format(now);
}

export function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** Start/end instants for a row in the week starting at `monday`. `date` = Lima day. */
export function occurrence(row: Row, monday: string): {date: string; start: Date; end: Date} {
  const date = addDays(monday, row.weekday);
  const pad = (t: string) => t.padStart(5, '0');
  const start = new Date(`${date}T${pad(row.start)}:00${LIMA_OFFSET}`);
  let end = new Date(`${date}T${pad(row.end)}:00${LIMA_OFFSET}`);
  if (end <= start) end = new Date(`${addDays(date, 1)}T${pad(row.end)}:00${LIMA_OFFSET}`);
  return {date, start, end};
}

const B32 = '0123456789bcdefghjkmnpqrstuvwxyz';
/** Standard geohash; same as dart_geohash `encode(lng, lat)`. */
export function geohash(lat: number, lng: number, precision = 6): string {
  const latR = [-90, 90];
  const lngR = [-180, 180];
  let out = '';
  let bit = 0;
  let ch = 0;
  let even = true;
  while (out.length < precision) {
    const r = even ? lngR : latR;
    const v = even ? lng : lat;
    const mid = (r[0] + r[1]) / 2;
    if (v >= mid) { ch = (ch << 1) | 1; r[0] = mid; } else { ch <<= 1; r[1] = mid; }
    even = !even;
    if (++bit === 5) { out += B32[ch]; bit = 0; ch = 0; }
  }
  return out;
}

export const templateId = (row: Row) => `rec_${row.key}`;
export const liveId = (row: Row, date: string) => `rec_${row.key}_${date}`;

function shared(row: Row, start: Date, end: Date) {
  const costPerPlayer = row.totalCost > 0 && row.maxPlayers > 0 ? row.totalCost / row.maxPlayers : 0;
  return {
    groupId: row.groupId,
    title: row.title,
    eventDate: start,
    eventEndDate: end,
    maxPlayers: row.maxPlayers,
    costPerPlayer,
    isPrivate: row.isPrivate,
    sport: row.sport,
    minAge: row.minAge,
    maxAge: row.maxAge,
    desiredGender: row.desiredGender,
    locationLat: row.lat,
    locationLng: row.lng,
    locationAddress: row.address,
    ...(row.district ? {district: row.district} : {}),
    ...(row.format ? {format: row.format} : {}),
    g: geohash(row.lat, row.lng),
    l: [row.lat, row.lng],
  };
}

/** Fields of a new liveSessions doc (no `players`, like the app). */
export function buildLiveDoc(row: Row, start: Date, end: Date): Record<string, any> {
  return {
    templateId: templateId(row),
    ...shared(row, start, end),
    status: 'OPEN',
    playerCount: 0,
  };
}

export function buildTemplateDoc(row: Row, start: Date, end: Date): Record<string, any> {
  return {
    ...shared(row, start, end),
    // Template is written with merge: null clears a value removed from the CSV.
    district: row.district ?? null,
    format: row.format ?? null,
    creatorId: row.creatorId,
    totalCost: row.totalCost,
    durationInMinutes: Math.round((end.getTime() - start.getTime()) / 60000),
  };
}

// Copied onto tickets at join time (see TicketModel). g/l derive from lat/lng.
const TICKET_SNAPSHOT = new Set(['title', 'eventDate', 'eventEndDate', 'locationAddress',
  'locationLat', 'locationLng', 'g', 'l', 'sport']);
const OPTIONAL_TEXT = ['district', 'format'];

const eq = (a: unknown, b: unknown): boolean => {
  const norm = (v: any): any => (v && typeof v.toMillis === 'function' ? v.toMillis()
    : v instanceof Date ? v.getTime() : v);
  return JSON.stringify(norm(a)) === JSON.stringify(norm(b));
};

/**
 * Compare desired live doc to the existing one. Returns fields to update and
 * warnings. With players, price changes and seats below playerCount are skipped.
 * Never touches players / playerCount / status.
 */
export function diffFields(
  existing: Record<string, any>,
  desired: Record<string, any>,
): {update: Record<string, any>; warnings: string[]} {
  const update: Record<string, any> = {};
  const warnings: string[] = [];
  const players: number = existing.playerCount ?? 0;
  for (const [k, v] of Object.entries(desired)) {
    if (k === 'status' || k === 'playerCount' || k === 'players') continue;
    if (eq(existing[k], v)) continue;
    if (players > 0 && k === 'costPerPlayer') {
      warnings.push(`has ${players} players: price change not applied`);
      continue;
    }
    // Tickets snapshot these fields; editing them would leave tickets stale.
    if (players > 0 && TICKET_SNAPSHOT.has(k)) {
      warnings.push(`has ${players} players: ${k} change not applied (edit in app)`);
      continue;
    }
    if (players > 0 && k === 'maxPlayers' && (v as number) < players) {
      warnings.push(`has ${players} players: maxPlayers ${v} not applied`);
      continue;
    }
    update[k] = v;
  }
  // Cleared optional cells: desired omits the key, so null out the stale value.
  for (const k of OPTIONAL_TEXT) {
    if (desired[k] === undefined && existing[k] != null) update[k] = null;
  }
  return {update, warnings};
}
