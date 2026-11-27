# Plan: Document correction (30-day limit)

## Summary
A player with a DNI/CE on their account can correct it from the profile, at most once every 30 days since the last change. The change goes through a new callable, `changeDocument`, which in one transaction checks the cooldown, claims the new uniqueness lock, releases the old one and updates the profile. Clients can never write the cooldown field. Tickets already issued keep the old document snapshot.

## User Story
As a player who typed my DNI/CE wrong, I want to fix it from my profile, so that my tickets show the right document at the door without asking support.

## Problem → Solution
Rules forbid any change to `documentType` / `documentNumber` after the first one, so a typo is permanent → a server-side callable swaps the document and its lock atomically, rate-limited to once per 30 days.

## Metadata
- **Complexity**: Medium
- **Source PRD**: `.claude/prds/event-join-identity-document.prd.md`
- **PRD Phase**: Milestone 2 — Document correction
- **Estimated Files**: 20 (5 new, 15 updated)

---

## UX Design

### Before
```
Perfil
  Saldo / Avisos / Política de asistencia / Editar perfil / Historial
  (no place to see or change the document)
```

### After
```
Perfil
  ...
  Documento de identidad          DNI 12345678        [>]
    subtitle when locked: "... · podrás corregirlo desde el 27 de diciembre"

Tap, correction allowed:
  Dialog "Corregir documento"
    "Solo puedes cambiarlo una vez cada 30 días. Tus tickets actuales
     conservan el documento anterior."
    (DNI | Carnet de extranjería) [Número de documento]  (prefilled)
    [Cancelar] [Guardar]
      - saved  -> snackbar "Documento actualizado", profile refreshed
      - taken  -> inline error: registered to another account + ricardo@cotillo.dev
      - locked -> inline error with the date it unlocks
Tap, cooldown active: snackbar "Podrás corregir tu documento desde el {fecha}."
Legacy account (no document): subtitle "Sin documento"; tap opens the Milestone 1 add dialog.
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Profile screen | No document row | "Documento de identidad" tile | Shows type + number, or "Sin documento" |
| `askIdentityDocument` | Add-only, empty form | `correcting: true` mode: prefilled, 30-day copy, calls `changeDocument` | Same dialog widget, one new parameter |
| `users/{uid}` rules | Document frozen after the first claim | Same, plus `documentChangedAt` frozen for clients | The callable (Admin SDK) is the only writer |
| New callable | n/a | `changeDocument` | Region `southamerica-east1` like the rest |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `firestore.rules` | 36-100, 125-150 | `isValidNewUser`, `documentFirstClaim`, `users` update rule, `documents/` lock rules |
| P0 | `functions/src/reviewCreditPurchase.ts` | all | Smallest callable: auth check, validation, transaction, return shape |
| P0 | `functions/src/joinPolicy.ts` | 56-66 | `hasIdentityDocument`, reuse it |
| P0 | `functions/src/attendancePolicy.ts` | 1-50 | Pure policy constants + Spanish date helper `fmtDate` (private today) |
| P0 | `lib/services/session_service.dart` | 640-670 | Client callable pattern (`httpsCallable` + `callableError`) |
| P0 | `lib/widgets/identity_document_dialog.dart` | all | Dialog to extend |
| P0 | `lib/bloc/identity_document/identity_document_cubit.dart` | all | Cubit to extend |
| P1 | `lib/utils/attendance_policy.dart` | all | Client mirror of server policy constants + `blockedUntilLabel` date format |
| P1 | `lib/models/user_model.dart` | 62-185 | `blockedUntil` is the model for a server-written timestamp: parsed in `fromMap`, absent from `toMap` |
| P1 | `lib/screens/profile_screen.dart` | 85-140, 175-215 | Tile list; `_AttendanceTile` / `_Tile` patterns |
| P1 | `lib/utils/document.dart` | all | `DocumentType`, `normalizeDocument`, `validateDocument`, `documentKey` |
| P2 | `functions/emulator-tests/attendance.test.mjs` | 1-40 | Emulator test header, `run()` helper, `t()` runner |
| P2 | `functions/emulator-tests/organizer.test.mjs` | 30-40 | `rejects(p, code, msg)` helper to copy |
| P2 | `functions/emulator-tests/rules.test.mjs` | 15-40, 145-170 | Rules seeding + document tests |
| P2 | `functions/test/attendancePolicy.test.ts` | all | Pure policy test style |
| P2 | `test/identity_document_cubit_test.dart` | all | Fake service + state assertions to extend |

## External Documentation
No external research needed — feature uses established internal patterns (callable + transaction, server-written timestamp).

---

## Patterns to Mirror

### NAMING_CONVENTION
```ts
// SOURCE: functions/src/reviewCreditPurchase.ts:12 and functions/src/attendancePolicy.ts:4-12
export const reviewCreditPurchase = onCall(async (request) => { ... });
export const WINDOW_MS = 90 * DAY;
export const BLOCK_MS = 14 * DAY;
```
New server files: `functions/src/documentPolicy.ts` (pure), `functions/src/changeDocument.ts` (callable). Constant: `DOCUMENT_COOLDOWN_MS`.

### POLICY_PATTERN (pure, testable)
```ts
// SOURCE: functions/src/attendancePolicy.ts:21-27
export const isBlocked = (blockedUntilMs: number | undefined, nowMs: number): boolean =>
  typeof blockedUntilMs === 'number' && blockedUntilMs > nowMs;
```

### ERROR_HANDLING (server)
```ts
// SOURCE: functions/src/reviewCreditPurchase.ts:13-20, 38-40
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }
  ...
    throw new HttpsError('invalid-argument', 'Solicitud inválida.');
  ...
    throw new HttpsError('failed-precondition', 'No encontramos al usuario de esta solicitud.');
```
`callableError` (`lib/utils/error_message.dart`) passes `failed-precondition` / `invalid-argument` Spanish copy to the UI as `Exception(msg)`; `userMessage` strips the prefix.

### CLIENT_CALLABLE
```dart
// SOURCE: lib/services/session_service.dart:648-656
  Future<String> joinSession(String sessionId) async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'southamerica-east1',
      ).httpsCallable('joinSession').call({'sessionId': sessionId});
      return (result.data as Map)['ticketId'] as String;
    } on FirebaseFunctionsException catch (e) {
      throw callableError(e);
    }
  }
```

### SERVER_WRITTEN_TIMESTAMP (model and rules)
```dart
// SOURCE: lib/models/user_model.dart:176  (and absent from toMap, 119-135)
      blockedUntil: (map['blockedUntil'] as Timestamp?)?.toDate(),
```
```
// SOURCE: firestore.rules (isValidNewUser and the users update rule)
        && !('blockedUntil' in d)
        && request.resource.data.get('blockedUntil', null) == resource.data.get('blockedUntil', null)
```

### LOGGING_PATTERN
No logging in callables of this kind. Add none.

### TEST_STRUCTURE (emulator)
```js
// SOURCE: functions/emulator-tests/attendance.test.mjs:22-30
const run = (fn, uid, data) => fn.run({auth: {uid, token: {}}, data, rawRequest: {}, acceptsStreaming: false});
async function t(name, fn) {
  try { await fn(); results.push(true); console.log('PASS', name); }
  catch (e) { results.push(false); console.log('FAIL', name, '\n   ', e.message); }
}
```

### TEST_STRUCTURE (cubit)
```dart
// SOURCE: test/identity_document_cubit_test.dart:6-22
class _FakeUserService implements UserService {
  Object? error;
  final claims = <(String, DocumentType, String)>[];
  @override
  Future<void> claimDocument(String uid, DocumentType type, String number) async { ... }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `functions/src/documentPolicy.ts` | CREATE | Cooldown, format validation, lock key, Spanish copy: pure and unit-tested |
| `functions/src/changeDocument.ts` | CREATE | The callable |
| `functions/src/index.ts` | UPDATE | Export `changeDocument` |
| `functions/src/attendancePolicy.ts` | UPDATE | Export the existing `fmtDate` (one word) to reuse the Spanish date format |
| `functions/package.json` | UPDATE | Add the new emulator test to `test:emulator` |
| `functions/test/documentPolicy.test.ts` | CREATE | Unit tests for the policy |
| `functions/emulator-tests/changeDocument.test.mjs` | CREATE | Callable end to end on the emulator |
| `functions/emulator-tests/rules.test.mjs` | UPDATE | Clients cannot touch `documentChangedAt` |
| `firestore.rules` | UPDATE | Freeze `documentChangedAt` for clients |
| `lib/utils/document.dart` | UPDATE | Cooldown constant + `nextDocumentChange` |
| `lib/models/user_model.dart` | UPDATE | `documentChangedAt` field (read-only) |
| `lib/services/user_service.dart` | UPDATE | `changeDocument(type, number)` calls the callable |
| `lib/bloc/identity_document/identity_document_cubit.dart` | UPDATE | `change(type, number)` |
| `lib/widgets/identity_document_dialog.dart` | UPDATE | `correcting` mode |
| `lib/screens/profile_screen.dart` | UPDATE | "Documento de identidad" tile |
| `test/document_test.dart` | UPDATE | Cooldown helper tests |
| `test/user_model_document_test.dart` | UPDATE | `documentChangedAt` parsing |
| `test/identity_document_cubit_test.dart` | UPDATE | `change` cases |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATE | Callable, field, rule, deploy order (keep CLAUDE.md and AGENTS.md in sync) |

## NOT Building

- Any change to the milestone 1 gate (`joinSession` / `joinWaitlist`) or the first-claim rule.
- Updating the document snapshot on existing tickets (decided: they keep the old one).
- An organizer or support tool to override the cooldown (support edits Firestore by hand if needed).
- External validation (RENIEC etc.), document photos.
- A notification or email when the document changes.
- Changing the document from the "Editar perfil" form: it stays a separate tile and dialog.

---

## Step-by-Step Tasks

### Task 1: Server policy (`documentPolicy.ts`)
- **ACTION**: Create `functions/src/documentPolicy.ts`.
- **IMPLEMENT**:
  ```ts
  import {fmtDate} from './attendancePolicy';

  const DAY = 86_400_000;
  /** Minimum time between two document changes. Keep equal to lib/utils/document.dart. */
  export const DOCUMENT_COOLDOWN_MS = 30 * DAY;

  /** Same rules as lib/utils/document.dart and firestore.rules. */
  export const normalizeDocument = (s: string): string => s.trim().toUpperCase();

  export const isValidDocument = (type: unknown, number: unknown): boolean =>
    typeof number === 'string' &&
    ((type === 'dni' && /^[0-9]{8}$/.test(number)) ||
     (type === 'ce' && /^[A-Z0-9]{9,12}$/.test(number)));

  /** Lock id in `documents/`. */
  export const documentKey = (type: string, number: string): string => `${type}_${number}`;

  /** When the next change is allowed, or null if now (no previous change counts as allowed). */
  export const nextChangeMs = (changedAtMs: number | undefined, nowMs: number): number | null =>
    typeof changedAtMs === 'number' && changedAtMs + DOCUMENT_COOLDOWN_MS > nowMs
      ? changedAtMs + DOCUMENT_COOLDOWN_MS
      : null;

  export const cooldownMessage = (untilMs: number): string =>
    `Solo puedes cambiar tu documento una vez cada 30 días. Podrás hacerlo desde el ${fmtDate(untilMs)}.`;

  export const DOCUMENT_TAKEN_MESSAGE =
    'Este documento ya está registrado en otra cuenta, así que no puedes usarlo. ' +
    'Si es tuyo, escríbenos a ricardo@cotillo.dev.';
  ```
- **MIRROR**: POLICY_PATTERN, NAMING_CONVENTION.
- **IMPORTS**: `fmtDate` from `./attendancePolicy` (Task 2).
- **GOTCHA**: A missing `documentChangedAt` means "never changed through the callable" → allowed. That covers accounts created with a document and legacy accounts that just did the first claim (PRD: the first correction after adding is allowed and starts the clock).
- **VALIDATE**: `cd functions && npm test` (Task 6).

### Task 2: Export `fmtDate`
- **ACTION**: In `functions/src/attendancePolicy.ts` change `const fmtDate` to `export const fmtDate`.
- **GOTCHA**: Nothing else changes; `fmtDate` formats in `America/Lima`.
- **VALIDATE**: `cd functions && npm run build`.

### Task 3: The callable (`changeDocument.ts`)
- **ACTION**: Create `functions/src/changeDocument.ts`; export it from `functions/src/index.ts` (`export {changeDocument} from './changeDocument';`).
- **IMPLEMENT**:
  ```ts
  export const changeDocument = onCall(async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    const uid = request.auth.uid;
    const type = request.data?.documentType;
    const number = typeof request.data?.documentNumber === 'string'
      ? normalizeDocument(request.data.documentNumber) : null;
    if (!isValidDocument(type, number)) {
      throw new HttpsError('invalid-argument', 'El documento no tiene un formato válido.');
    }

    const db = getFirestore();
    const userRef = db.doc(`users/${uid}`);
    const newKey = documentKey(type, number!);
    const newLockRef = db.doc(`documents/${newKey}`);

    return db.runTransaction(async (tx) => {
      // ---- reads (all before any write) ----
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new HttpsError('failed-precondition', 'No encontramos tu perfil.');
      const user = userSnap.data()!;
      if (!hasIdentityDocument(user)) {
        throw new HttpsError('failed-precondition', 'Primero registra tu documento al unirte a un evento.');
      }
      const oldKey = documentKey(user.documentType, user.documentNumber);
      if (oldKey === newKey) throw new HttpsError('failed-precondition', 'Ese ya es tu documento.');

      const until = nextChangeMs(user.documentChangedAt?.toMillis?.(), Date.now());
      if (until !== null) throw new HttpsError('failed-precondition', cooldownMessage(until));

      const oldLockRef = db.doc(`documents/${oldKey}`);
      const [newLock, oldLock] = await Promise.all([tx.get(newLockRef), tx.get(oldLockRef)]);
      if (newLock.exists) throw new HttpsError('failed-precondition', DOCUMENT_TAKEN_MESSAGE);

      // ---- writes ----
      // Release the old lock only if it is this user's (a missing or foreign lock is left alone).
      if (oldLock.exists && oldLock.get('uid') === uid) tx.delete(oldLockRef);
      tx.set(newLockRef, {uid, createdAt: FieldValue.serverTimestamp()});
      tx.update(userRef, {
        documentType: type, documentNumber: number, documentChangedAt: FieldValue.serverTimestamp(),
      });
      return {documentType: type, documentNumber: number};
    });
  });
  ```
- **MIRROR**: ERROR_HANDLING (server), `reviewCreditPurchase.ts` shape.
- **IMPORTS**: `onCall, HttpsError` from `firebase-functions/v2/https`; `getFirestore, FieldValue` from `firebase-admin/firestore`; `hasIdentityDocument` from `./joinPolicy`; policy helpers from `./documentPolicy`.
- **GOTCHA**:
  - The cooldown check goes before the lock read so a locked user learns the date, not "taken".
  - The same-key case is caught by `oldKey === newKey`; any other key is a different number.
  - Admin SDK bypasses rules, so the lock `delete` works even though clients can never delete locks.
  - Transactions retry: no side effects outside `tx`.
  - Do NOT touch `tickets`: they keep the old snapshot (PRD decision).
  - Two users racing for the same new number: both read `newLock` missing, the second commit's transaction retries and then sees the lock → `taken`. Cover with a test.
- **VALIDATE**: emulator test (Task 8) and `cd functions && npm run build`.

### Task 4: Rules — freeze `documentChangedAt` for clients
- **ACTION**: In `firestore.rules`:
  - `isValidNewUser`: add `&& !('documentChangedAt' in d)`.
  - `users/{userId}` update: add `&& request.resource.data.get('documentChangedAt', null) == resource.data.get('documentChangedAt', null)` next to the `blockedUntil` line, with the comment "documentChangedAt (30-day document cooldown) is written only by the changeDocument function."
- **MIRROR**: SERVER_WRITTEN_TIMESTAMP (rule side).
- **GOTCHA**:
  - Without this, a client could delete the field and skip the 30-day limit.
  - Applies to the superUser branch too (it ANDs with the rest).
  - The first-claim path leaves the field untouched, so it keeps passing.
  - Per CLAUDE.md: diff `firestore.rules` against the console before deploying.
- **VALIDATE**: rules emulator tests (Task 9).

### Task 5: Client policy, model, service
- **ACTION A** (`lib/utils/document.dart`): append
  ```dart
  /// Minimum time between two document changes. Keep equal to
  /// functions/src/documentPolicy.ts.
  const int kDocumentCooldownDays = 30;

  /// When the next change is allowed, or null when it is allowed now.
  DateTime? nextDocumentChange(DateTime? changedAt, DateTime now) {
    if (changedAt == null) return null;
    final next = changedAt.add(const Duration(days: kDocumentCooldownDays));
    return next.isAfter(now) ? next : null;
  }
  ```
- **ACTION B** (`lib/models/user_model.dart`): add `final DateTime? documentChangedAt;` (doc comment: "Last document correction; written only by the `changeDocument` function"), constructor param `this.documentChangedAt`, and in `fromMap` `documentChangedAt: (map['documentChangedAt'] as Timestamp?)?.toDate(),`. Do **not** add it to `toMap` (rules reject it on create).
- **ACTION C** (`lib/services/user_service.dart`): add
  ```dart
  /// Corrects the account's document via the `changeDocument` function
  /// (30-day limit, lock swap). Error messages are the server's Spanish copy.
  Future<void> changeDocument(DocumentType type, String number) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('changeDocument')
          .call({'documentType': type.name, 'documentNumber': normalizeDocument(number)});
    } on FirebaseFunctionsException catch (e) {
      throw callableError(e);
    }
  }
  ```
- **MIRROR**: CLIENT_CALLABLE, SERVER_WRITTEN_TIMESTAMP.
- **IMPORTS**: `package:cloud_functions/cloud_functions.dart`, `package:proplay/utils/error_message.dart` in `user_service.dart`.
- **GOTCHA**: `UserModel` has other constructors in tests (`_user(...)` helpers): the new param is optional, nothing breaks.
- **VALIDATE**: `flutter analyze lib test`; Task 11 tests.

### Task 6: Server unit tests
- **ACTION**: Create `functions/test/documentPolicy.test.ts` (style of `attendancePolicy.test.ts`).
- **IMPLEMENT**:
  - `nextChangeMs`: `undefined` → null; changed 29 days ago → `changedAt + 30d`; exactly 30 days ago → null; 31 days ago → null.
  - `isValidDocument`: `('dni','12345678')` true; `('dni','1234567')`, `('dni','1234567A')`, `('ce','A1234567')`, `('ce','ABC1234567890')`, `('passport','X')`, `('dni', 12345678)` false; `('ce','AB1234567')` true.
  - `normalizeDocument(' ab1234567 ')` = `'AB1234567'`; `documentKey('dni','12345678')` = `'dni_12345678'`.
  - `cooldownMessage(...)` mentions `30 días`.
- **VALIDATE**: `cd functions && npm test`.

### Task 7: Register the emulator test
- **ACTION**: In `functions/package.json` `test:emulator`, add `node functions/emulator-tests/changeDocument.test.mjs` to the first `&&` chain (after `attendance.test.mjs`, before `rules.test.mjs`).
- **VALIDATE**: runs in Task 8.

### Task 8: Emulator test for the callable
- **ACTION**: Create `functions/emulator-tests/changeDocument.test.mjs` (header like `attendance.test.mjs`; `rejects` helper from `organizer.test.mjs`).
- **IMPLEMENT** helpers: `user(uid, extra)` seeds `users/{uid}` with `documentType: 'dni', documentNumber`, plus the matching lock `documents/dni_{number}`; use a fresh number per test (`String(10000000 + n)`).
- **IMPLEMENT** tests:
  - Success: old lock deleted, new lock `{uid}` exists, user has the new type/number and `documentChangedAt` set, return value matches.
  - Second change right after → `failed-precondition` matching `/30 días/`; nothing changed.
  - After backdating `documentChangedAt` to 31 days ago → succeeds; to 29 days ago → rejected.
  - Account with a document and no `documentChangedAt` (registered or first-claimed) changes immediately (PRD: first correction is free).
  - Number already locked by another user → `failed-precondition` matching `/ricardo@cotillo.dev/`; the user's document and both locks unchanged.
  - Same document as current → `failed-precondition`.
  - Legacy user (`documentType: ''`) → `failed-precondition`.
  - Invalid formats (`'1234'`, type `'passport'`, missing number) → `invalid-argument`; no auth → `unauthenticated`.
  - Lowercase CE input is normalized (`'ab1234567'` stores `'AB1234567'`).
  - CE ↔ DNI switch works and swaps the lock key.
  - Existing ticket keeps the old `userDocumentNumber` after the change.
  - Race: two users change to the same new number via `Promise.allSettled` → exactly one fulfilled, one rejected `failed-precondition`; the lock belongs to the winner.
  - Old number is claimable by someone else after the change (lock released): another user's change to it succeeds.
- **GOTCHA**: backdating writes `Timestamp.fromMillis(Date.now() - 31 * D)` with the Admin SDK.
- **VALIDATE**: `cd functions && npm run test:emulator` (needs Java).

### Task 9: Rules tests
- **ACTION**: In `functions/emulator-tests/rules.test.mjs`, near the `[theirs]` document tests (≈165). Seed (rules disabled) a user `changer` with a document and `documentChangedAt: Timestamp.now()`.
- **IMPLEMENT**:
  - Client sets `documentChangedAt` to another value → denied.
  - Client deletes `documentChangedAt` (`deleteField()`) → denied.
  - Client adds `documentChangedAt` to a user that has none → denied.
  - Register (batch with lock) including `documentChangedAt` → denied.
  - A normal profile update that leaves the field alone still succeeds (existing tests keep passing).
- **VALIDATE**: `cd functions && npm run test:emulator`.

### Task 10: Cubit + dialog + profile tile
- **ACTION A** (`identity_document_cubit.dart`): add
  ```dart
  /// Corrects an existing document (changeDocument: 30-day limit, server errors in Spanish).
  Future<void> change(DocumentType type, String number) async {
    emit(const IdentityDocumentState(status: IdentityDocumentStatus.saving));
    try {
      await _userService.changeDocument(type, number);
      emit(const IdentityDocumentState(status: IdentityDocumentStatus.saved));
    } catch (e) {
      emit(IdentityDocumentState(status: IdentityDocumentStatus.failure, error: userMessage(e)));
    }
  }
  ```
  Update the class doc comment ("Saves or corrects…").
- **ACTION B** (`identity_document_dialog.dart`): `Future<bool> askIdentityDocument(BuildContext context, {bool correcting = false})`; pass `correcting` to `_IdentityDocumentDialog`. In the state: when `correcting`, initialize `_type` and `_controller.text` from `context.currentUser` in `initState` (`DocumentType.values.byName(user.documentType)`, guarded by `hasDocument`); title "Corregir documento"; body text "Solo puedes cambiarlo una vez cada 30 días. Tus tickets actuales conservan el documento anterior."; save button "Guardar" (instead of "Guardar y continuar"); `_save` calls `change` when correcting, `save` otherwise. Everything else (listener, error text, `AuthRefreshUserRequested`) unchanged.
- **ACTION C** (`profile_screen.dart`): add `_DocumentTile` between `_AttendanceTile` and "Editar perfil":
  ```dart
  class _DocumentTile extends StatelessWidget {
    const _DocumentTile({required this.user});
    final UserModel user;

    @override
    Widget build(BuildContext context) {
      final next = nextDocumentChange(user.documentChangedAt, DateTime.now());
      final subtitle = !user.hasDocument
          ? 'Sin documento'
          : next == null
          ? '${user.documentType.toUpperCase()} ${user.documentNumber}'
          : '${user.documentType.toUpperCase()} ${user.documentNumber} · '
                'podrás corregirlo desde el ${blockedUntilLabel(next)}';
      return ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: const Text('Documento de identidad'),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          if (!user.hasDocument) {
            await askIdentityDocument(context);
          } else if (next != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Podrás corregir tu documento desde el ${blockedUntilLabel(next)}.'),
            ));
          } else if (await askIdentityDocument(context, correcting: true) && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Documento actualizado')),
            );
          }
        },
      );
    }
  }
  ```
  Insert `_DocumentTile(user: user),` in the `ListView`.
- **MIRROR**: `_AttendanceTile` / `_Tile` in the same file; CLAUDE.md UI rules (theme/`AppColors`, no Firebase calls in widgets, Spanish copy).
- **IMPORTS** (`profile_screen.dart`): `package:proplay/models/user_model.dart`, `package:proplay/utils/document.dart`, `package:proplay/widgets/identity_document_dialog.dart`. `blockedUntilLabel` is already imported via `attendance_policy.dart` (it formats any date; reuse, do not add a second formatter).
- **GOTCHA**:
  - The tile reads `user` from `context.watchUser`, so it rebuilds after `AuthRefreshUserRequested`.
  - `context.mounted` after every `await`.
  - Client-side cooldown is display only; the server decides.
  - The Spanish message from the server (taken, cooldown) shows inline in the dialog through `userMessage`.
- **VALIDATE**: `flutter analyze lib test`; Manual Validation.

### Task 11: Client tests
- **ACTION**:
  - `test/document_test.dart`: `nextDocumentChange(null, now)` null; changed 29 days ago → date 1 day ahead; exactly 30 days ago → null; 31 days → null.
  - `test/user_model_document_test.dart`: `UserModel.fromMap({...required fields..., 'documentChangedAt': Timestamp.fromDate(d)})` parses to `d`; missing → null; `toMap()` has no `documentChangedAt` key.
  - `test/identity_document_cubit_test.dart`: extend `_FakeUserService` with `changeDocument` (records calls, throws `error`); `change` success → `[saving, saved]` and the fake got `(DocumentType.dni, '12345678')`; failure shows `userMessage` (e.g. `Exception('Solo puedes cambiar…')` → that text).
- **GOTCHA**: `fromMap` needs `createdAt` as a `Timestamp`; build a minimal map or use `UserModel(...)` and `toMap()`.
- **VALIDATE**: `flutter test`.

### Task 12: Docs
- **ACTION**:
  - `docs/ARCHITECTURE.md`: §7 `users` table: add row `documentChangedAt` (timestamp, absent until the first correction; written only by `changeDocument`). `documents/` paragraph (≈337): add "A correction goes through the `changeDocument` callable: one transaction checks the 30-day cooldown, claims the new lock, releases the old one and updates the profile; clients cannot write `documentChangedAt`." Callables list (≈484): add `changeDocument`. Deploy-order note: this milestone follows the usual order (functions → hosting → rules): the callable works before the rules freeze, and the freeze only closes a client bypass of the cooldown.
  - `CLAUDE.md` and `AGENTS.md` (same text): add `changeDocument` (callable) to the Firebase paragraph's callable list ("corrects the identity document once every 30 days: swaps the `documents/` lock and sets `users.documentChangedAt`"); extend the identity-document line in "Do not regress": "correcting it is server-only (`UserService.changeDocument`); never write `documentChangedAt` from the client".
- **VALIDATE**: read the diff; CLAUDE.md and AGENTS.md match.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| `nextChangeMs` | `undefined` | null (allowed) | yes |
| `nextChangeMs` | 29 days ago / exactly 30 / 31 | blocked / allowed / allowed | yes (boundary) |
| `isValidDocument` | `'1234'`, passport, number not a string | false | yes |
| `nextDocumentChange` (Dart) | same boundaries | same | yes |
| `UserModel.fromMap` | `documentChangedAt` present / missing | date / null | |
| `UserModel.toMap` | any | no `documentChangedAt` key | yes |
| `IdentityDocumentCubit.change` | fake succeeds / throws | saving → saved / failure with the message | |
| `changeDocument` (emulator) | see Task 8 | success, cooldown, taken, same, legacy, invalid, auth, race, tickets kept | yes |
| rules (emulator) | client writes/deletes/creates `documentChangedAt` | denied | yes |

### Edge Cases Checklist
- [x] Empty / invalid input — callable `invalid-argument`; form validator on the client
- [x] Concurrent access — two users, same new number (race test)
- [x] Same user double-tap — the second call sees the cooldown
- [x] Network failure — `userMessage` maps `unavailable`
- [x] Permission denied — rules freeze the cooldown field
- [x] Legacy account (no document) calls the callable — refused, pointed to the join flow
- [x] Old lock missing or owned by someone else — left alone, change still completes
- [x] Tickets issued before the change keep their snapshot
- [x] Cooldown boundary (exactly 30 days)

---

## Validation Commands

### Static Analysis
```bash
flutter analyze lib test
```
EXPECT: no issues.

```bash
(cd functions && npm run build)
```
EXPECT: zero TypeScript errors.

### Unit Tests
```bash
flutter test
```
```bash
(cd functions && npm test)
```
EXPECT: all pass.

### Emulator Tests
```bash
(cd functions && npm run test:emulator)
```
EXPECT: all pass, including `changeDocument.test.mjs` and the new rules cases (needs Java).

### Browser Validation
```bash
flutter run -d chrome
```
EXPECT: feature works as in Manual Validation.

### Manual Validation
- [ ] Profile shows "Documento de identidad" with `DNI ########` (or "Sin documento" for a legacy test account).
- [ ] Tap with no previous change → dialog prefilled; fix the number → "Documento actualizado"; the tile now says it can be corrected from a date 30 days ahead.
- [ ] Tap again right away → snackbar with that date, no dialog.
- [ ] Enter a number used by another account → inline error with ricardo@cotillo.dev; nothing changes.
- [ ] A ticket created before the change still shows the old document when scanned; a new ticket shows the new one.
- [ ] Legacy test account: tap → the add dialog from milestone 1.
- [ ] Run against the emulator or a test project, never production data.

---

## Acceptance Criteria
- [ ] All tasks completed
- [ ] All validation commands pass
- [ ] Tests written and passing
- [ ] No type errors
- [ ] No new lint errors
- [ ] Matches UX design

## Completion Checklist
- [ ] Code follows discovered patterns
- [ ] Error handling matches codebase style
- [ ] Tests follow test patterns
- [ ] No Firebase calls in widgets
- [ ] No hard-coded colors
- [ ] Money untouched (no credit writes)
- [ ] Documentation updated (ARCHITECTURE.md, CLAUDE.md, AGENTS.md)
- [ ] No unnecessary scope additions
- [ ] Self-contained — no questions needed during implementation

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Client bypasses the cooldown by deleting or editing `documentChangedAt` | Medium if rules lag | Weakens the 30-day limit | Rules freeze the field (Task 4) + rules tests; deploy rules in the same release |
| Two accounts race for the same new number | Low | Wrong owner / double claim | Transaction reads both locks; race test asserts a single winner |
| Releasing the old lock lets someone else claim a number the owner mistyped away from | Low | Number reuse | Intended (it frees typos); tickets keep their snapshot |
| Abuse: change the document to evade a block or ban | Low | Weakens safety controls | 30-day limit; blocks are tied to the account (`users.blockedUntil`), not the document |
| App calls `changeDocument` before the function is deployed | Low | "Algo salió mal" | Deploy functions first (usual order); the tile only appears in the new hosting build |
| Live rules differ from the repo | Medium | Deploy overwrites console edits | Diff `firestore.rules` against the console before deploying (CLAUDE.md) |

## Notes
- Cooldown semantics (PRD): measured from the last change through this callable. Registration and the milestone 1 first claim do not set `documentChangedAt`, so the first correction is always allowed and starts the clock.
- `documentChangedAt` is written only by the callable; the client reads it to show the unlock date.
- Support contact in copy: ricardo@cotillo.dev (PRD decision), defined once on the server (`DOCUMENT_TAKEN_MESSAGE`) and once on the client (`IdentityDocumentCubit.takenMessage` for the milestone 1 claim).
