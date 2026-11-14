# Plan: Events marketplace (public feed + cancel with refund)

## Summary
Turn ProPlay's group-first UX into a Fuchigol-style public events feed. Signed-out visitors browse public events at `/events`. Signed-in players cancel their own spot through a Cloud Function that refunds the full cost when cancelled 24 h or more before kickoff. Groups stay and act as organizers.

## User Story
As a player in Peru, I want to browse public sports events, filter them, pay for a spot and cancel with a refund, so that I can trust the app like I trust Fuchigol.

## Problem → Solution
Home is a list of groups; the matched list needs `user.sports`, requires sign-in, and a joined player can never leave with a refund (the join dialog even says "NO serán devueltos") → public feed with district/time/price/format filters, anonymous browsing, and a server-side cancel that voids the ticket and refunds.

## Metadata
- **Complexity**: Large (new Cloud Functions package, rules change, ~25 files)
- **Source PRD**: `docs/superpowers/specs/2026-11-13-events-marketplace-design.md` (design doc, not a PRD with phases)
- **PRD Phase**: standalone
- **Estimated Files**: ~14 Dart edits, ~8 Dart creates, ~8 functions/rules files, 4 docs

---

## UX Design

### Before
```
signed out: /welcome (landing) → login / registration only
signed in : Home = [carousel of upcoming] + [my groups list]
            Sessions = matched list (needs user.sports, sign-in)
            Session detail: join (no way back, "créditos NO serán devueltos")
```

### After
```
anyone    : /welcome → "Ver eventos" → /events
            [filters: deporte · distrito · horario · precio máx · formato]
            card: título · deporte · distrito · fecha · S/precio · 3/10 cupos
            tap → /events/:id (read-only, "Regístrate para unirte")
signed in : Home leads with the same feed, groups below ("Mis grupos")
            Session detail: [Ver mi ticket] [Cancelar mi cupo]
            Cancel dialog: "Reembolso completo" (≥24 h) | "Sin reembolso" (<24 h)
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| `/events` | n/a | public feed, no auth | reads `publicEvents` only |
| Home | groups list | feed first, groups second | layout is builder's call |
| Join dialog | "No podrás salir… NO devueltos" | states the 24 h refund rule | copy in Spanish |
| Session detail | no leave button | "Cancelar mi cupo" | calls callable |
| Create session | no district/format | district auto from map, format optional | |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `docs/superpowers/specs/2026-11-13-events-marketplace-design.md` | all | the contract |
| P0 | `docs/superpowers/specs/prod-firestore-rules-2026-11-13.rules` | all | exact live rules; base for `firestore.rules` |
| P0 | `lib/services/session_service.dart` | 31-90, 437-580, 603-727 | create, matchmaking filters, join (ticket + ledger shape), old leave |
| P0 | `lib/services/ticket_service.dart` | all | ticket builder/validate |
| P0 | `lib/models/ticket_model.dart` | all | model to extend |
| P0 | `lib/models/session_model.dart` | all | model to extend |
| P0 | `lib/utils/auth_redirect.dart` + `test/auth_redirect_test.dart` | all | route gate and its test |
| P0 | `lib/main.dart` | 108-240 | GoRouter table and redirect |
| P1 | `lib/bloc/session_detail/*` | all | bloc to change |
| P1 | `lib/screens/session_detail_screen.dart` | 35-110, 355-410, 548-600 | join/ticket buttons, dialog |
| P1 | `lib/screens/sessions_screen.dart` | all | current matched list (to replace) |
| P1 | `lib/screens/create_session_screen.dart` | 36-60, 205-240, 292-306, 495-535 | create wizard |
| P1 | `lib/widgets/location_picker.dart` | 8-14, 95-125 | where district is extracted |
| P2 | `lib/screens/home_screen.dart` | 225-270, 351-436 | Home layout |
| P2 | `lib/screens/my_tickets_screen.dart` 85-100, `ticket_detail_screen.dart` 105-160, `validate_ticket_screen.dart` 160-190 | | all branch on `isUsed` |
| P2 | `lib/utils/sports.dart` | all | canonical sport list `kSports` |

## External Documentation
| Topic | Source | Key Takeaway |
|---|---|---|
| Callable v2 | firebase.google.com/docs/functions/callable | `onCall` from `firebase-functions/v2/https`; `request.auth.uid`; throw `HttpsError` |
| Firestore triggers v2 | firebase.google.com/docs/functions/firestore-events | `onDocumentWritten('liveSessions/{id}')`; **trigger region must match the Firestore database location** |
| `cloud_functions` Dart | pub.dev/packages/cloud_functions | `FirebaseFunctions.instanceFor(region: …).httpsCallable(name).call({...})` |
| Rules emulator | firebase.google.com/docs/rules/emulator-functions | optional; test rules before deploying |

KEY_INSIGHT: callable region and trigger region are independent; the trigger must sit where the DB lives.
VERIFIED (2026-11-13, Firebase MCP `firestore_list_databases`): the `(default)` database of `proplay-eac23` is in `southamerica-east1` (Firestore Native, Standard edition). So the trigger and the callable both use `southamerica-east1`; no region split needed.
GOTCHA: `cloud_functions` must be compatible with `firebase_core ^5.1.0` / `cloud_firestore ^7.1.0`. Run `flutter pub add cloud_functions` and accept the resolver's version; do not pin by hand.

---

## Patterns to Mirror

### NAMING_CONVENTION
// SOURCE: CLAUDE.md "Conventions"; lib/bloc/session_detail/
Screens `{name}_screen.dart`, models `{name}_model.dart`, services `{name}_service.dart`, BLoC `{name}_bloc.dart` / `_event.dart` / `_state.dart`. Imports: Flutter → packages → `package:proplay/...`. Product copy Spanish.

### ERROR_HANDLING
// SOURCE: lib/bloc/session_detail/session_detail_bloc.dart:93-98
```dart
try {
  await sessionService.joinSession(currentState.session.id, currentUser);
} catch (e) {
  emit(SessionDetailError(e.toString(), session: currentState.session));
}
```

### SERVICE_PATTERN (transaction, ledger row shape)
// SOURCE: lib/services/session_service.dart:650-668
```dart
transaction.set(creditHistoryRef, {
  'userId': user.uid, 'creditAmount': costPerPlayer, 'amountPaid': 0.0,
  'createdAt': FieldValue.serverTimestamp(), 'status': 'completed',
  'entryType': 'spend', 'direction': 'debit', 'sourceType': 'session',
  'sourceId': sessionId, 'sessionId': sessionId, 'sessionTitle': session.title,
  'groupId': session.groupId, 'balanceBefore': userCredits,
  'balanceAfter': newCredits, 'notes': 'Unirse a pichanga: ${session.title}',
});
```

### CREDIT_FORMAT
// SOURCE: lib/models/user_model.dart:99-104
`creditsValue = double.tryParse(credits) ?? 0.0`; `formatCredits(v) = v.toStringAsFixed(2)`. The function mirrors this with `Number(x).toFixed(2)`.

### BLOC_EVENT_PATTERN
// SOURCE: lib/bloc/session_detail/session_detail_event.dart:25-28
```dart
/// Leave the current session
class LeaveSession extends SessionDetailEvent {
  const LeaveSession();
}
```

### ROUTE_GATE
// SOURCE: lib/utils/auth_redirect.dart:1-9
```dart
const _publicRoutes = {'/welcome', '/login', '/registration'};
String? authRedirect({required bool loggedIn, required String location}) {
  final isPublic = _publicRoutes.contains(location);
  if (!loggedIn && !isPublic) return '/welcome';
  if (loggedIn && isPublic) return '/';
  return null;
}
```

### TEST_STRUCTURE
// SOURCE: test/auth_redirect_test.dart:1-10
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:proplay/utils/auth_redirect.dart';
void main() {
  test('guest on protected route goes to /welcome', () {
    expect(authRedirect(loggedIn: false, location: '/'), '/welcome');
  });
}
```
Pure functions + `flutter_test`, no Firebase. Follow this for every new Dart test.

### GEOLOCATION_SORT
// SOURCE: lib/services/session_service.dart:546-571 — sort by `LocationUtils.calculateDistance`, sessions without lat/lng last, tie-break by `eventDate`. Reuse it; do not rewrite.

### FILTER_RULES_TO_KEEP
// SOURCE: lib/services/session_service.dart `_matchesGenderRequirement`, `_matchesAgeRequirement`, `_isWithinDistance` (private helpers near line 1-30). Make them public static (or move to `lib/utils/feed_filters.dart`) so the feed reuses them.

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `firestore.rules` | CREATE | baseline = prod rules + `publicEvents` + `pricePaid` |
| `firestore.indexes.json` | CREATE | empty indexes (feed needs none) |
| `firebase.json` | UPDATE | add `firestore` and `functions` sections |
| `functions/package.json`, `tsconfig.json`, `.gitignore` | CREATE | Functions v2 package (Node 20, TypeScript) |
| `functions/src/index.ts` | CREATE | exports |
| `functions/src/refundPolicy.ts` | CREATE | pure `isRefundable`, `formatCredits` |
| `functions/src/cancelParticipation.ts` | CREATE | callable |
| `functions/src/publicEvents.ts` | CREATE | trigger + pure `buildPublicEvent` |
| `functions/scripts/backfillPublicEvents.ts` | CREATE | one-off copy of existing public events |
| `functions/test/*.test.ts` | CREATE | `node --test` unit tests |
| `pubspec.yaml` | UPDATE | `cloud_functions` |
| `lib/models/session_model.dart`, `session_template_model.dart` | UPDATE | `district`, `format`, optional `groupName` |
| `lib/models/ticket_model.dart` | UPDATE | `pricePaid`, `cancelled` status, `cancelledAt`, `refunded` |
| `lib/models/cancel_result_model.dart` | CREATE | `{refunded, amount}` |
| `lib/services/ticket_service.dart` | UPDATE | set `pricePaid`; reject cancelled in `validateTicket` |
| `lib/services/session_service.dart` | UPDATE | `cancelParticipation`, `getPublicEvents`, `streamPublicEvent`; delete `leaveSession`; district/format on create |
| `lib/utils/refund_policy.dart` | CREATE | display-only `isRefundable(eventDate, now)` |
| `lib/utils/feed_filters.dart` | CREATE | `FeedFilters`, `applyFeedFilters`, `timeOfDay` |
| `lib/utils/auth_redirect.dart` | UPDATE | open routes `/events`, `/events/:id` |
| `lib/widgets/location_picker.dart` | UPDATE | `LocationResult.district` |
| `lib/screens/create_session_screen.dart` | UPDATE | pass district, add format field |
| `lib/bloc/events_feed/*` | CREATE | feed bloc (event/state/bloc) |
| `lib/screens/events_feed_screen.dart` | CREATE | feed + filters |
| `lib/screens/public_event_screen.dart` | CREATE | read-only detail for guests |
| `lib/widgets/events_feed_view.dart` | CREATE | shared feed body (Home + `/events`) |
| `lib/main.dart` | UPDATE | routes `/events`, `/events/:id`; `/sessions` → feed |
| `lib/screens/home_screen.dart` | UPDATE | feed first, groups second |
| `lib/screens/landing_screen.dart` | UPDATE | "Ver eventos" button |
| `lib/bloc/session_detail/*` | UPDATE | `LeaveSession` → `CancelParticipation` |
| `lib/screens/session_detail_screen.dart` | UPDATE | cancel button/dialog, join copy |
| `lib/screens/my_tickets_screen.dart`, `ticket_detail_screen.dart`, `validate_ticket_screen.dart` | UPDATE | cancelled state |
| `test/*` | CREATE/UPDATE | see Testing Strategy |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md`, `README.md` | UPDATE | routes, `publicEvents`, functions, deploy order |

## NOT Building
- Min-player confirmation, no-show strikes, suspension, goalkeeper rate, fields/academies/tournaments, MVP/chat/live score.
- Refund on organizer deletion or admin removal (`removeUserFromSession` unchanged).
- Moving `joinSession` or Yape approval server-side; fixing the stale-credits read in `joinSession`.
- Locking `users.credits` / `liveSessions` update rules (documented follow-up).
- Waitlist, recurring events, pagination beyond the 30-day window.

---

## Step-by-Step Tasks

Order matters for the owner's manual deploy: **rules → function → app**. Code order below is dependency order; deploy order is in Task 20.

### Task 1: Rules, indexes, firebase.json
- **ACTION**: create `firestore.rules` and `firestore.indexes.json`; extend `firebase.json`.
- **IMPLEMENT**: copy `docs/superpowers/specs/prod-firestore-rules-2026-11-13.rules` to `firestore.rules`, then apply exactly two edits: (1) add before the closing of `match /documents/`:
  ```
  match /publicEvents/{eventId} {
    allow read: if true;
    allow write: if false;
  }
  ```
  (2) in `isValidTicketData`, add `'pricePaid'` to the `hasOnly` list and the check `&& (!('pricePaid' in data) || (data.pricePaid is number && data.pricePaid >= 0))`. `firestore.indexes.json` = `{"indexes": [], "fieldOverrides": []}`. In `firebase.json` add `"firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"}` and `"functions": [{"source": "functions", "codebase": "default", "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]}]` beside `hosting`. Do not touch the `flutter` block.
- **MIRROR**: existing `firebase.json` structure.
- **GOTCHA**: do **not** touch `liveSessions`, `users` or `creditHistory` rules. `pricePaid` must be **optional** in the rule (the form above): the old app's join does not send it, and a required field would break join until the new app ships.
- **VALIDATE**: `npx -y firebase-tools@latest emulators:exec --only firestore "echo ok"` loads the rules without syntax error. The owner can also use the console Rules Playground.

### Task 2: Functions package skeleton
- **ACTION**: create `functions/` with `package.json` (Node 20; deps `firebase-admin`, `firebase-functions`; dev `typescript`, `tsx`, `@types/node`; scripts `build: tsc`, `test: node --import tsx --test test/*.test.ts`), `tsconfig.json` (`outDir: lib`, `strict`, `module: commonjs`, `target: es2022`), `.gitignore` (`node_modules`, `lib`).
- **IMPLEMENT**: `src/index.ts`: `import {setGlobalOptions} from 'firebase-functions/v2'; import {initializeApp} from 'firebase-admin/app'; initializeApp(); setGlobalOptions({region: 'southamerica-east1', maxInstances: 10}); export {cancelParticipation} from './cancelParticipation'; export {mirrorPublicEvent} from './publicEvents';`
- **GOTCHA**: the Firestore trigger needs its own `region` option equal to the DB location (see External Documentation); override `setGlobalOptions` per function in Task 5.
- **VALIDATE**: `cd functions && npm install && npm run build`.

### Task 3: Pure refund policy (TS) + tests
- **ACTION**: create `functions/src/refundPolicy.ts`.
- **IMPLEMENT**:
  ```ts
  export const REFUND_WINDOW_MS = 24 * 60 * 60 * 1000;
  export const isRefundable = (eventDate: Date, now: Date): boolean =>
    eventDate.getTime() - now.getTime() >= REFUND_WINDOW_MS;
  export const formatCredits = (v: number): string => v.toFixed(2);
  export const refundDocId = (sessionId: string, uid: string, token: string) =>
    `refund_${sessionId}_${uid}_${token}`;
  ```
- **VALIDATE**: `functions/test/refundPolicy.test.ts` covers exactly 24 h (true), 24 h minus 1 ms (false), past event (false), `formatCredits(15)` = `'15.00'`, `refundDocId` shape.

### Task 4: `cancelParticipation` callable
- **ACTION**: create `functions/src/cancelParticipation.ts`.
- **IMPLEMENT**: `onCall` with `request.auth` required (else `HttpsError('unauthenticated')`), `sessionId` string required (else `invalid-argument`). `uid = request.auth.uid` only. One `db.runTransaction`, **all reads before writes**:
  1. read `liveSessions/{sessionId}`; missing → `not-found`. Parse `players` (array of maps with `uid`); user absent → `failed-precondition` "No participas en este evento".
  2. read `tickets/{sessionId}_{uid}` (may not exist).
  3. If ticket exists and `status != 'valid'` → `failed-precondition` (used or already cancelled).
  4. `eventDate = session.eventDate.toDate()`; `refundable = isRefundable(eventDate, new Date())` (server time).
  5. If refundable, resolve amount: `ticket.pricePaid` if a number, else query `creditHistory` where `userId == uid`, `sourceId == sessionId`, `entryType == 'spend'` (equality-only, no composite index) and take the row with the latest `createdAt` → its `creditAmount`; else amount 0 → treated as not refunded. Do this query **before** writes (use `transaction.get(query)`).
  6. Read `users/{uid}` (needed only when refunding).
  7. Writes: `liveSessions` update `players` (filtered) + `playerCount`; ticket update (if exists) `status: 'cancelled'`, `cancelledAt: serverTimestamp`, `refunded: boolean`; if `refundable && amount > 0`: `users/{uid}.credits = formatCredits(before + amount)` and `creditHistory/{refundDocId(sessionId, uid, token || 'noticket')}` set (not add) with the shape in SERVICE_PATTERN but `entryType: 'refund'`, `direction: 'credit'`, `sourceType: 'session'`, `notes: 'Reembolso por cancelación: <title>'`, `balanceBefore/After` as numbers.
  8. Return `{refunded: boolean, amount: number}`.
- **MIRROR**: ledger shape above; credit string rule.
- **IMPORTS**: `onCall, HttpsError` from `firebase-functions/v2/https`; `getFirestore, FieldValue` from `firebase-admin/firestore`.
- **GOTCHA**: idempotency comes from `set()` on a deterministic doc id plus the ticket status check; also, if the refund doc already exists (`transaction.get`), treat as already refunded and skip the credit write. Never read the amount from the payload. A user not in `players[]` with a leftover valid ticket: still `failed-precondition`.
- **VALIDATE**: manual emulator test in Task 20; pure helpers are covered in Task 3.

### Task 5: `mirrorPublicEvent` trigger + pure builder
- **ACTION**: create `functions/src/publicEvents.ts`.
- **IMPLEMENT**: pure `buildPublicEvent(id, data, groupName?) → object | null`: returns `null` if `data.isPrivate !== false`; otherwise copies only `templateId, groupId, title, eventDate, eventEndDate, status, playerCount, maxPlayers, costPerPlayer, isPrivate, sport, minAge, maxAge, desiredGender, locationLat, locationLng, locationAddress, district, format, g, l` plus `groupName`. Never copies `players`. Trigger: `onDocumentWritten({document: 'liveSessions/{id}', region: 'southamerica-east1'}, …)`: if `after` missing or builder returns null → delete `publicEvents/{id}` (ignore not-found); else read `groups/{groupId}` name and `set` the projection.
- **GOTCHA**: fires on every join (`players` changes); no loop since it writes a different collection.
- **VALIDATE**: `functions/test/publicEvents.test.ts`: private → null; public copies fields, omits `players`, keeps `g`/`l`; missing optional fields stay undefined.

### Task 6: Backfill script
- **ACTION**: create `functions/scripts/backfillPublicEvents.ts`.
- **IMPLEMENT**: Admin SDK, query `liveSessions` where `isPrivate == false`, for each call `buildPublicEvent` and `set` into `publicEvents`, in batches of 400. Log counts. The owner runs it with `gcloud auth application-default login` then `npx tsx scripts/backfillPublicEvents.ts`.
- **VALIDATE**: against the emulator with `FIRESTORE_EMULATOR_HOST` set.

### Task 7: Dart dependency
- **ACTION**: `flutter pub add cloud_functions`.
- **VALIDATE**: `flutter pub get` resolves; `flutter analyze` does not get worse (it already reports `include_file_not_found`).

### Task 8: Session and template models
- **ACTION**: add `final String? district; final String? format; final String? groupName;` to `SessionModel` (props, `copyWith`, `toMap`, `fromMap`); add `district`, `format` to `SessionTemplateModel` (constructor, props, `copyWith`, `toMap`, `fromMap`).
- **MIRROR**: how `locationAddress` is threaded (`session_model.dart:25,46,69,91,112,135,169`).
- **IMPLEMENT**: in `toMap` write `district`, `format` only when non-null; `groupName` is never written by the client. `fromMap` reads `map['district'] as String?` etc.
- **GOTCHA**: existing docs lack these fields; `fromMap` must stay null-safe. `SessionModel.fromMap` still `as`-casts required fields; the projection carries them all.
- **VALIDATE**: `test/session_model_test.dart`: roundtrip with and without new fields.

### Task 9: Ticket model + service
- **ACTION**: `TicketModel`: add `final double? pricePaid; final DateTime? cancelledAt; final bool refunded;` (default false); `bool get isCancelled => status == 'cancelled';`. `toMap()` writes `pricePaid` **only when non-null** and **never** writes `cancelledAt`/`refunded` (the client must not; the rule forbids those keys). `fromMap` reads all three.
- `TicketService.buildTicketForJoin`: set `pricePaid: session.costPerPlayer`.
- `TicketService.validateTicket`: after the `isUsed` check add `if (ticket.isCancelled) throw Exception('Este ticket fue cancelado');`.
- `ValidateTicketBloc` (`lib/bloc/validate_ticket/validate_ticket_bloc.dart`, around line 100) must also stop a cancelled ticket; read it and mirror its error path.
- **VALIDATE**: `test/ticket_model_test.dart`: `toMap` has `pricePaid` and lacks `cancelledAt`/`refunded`; `fromMap` of a cancelled doc sets `isCancelled`.

### Task 10: Cancelled ticket UI
- **ACTION**: wherever `ticket.isUsed` picks color/text (`my_tickets_screen.dart:92-93`, `ticket_detail_screen.dart:110,126,155`, `validate_ticket_screen.dart:164-185`) add a cancelled branch: grey, "Cancelado", QR dimmed and disabled.
- **VALIDATE**: manual check in Task 20.

### Task 11: Refund policy (Dart, display only) + test
- **ACTION**: create `lib/utils/refund_policy.dart`.
- **IMPLEMENT**: `bool isRefundable(DateTime eventDate, DateTime now) => eventDate.difference(now) >= const Duration(hours: 24);`
- **VALIDATE**: `test/refund_policy_test.dart` with the same boundaries as Task 3.

### Task 12: `SessionService` additions
- **ACTION**: in `session_service.dart`:
  - add `import 'package:cloud_functions/cloud_functions.dart';` and `Future<CancelResultModel> cancelParticipation(String sessionId)` using `FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('cancelParticipation').call({'sessionId': sessionId})`; map `data['refunded']`, `data['amount']`; convert `FirebaseFunctionsException` to `Exception(e.message ?? '...')`.
  - add `Future<List<SessionModel>> getPublicEvents({int windowDays = 30})`: `collection('publicEvents').where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now)).where('eventDate', isLessThanOrEqualTo: Timestamp.fromDate(now + windowDays)).orderBy('eventDate')` (range on one field, no composite index) → `SessionModel.fromMap`.
  - add `Stream<SessionModel> streamPublicEvent(String id)` mirroring `streamSession` (`session_service.dart:592-600`).
  - **delete** `leaveSession` (`:697-727`).
  - `createSessionTemplate` / `_createFirstLiveSession`: pass `district`, `format` through (`:63-90`).
- **MIRROR**: existing query style in `getAllPublicSessions` (`:216`); `streamSession`.
- **GOTCHA**: do not touch `getAllUpcomingSessions`; Home carousel still uses it.
- **VALIDATE**: `flutter analyze` shows no new errors; unit tests only for pure code (services use Firebase singletons, as the repo does).

### Task 13: Feed filters (pure) + test
- **ACTION**: create `lib/utils/feed_filters.dart`.
- **IMPLEMENT**:
  ```dart
  enum DayPart { morning, afternoon, night }   // not TimeOfDay: clashes with Flutter
  DayPart dayPart(DateTime d) // America/Lima = UTC-5, no DST:
  //   h = d.toUtc().add(const Duration(hours: -5)).hour
  //   5<=h<12 morning, 12<=h<18 afternoon, else night
  class FeedFilters extends Equatable { sport, district, dayPart, maxPrice, format }
  List<SessionModel> applyFeedFilters(List<SessionModel> l, FeedFilters f,
      {String? userGender, int? userAge})
  List<String> distinctDistricts(List<SessionModel> l)
  ```
  Each non-null filter must match; `district`/`format` compare case- and accent-insensitively; sessions lacking the field fail only that filter; gender/age use the same semantics as matchmaking (`desiredGender == 'any' || == userGender`; `minAge <= age <= maxAge`) and apply **only** when `userGender`/`userAge` are non-null.
- **MIRROR**: `_matchesGenderRequirement` / `_matchesAgeRequirement` in `session_service.dart`; read them first and keep null-handling identical.
- **VALIDATE**: `test/feed_filters_test.dart`: bucket boundaries (04:59, 05:00, 11:59, 12:00, 17:59, 18:00 Lima), price filter inclusive, accent/case-insensitive district, missing district excluded only when a district filter is set, guest gets no gender/age filtering.

### Task 14: Route gate for `/events`
- **ACTION**: update `lib/utils/auth_redirect.dart`.
- **IMPLEMENT**: keep `_guestOnly = {'/welcome','/login','/registration'}` (signed-in users go to `/`); add `bool _isOpen(String l) => l == '/events' || l.startsWith('/events/')` — open to everyone, never redirected. Logic: if `_isOpen` → `null`; then the existing guest/signed-in rules.
- **VALIDATE**: extend `test/auth_redirect_test.dart`: guest on `/events` and `/events/abc` → null; signed-in on `/events` → null; existing cases unchanged.

### Task 15: Feed bloc + screens
- **ACTION**: create `lib/bloc/events_feed/{events_feed_bloc,events_feed_event,events_feed_state}.dart` (sibling-file style as `session_detail`), `lib/widgets/events_feed_view.dart`, `lib/screens/events_feed_screen.dart`, `lib/screens/public_event_screen.dart`.
- **IMPLEMENT**: events `EventsFeedStarted({lat,lng})`, `EventsFeedFiltersChanged(FeedFilters)`; state `EventsFeedLoaded(all, visible, filters, districts)` (Equatable). Bloc takes `SessionService`, optional `userGender`, `userAge`; loads `getPublicEvents()`, applies `applyFeedFilters`, then distance sort (GEOLOCATION_SORT). `EventsFeedView` renders filters (sport from `kSports`, district from `distinctDistricts`, day part, max price, format text) and cards (title, sport icon, district, date via `DateFormat`, `S/ price`, `playerCount/maxPlayers` cupos). Card tap: signed in → existing `SessionDetailScreen(sessionId)` via `Navigator.push`; guest → `context.go('/events/${id}')` (use `context.isAuthenticated`). `PublicEventScreen` streams `streamPublicEvent`, shows details, organizer `groupName`, seats `playerCount/maxPlayers`, and a button "Regístrate para unirte" → `context.go('/registration')`. No `players[]` anywhere.
- **MIRROR**: location loading in `sessions_screen.dart:33-100` (extract to a small shared helper or keep inline); `BlocBuilder` usage per CLAUDE.md.
- **GOTCHA**: `context.currentUser!` in `SessionDetailScreen` crashes for guests — guests must never reach it. Widgets dispatch events only; no Firebase in widgets.
- **VALIDATE**: manual check in Task 20 (no mocking lib in pubspec, so no bloc tests unless one is added).

### Task 16: Routes
- **ACTION**: `lib/main.dart` GoRouter: add top-level `GoRoute(path: '/events', name: 'events', builder: → EventsFeedScreen(), routes: [GoRoute(path: ':id', name: 'event-detail', builder: → PublicEventScreen(eventId: state.pathParameters['id']!))])` next to `/welcome`. Change `/sessions` builder to `EventsFeedScreen()` and delete `sessions_screen.dart` if nothing else references it (grep first).
- **VALIDATE**: `flutter analyze`; a guest opens `/events` without redirect.

### Task 17: Create-session district and format
- **ACTION**: `LocationResult` gets `final String? district;`. In `location_picker.dart` `onNext` (`:100-110`) compute `district` from `result.addressComponents`: first component whose `types` contains `'locality'`, else `'sublocality'`, else `'administrative_area_level_3'`, using `longName`; trim; null if none. In `create_session_screen.dart` store `_locationDistrict`, set it in `onLocationSelected` (`:296-303`), add an optional `TextFormField` "Formato (opcional)" (`_formatController`, dispose it) in the details step near the gender field (`:495-520`), and pass `district`/`format` into `SessionTemplateModel` (`:218-233`). Trim format; empty → null.
- **GOTCHA**: verified in `map_location_picker-4.0.1` that the result's `addressComponents` have `longName` and `types` (`google_maps_apis` legacy `AddressComponent`). In Peru, districts usually come back as `locality`.
- **VALIDATE**: unit-test the extraction as a pure helper `String? districtFromComponents(List<({String name, List<String> types})>)` in `lib/utils/district_utils.dart`; manual check creating an event.

### Task 18: Cancel flow in detail bloc and screen
- **ACTION**: `session_detail_event.dart`: rename `LeaveSession` → `CancelParticipation`. `session_detail_state.dart`: add `SessionDetailCancelled(session, refunded, amount)`. Bloc: replace `_onLeaveSession` with `_onCancelParticipation` → emit `SessionDetailProcessing(action: 'cancelling')`, call `sessionService.cancelParticipation(sessionId)`, emit `SessionDetailCancelled`; on error → `SessionDetailError`. The Firestore stream then emits `Loaded` (`_onUpdateSessionState`).
- Screen (`session_detail_screen.dart`): in the joined branch add below "Ver mi Ticket" an `OutlinedButton` "Cancelar mi cupo" → dialog that shows "Reembolso completo de S/ X" when `isRefundable(session.eventDate, DateTime.now())`, else "Si cancelas ahora no recibirás reembolso", then dispatches `CancelParticipation`. In the `BlocConsumer` listener: on `SessionDetailCancelled` dispatch `AuthRefreshUserRequested` (as at `:58`) and show a snackbar ("Reembolso acreditado" / "Cupo cancelado, sin reembolso"). Replace the join dialog warning at `:571` with: "Puedes cancelar hasta 24 horas antes del evento y recibir reembolso completo."
- **MIRROR**: existing `Processing`/`Error` handling and the `_wasProcessingJoin` flag; drive the cancel feedback from `SessionDetailCancelled`, not a flag.
- **GOTCHA**: `SessionDetailBloc` is built inline in the screen with `SessionService()`; keep that style. Remove every reference to `LeaveSession` (grep).
- **VALIDATE**: `flutter analyze`; manual cancel in Task 20.

### Task 19: Home, landing and docs
- **ACTION**: `home_screen.dart` (`:240-262`): replace the carousel + groups `Column` so the feed (`EventsFeedView`) comes first and the groups list sits below under a "Mis grupos" header; keep `_buildGroupsList`, the empty state and join-by-code. `landing_screen.dart`: add a button "Ver eventos" → `context.go('/events')` near the existing CTAs (`:181,243-256`). Update `docs/ARCHITECTURE.md` (§4 routes table adds `/events`, `/events/:id`; §7 `publicEvents` and ticket `cancelled`/`pricePaid`; §8 new cancel flow and feed; §9 services; §14 pitfalls: leave is gone, rules now in repo, trigger region; bump "Last reviewed"), mirror the summary in `CLAUDE.md` and `AGENTS.md` (keep identical), and add "Cloud Functions" and "Deploy order" sections to `README.md`.
- **VALIDATE**: `grep -rn "LeaveSession\|leaveSession" lib docs` returns nothing.

### Task 20: Verification and deploy runbook (owner)
Local, with emulators: `firebase emulators:start --only firestore,functions,auth`; seed one public and one private event and one user with credits `20.00`.
Deploy order (the owner runs it by hand from the repo root):
```bash
npx -y firebase-tools@latest deploy --only firestore:rules,firestore:indexes   # 1. rules (additive)
npx -y firebase-tools@latest deploy --only functions                           # 2. functions
(cd functions && npx tsx scripts/backfillPublicEvents.ts)                      # 3. backfill publicEvents
flutter build web && npx -y firebase-tools@latest deploy --only hosting       # 4. web app
```
Mobile apps ship after step 4.

---

## Testing Strategy

### Unit Tests

| Test | Input | Expected | Edge? |
|---|---|---|---|
| `isRefundable` (TS and Dart) | event − now = exactly 24 h | true | boundary |
| same | 24 h − 1 ms; past event | false | yes |
| `refundDocId` | session `s`, uid `u`, token `t` | `refund_s_u_t` | |
| `buildPublicEvent` | private event | null | yes |
| same | public event with `players` | no `players` key | yes |
| `dayPart` | 04:59 / 05:00 / 11:59 / 12:00 / 17:59 / 18:00 Lima | night / morning / morning / afternoon / afternoon / night | boundaries |
| `applyFeedFilters` | district "Miraflores " vs "miraflores" | match | accent/case |
| same | session without district + district filter | excluded | yes |
| same | guest (no gender/age) | not filtered by gender/age | |
| `authRedirect` | guest `/events`, `/events/x`; signed-in `/events` | null | |
| `TicketModel.toMap` | with `pricePaid` | has key; no `cancelledAt`/`refunded` | rules |
| `districtFromComponents` | `locality` present / only `sublocality` / none | name / name / null | |

### Edge Cases Checklist
- [ ] Cancel twice (retry) → no double refund
- [ ] Cancel after rejoin → second refund works (new token)
- [ ] Cancel with `used` ticket → rejected
- [ ] User not in `players[]` → rejected
- [ ] Legacy ticket without `pricePaid` → falls back to the `spend` ledger row
- [ ] Legacy player with no ticket → seat freed, refund only if a `spend` row exists
- [ ] Cancel with <24 h → seat freed, no credit, ticket `cancelled`
- [ ] Unauthenticated call → `unauthenticated`
- [ ] Concurrent join + cancel on the last seat
- [ ] Guest cannot read `liveSessions` (rules emulator) but can read `publicEvents`
- [ ] Old events without `district`/`format` still listed

---

## Validation Commands

### Static Analysis
```bash
flutter analyze
(cd functions && npm run build)
```
EXPECT: only the pre-existing `include_file_not_found` info; zero TS errors.

### Unit Tests
```bash
flutter test
(cd functions && npm test)
```
EXPECT: all pass, including the existing `landing_screen_test.dart` and `auth_redirect_test.dart`.

### Manual Validation
```bash
flutter run -d chrome
```
- [ ] Signed out: landing → "Ver eventos" → `/events` loads, filters work, detail shows no players, button goes to `/registration`
- [ ] Signed in: Home shows feed first, groups below
- [ ] Join an event (≥24 h away) → balance drops by cost → "Cancelar mi cupo" says "Reembolso completo" → balance restored, ticket shows "Cancelado", seat count drops, `creditHistory` has one `refund` row
- [ ] Join an event starting in <24 h → cancel says "Sin reembolso" → balance unchanged, seat freed
- [ ] Cancelled ticket QR is rejected by `/validate-ticket`
- [ ] Rejoin after cancel works (rule allows overwriting own ticket)
- [ ] Create event: district shows in the feed; format optional

---

## Acceptance Criteria
- [ ] All tasks completed; deploy order documented in README
- [ ] Tests written and passing (Dart + functions)
- [ ] No new analyzer or TS errors
- [ ] Guests read only `publicEvents`; `players[]` never exposed
- [ ] Refund is idempotent and server-side
- [ ] `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` updated and consistent

## Completion Checklist
- [ ] BLoC-only: no Firebase calls in new widgets
- [ ] Credits go through `formatCredits` (Dart) / `toFixed(2)` (TS)
- [ ] Sport values come from `kSports`; no football-specific wording or fields
- [ ] Spanish product copy; English docs
- [ ] No hand edits to `firebase_options.dart` or Google service files
- [ ] `LeaveSession` / `leaveSession` fully removed

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Trigger region ≠ Firestore location → deploy fails | Low | Medium | verified: DB is in `southamerica-east1`; use the same region |
| `cloud_functions` version conflict with `firebase_core ^5` | Medium | Low | `flutter pub add`, accept resolver |
| Rules edit breaks join or approval | Low | High | additive only; `pricePaid` optional; test in emulator; owner deploys rules first and can roll back from the console |
| Client can still edit its own `credits` and any `liveSessions` | High (pre-existing) | High | out of scope; first follow-up: move join and approval server-side and tighten rules |
| `publicEvents` stale if the trigger fails | Low | Medium | backfill script is re-runnable |
| District missing for non-Google results | Medium | Low | filter tolerates null |
| Guest reaches `SessionDetailScreen` (crash on `currentUser!`) | Low | Medium | guest cards route to `/events/:id` only |

## Notes
- `docs/ARCHITECTURE.md` says `SessionDetailBloc` treats only `group.createdBy` as admin; unchanged.
- The ticket rule lets a holder overwrite their own ticket even when `used` (pre-existing hole); noted for the server-side follow-up, not fixed here.
- District filter options come from fetched events, so they cover all of Peru without a fixed list.
- Confidence for one-pass implementation: 7/10. Main unknowns: DB region, `cloud_functions` version, exact Home layout.
