# Plan: Recurring Events Script (CSV → liveSessions)

## Summary
A CLI script (`functions/scripts/createRecurringEvents.ts`, Admin SDK) reads a local CSV of weekly event rules and creates/updates the `liveSessions` for one target week. CSV rows = recurring series; edit the CSV (change/add/delete rows) before each weekly run. Re-runs are idempotent (deterministic doc ids), never delete, and default to dry-run.

## User Story
As a ProPlay organizer, I want to keep my weekly events in a local spreadsheet and run one command each week, so that I don't create 10+ events by hand in the app every week.

## Problem → Solution
Each event is created by hand through the create-session UI (template + first live session; no recurrence, `docs/ARCHITECTURE.md` §7) → `npm run events:create -- --week 2026-12-07 --apply` reads `functions/events/events.csv` and upserts all events for that week.

## Metadata
- **Complexity**: Medium
- **Source PRD**: N/A
- **PRD Phase**: N/A
- **Estimated Files**: 8 (5 new, 3 updated)

---

## UX Design

### Before
N/A — no tooling; organizer uses the in-app form per event.

### After
```
functions/events/events.csv (local, gitignored)
  edit rows ──► npm run events:create -- --week 2026-12-07          (dry-run: prints plan)
            └─► npm run events:create -- --week 2026-12-07 --apply  (writes Firestore)

  output:
  CREATE rec_futsal-lun_2026-12-07  Lun 20:00 Futsal Miraflores
  UPDATE rec_futsal-mie_2026-12-09  (maxPlayers 10→12)
  SKIP   rec_voley-jue_2026-12-10   (active=no)
  WARN   rec_futsal-mar_2026-12-08  has 4 players: price change not applied
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Weekly event creation | One form per event | One command per week | Dry-run default |
| Change an event | Edit in app | Edit CSV row, re-run | Existing players untouched |
| Remove an event | Delete in app | Delete row/set `active=no` + delete in app | Script never deletes |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `functions/scripts/backfillPublicEvents.ts` | all | Admin-script pattern (init, ADC, emulator, batching, main/exit) |
| P0 | `lib/services/session_service.dart` | 33-94 | Exact fields written for template + liveSession, computed `durationInMinutes`/`costPerPlayer` |
| P0 | `lib/models/session_model.dart` | 134-162 | `liveSessions` `toMap` (field set, `g`/`l`, optional `district`/`format`) |
| P0 | `lib/models/session_template_model.dart` | 112-137 | `sessionTemplates` `toMap` |
| P1 | `lib/utils/geohash_utils.dart` | 1-16 | Geohash precision 6, `encode(lng, lat)` — port to TS |
| P1 | `functions/src/publicEvents.ts` + `functions/test/publicEvents.test.ts` | all | Pure-module + `node:test` pattern |
| P1 | `functions/src/index.ts` | mirror trigger | Public events are projected automatically; script must not write `publicEvents` |
| P2 | `lib/utils/sports.dart` | 1-8 | Canonical sports: `fútbol`, `baloncesto`, `voleibol` |
| P2 | `README.md` | ~125-145 | Where to document the script |

## External Documentation
No external research needed — uses `firebase-admin` already installed; no new dependency (own tiny CSV parser + geohash encoder).

---

## Patterns to Mirror

### SCRIPT_PATTERN
// SOURCE: functions/scripts/backfillPublicEvents.ts:1-14,41-44
```ts
// Usage (owner, from functions/):
//   gcloud auth application-default login
//   npx tsx scripts/backfillPublicEvents.ts
// Against the emulator: FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx tsx scripts/...
import {initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
async function main() {
  initializeApp({projectId: process.env.GCLOUD_PROJECT ?? 'proplay-eac23'});
  const db = getFirestore();
  ...
}
main().catch((e) => { console.error(e); process.exit(1); });
```

### FIELD_SHAPE (liveSessions)
// SOURCE: lib/models/session_model.dart:134-162
```
templateId, groupId, title, eventDate(Timestamp), eventEndDate(Timestamp), status:'OPEN',
playerCount:0, maxPlayers, costPerPlayer, isPrivate, sport, minAge, maxAge, desiredGender,
locationLat, locationLng, locationAddress, [district], [format], g (geohash p6), l [lat,lng]
```
Template adds `creatorId`, `totalCost`, `durationInMinutes`; `costPerPlayer = totalCost / maxPlayers` (0 if either is 0). `players` is omitted on create (client appends in the join transaction).

### TEST_STRUCTURE
// SOURCE: functions/test/publicEvents.test.ts:1-12
```ts
import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildPublicEvent} from '../src/publicEvents';
test('private event yields null', () => { assert.equal(buildPublicEvent('s1', {...base, isPrivate: true}), null); });
```

### ERROR/LOGGING
Scripts use `console.log` summaries and throw → `process.exit(1)` (backfill). Validation errors: collect all, print per-row (`row 4: sport "futbol" invalid`), exit 1 before any write.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `functions/src/recurringEvents.ts` | CREATE | Pure logic: `parseCsv`, `parseRows`, `weekDates`, `buildDocs`, `geohash`. Testable, no Firebase import |
| `functions/scripts/createRecurringEvents.ts` | CREATE | CLI: args, read CSV, diff vs Firestore, write |
| `functions/test/recurringEvents.test.ts` | CREATE | Unit tests for pure logic |
| `functions/events/events.example.csv` | CREATE | Committed template for the local file |
| `.gitignore` | UPDATE | Ignore `functions/events/events.csv` (real data local) |
| `functions/package.json` | UPDATE | `"events:create": "tsx scripts/createRecurringEvents.ts"` |
| `README.md` | UPDATE | Usage in the functions/scripts section |
| `docs/ARCHITECTURE.md` | UPDATE | §7 sessionTemplates note: script-created `rec_` ids; "Recurring" line |

(`CLAUDE.md`/`AGENTS.md`: "Not done" lists "recurring sessions" — leave; script is ops tooling, not app feature. Keep both in sync if touched.)

## NOT Building
- Deleting events (removals stay manual in-app; players/tickets/credits may exist).
- Refunds, admin removal, player management.
- Writing `publicEvents` (the `mirrorPublicEvent` trigger does it).
- In-app recurrence, `rrule`, UI, or deploying anything.
- Multi-week generation in one run (one `--week` per run; run again for more).
- XLSX import (export CSV from the spreadsheet).

---

## CSV Contract (decided)

Header row, UTF-8, comma-separated, RFC4180 quotes (addresses contain commas). One row = one weekly series.

| Column | Req | Notes |
|---|---|---|
| `key` | yes | Unique slug `[a-z0-9-]+`. Stable identity: doc ids `rec_{key}` (template) and `rec_{key}_{YYYY-MM-DD}` (live). **Never rename** a key or it becomes a new series |
| `active` | no | `no`/`false`/`0` → skip row. Default yes |
| `groupId` | yes | Must exist (`groups/{id}`) |
| `creatorId` | yes | uid, stored on template |
| `title` | yes | |
| `sport` | yes | `fútbol` \| `baloncesto` \| `voleibol` (exact accents) |
| `weekday` | yes | `lun mar mie jue vie sab dom` (or 1–7, Mon=1) |
| `start`, `end` | yes | `HH:mm`, Lima time. `end <= start` → ends next day |
| `maxPlayers` | yes | int ≥ 1 |
| `totalCost` | yes | number ≥ 0 (PEN); `costPerPlayer = totalCost/maxPlayers` |
| `isPrivate` | no | default `no` |
| `minAge`, `maxAge` | no | defaults from the create form (check create-session screen; Task 1) |
| `desiredGender` | no | default as the create form (Task 1) |
| `lat`, `lng`, `address`, `district`, `format` | lat/lng/address yes; rest no | |

Timezone: Peru is UTC−5 with no DST → build dates with fixed offset `-05:00`.

Week arg: `--week YYYY-MM-DD` = any date; normalized to that week's Monday. Default: next Monday.

## Sync semantics
- Live doc id `rec_{key}_{date}`. Not found → CREATE (`status:'OPEN'`, `playerCount:0`, no `players`).
- Found → UPDATE only changed schedule/info fields via `update` (never `players`, `playerCount`, `status`).
- Found with `playerCount > 0` and `costPerPlayer` or `maxPlayers < playerCount` change → WARN, skip those fields (price after payment would mismatch refunds; seats below players corrupt state).
- Template: `set(..., {merge:true})` at `sessionTemplates/rec_{key}` each run (keeps latest rule). Template `eventDate/eventEndDate` = this week's occurrence (matches existing shape).
- Dry-run default prints CREATE/UPDATE/SKIP/WARN; `--apply` writes (batches ≤ 400, backfill pattern).

---

## Step-by-Step Tasks

### Task 1: Confirm form defaults
- **ACTION**: Read `lib/screens/` create-session screen (grep `minAge`/`desiredGender`) for default values.
- **IMPLEMENT**: Use same defaults for omitted CSV columns; record them as constants in `recurringEvents.ts`.
- **VALIDATE**: Constants match the form.

### Task 2: Pure module `functions/src/recurringEvents.ts`
- **ACTION**: Create.
- **IMPLEMENT**: `parseCsv(text): string[][]` (quotes, `""`, CRLF, skip blank lines); `parseRows(records): {rows, errors}` (header → fields, per-row validation: key regex + uniqueness, sport ∈ list, weekday map, `HH:mm`, ints/numbers, lat∈[-90,90]/lng∈[-180,180]); `weekMonday(dateStr)`; `occurrence(row, monday): {start: Date, end: Date}` using `-05:00`; `geohash(lat,lng,6)` (standard base32 encoder, lng/lat order as `dart_geohash`); `buildLiveDoc(row, start, end)` & `buildTemplateDoc(row, start, end)` mirroring FIELD_SHAPE; `diffFields(existing, desired)`.
- **MIRROR**: `functions/src/publicEvents.ts` (pure, typed, no Firebase imports; dates as `Date` — admin SDK converts to `Timestamp`).
- **GOTCHA**: `durationInMinutes` from end−start; `costPerPlayer` 0 when `totalCost` or `maxPlayers` is 0; omit `district`/`format` when empty (match `if (x != null)`); sports compared byte-exact (NFC-normalize input).
- **VALIDATE**: `cd functions && npm run build`

### Task 3: Unit tests `functions/test/recurringEvents.test.ts`
- **MIRROR**: TEST_STRUCTURE.
- **IMPLEMENT**: see Testing Strategy.
- **VALIDATE**: `cd functions && npm test`

### Task 4: CLI `functions/scripts/createRecurringEvents.ts`
- **ACTION**: Create.
- **IMPLEMENT**: parse args (`--week`, `--file` default `events/events.csv`, `--apply`); read + parse + validate (print all errors, exit 1); `initializeApp` (SCRIPT_PATTERN); verify each distinct `groupId` exists (one `get` each, cached); for each active row load `rec_{key}_{date}`, diff, print line, queue writes; if `--apply` commit in batches; print totals.
- **MIRROR**: SCRIPT_PATTERN (batch of 400, `main().catch`).
- **GOTCHA**: Print project id before writing. Use `update` for existing (preserves `players`); `set` only for new.
- **VALIDATE**: dry-run against emulator (below).

### Task 5: Example CSV, gitignore, npm script
- **IMPLEMENT**: `events.example.csv` with 3 sample rows (one with quoted address containing comma, one `active=no`); `.gitignore` add `functions/events/events.csv`; `package.json` script `events:create`.

### Task 6: Docs
- **IMPLEMENT**: README block under the scripts section (`cp events/events.example.csv events/events.csv`, edit, dry-run, `--apply`, "never rename key", "removals are manual"); ARCHITECTURE §7 one-liner about `rec_` ids.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge? |
|---|---|---|---|
| parseCsv quotes | `a,"b, c","d""e"` | `['a','b, c','d"e']` | yes |
| parseCsv CRLF/blank lines | | blanks ignored | yes |
| invalid sport | `futbol` | error naming row | yes |
| duplicate key | two same | error | yes |
| weekMonday | `2026-12-09` (Wed) | `2026-12-07` | |
| occurrence | `mie 20:00–21:30` | `2026-12-09T20:00-05:00` = `2026-12-10T01:00Z` | yes (UTC rollover) |
| overnight | `22:00–00:30` | end next day | yes |
| geohash | `(57.64911, 10.40744)` | starts `u4pruy` (canonical vector) | |
| cost | 120 / 10 | 12; `maxPlayers` 0 → 0 | yes |
| omitted optional | no district | key absent | |
| diffFields | existing `playerCount:3` + new price | price flagged WARN, not in update | yes |

### Edge Cases Checklist
- [ ] Empty CSV / header only
- [ ] Missing required column
- [ ] `active=no` row
- [ ] Re-run produces zero writes (idempotent)
- [ ] Group id missing in Firestore
- [ ] Event with players: no overwrite of `players`/`playerCount`

---

## Validation Commands

### Static Analysis
```bash
cd functions && npm run build
```
EXPECT: zero type errors

### Unit Tests
```bash
cd functions && npm test
```
EXPECT: all pass (incl. new file)

### Emulator end-to-end (manual)
```bash
npx -y firebase-tools@latest emulators:start --project demo-proplay --only firestore,functions
# other shell, seed a groups/{id} doc, then:
cd functions && cp events/events.example.csv events/events.csv
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-proplay npm run events:create -- --week 2026-12-07
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-proplay npm run events:create -- --week 2026-12-07 --apply
# re-run --apply → all lines UNCHANGED; edit a row → UPDATE; check publicEvents mirrored
```
EXPECT: CREATE, then UNCHANGED, then UPDATE; `publicEvents/rec_*` appear for public rows

### Manual Validation
- [ ] Dry-run writes nothing
- [ ] Created event renders in the app feed/detail with correct Lima time
- [ ] Join an event, change price in CSV, re-run: WARN, price unchanged

---

## Acceptance Criteria
- [ ] All tasks done; `npm run build` and `npm test` pass
- [ ] Idempotent re-run; never deletes; dry-run default
- [ ] Field shape identical to app-created docs (join/ticket/cancel flows work on script events)
- [ ] README documents the weekly workflow

## Completion Checklist
- [ ] Follows backfill script pattern
- [ ] No new dependencies
- [ ] Sports canonical; constant mirrors `kSports` with a source comment
- [ ] `events.csv` gitignored, example committed

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Renamed `key` duplicates a series | Med | Duplicate events | Doc: never rename; dry-run shows CREATE |
| Price/seat edit after players joined | Med | Credit/refund mismatch | WARN + skip those fields |
| Script run against prod by mistake | Low | Real events created | Dry-run default, prints project id, `--apply` required |
| Timezone off (UTC vs Lima) | Med | Wrong event time | Fixed `-05:00`; unit test with UTC rollover |
| Admin writes bypass rules | Low | Invalid data | Row validation mirrors form rules |
| Geohash port differs from Dart | Low | Missing from radius search | Canonical vector test + emulator check of `g` vs an app-created doc |

## Notes
- Decisions from clarification: CSV format, upsert-only (no deletes), Admin SDK script under `functions/scripts`, one reused template per series.
- Open item: confirm the group owner uid for `creatorId` (one value repeated per row is fine).
