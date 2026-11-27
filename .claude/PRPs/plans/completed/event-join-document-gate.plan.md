# Plan: Document gate at join

## Summary
Players whose account has no identity document (legacy accounts, `documentType == ''`) must enter a DNI or CE before they can join an event or a waitlist. If the account already has one, it is reused and nothing changes for the player. The gate is enforced server-side in `joinSession` and `joinWaitlist`. The client asks for the document inline (a dialog) before joining, and saves it with the same uniqueness lock that registration uses. A narrow Firestore rules change allows this one first-time claim.

## User Story
As an organizer or door staff member, I want every player who joins my event to have a DNI or CE on their account, so that I can check who attends when I scan their QR ticket.

## Problem → Solution
Legacy accounts join events with no document, so their tickets have an empty `userDocumentNumber`, and the rules forbid adding one later → joining requires a document (server-enforced), and legacy players add theirs once in the join flow, atomically with a `documents/` lock.

## Metadata
- **Complexity**: Medium
- **Source PRD**: `.claude/prds/event-join-identity-document.prd.md`
- **PRD Phase**: Milestone 1 — Document gate at join
- **Estimated Files**: 18 (5 new, 13 updated)

---

## UX Design

### Before
```
Legacy player (no document) on /events/:id
  [Unirse]  -> confirm dialog "Se descontarán S/ 10" -> joined
             ticket: userDocumentNumber = ''  -> staff sees no DNI
  [Unirme a la lista de espera] -> on waitlist, no document
```

### After
```
Legacy player (no document) on /events/:id
  [Unirse] or [Unirme a la lista de espera]
     -> dialog "Tu documento de identidad"
          (DNI | Carnet de extranjería)  [Número de documento]
          "Por seguridad, los organizadores necesitan saber quién asiste.
           Lo pedimos una sola vez; el staff lo verá al escanear tu ticket."
          [Cancelar] [Guardar y continuar]
        - saved   -> profile refreshed -> normal join confirm / waitlist call
        - taken   -> inline error with support email, dialog stays open
        - cancel  -> nothing happens
Player with a document: unchanged (no dialog).
Old app build hitting the new server: join refused with a Spanish message.
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| "Unirse" button (session detail) | Opens the join confirm dialog | Opens the document dialog first when the account has none | Both call sites go through `_showJoinConfirmationDialog`, including the waitlist "confirm offered seat" path |
| "Unirme a la lista de espera" | Dispatches `JoinWaitlist` | Opens the document dialog first when the account has none | |
| `joinSession` / `joinWaitlist` callables | No document check | `failed-precondition` with Spanish copy when the account has no document | Safety net for old builds and direct calls |
| Registration | DNI/CE selector + field inline | Same UI, now the shared `DocumentFields` widget | No behavior change |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `firestore.rules` | 36-130 | `isValidNewUser`, `documentUnchanged`, `documents/{key}` create rule, `users/{userId}` update rule |
| P0 | `functions/src/joinSession.ts` | 46-70 | Retry branch, user doc read and block check: the gate goes right after the block check |
| P0 | `functions/src/waitlistCallables.ts` | 44-49 | Same spot in `joinWaitlist` |
| P0 | `lib/services/user_service.dart` | 1-58 | `DocumentAlreadyRegistered`, `createUserWithDocument` transaction to mirror |
| P0 | `lib/screens/session_detail_screen.dart` | 580-720, 880-930 | Join and waitlist buttons, `_showJoinConfirmationDialog` |
| P1 | `lib/screens/registration_screen.dart` | 25-75, 140-178 | Document selector + field to extract |
| P1 | `lib/utils/document.dart` | all | `DocumentType`, `normalizeDocument`, `validateDocument`, `documentKey` |
| P1 | `lib/bloc/credit_approval/credit_approval_cubit.dart` | 1-70 | Cubit + Equatable state shape to mirror |
| P1 | `functions/src/joinPolicy.ts` | all | Pure policy helpers + Spanish copy |
| P2 | `functions/emulator-tests/rules.test.mjs` | 15-40, 140-170 | Seeding with rules disabled, `as(uid)`, `[theirs]` document tests |
| P2 | `functions/emulator-tests/join.test.mjs` | 20-60 | `seed()`, `run()`, `rejects()` helpers |
| P2 | `functions/emulator-tests/waitlist.test.mjs` | 30-100 | `user()`, `fullEvent()` helpers |
| P2 | `test/credit_approval_cubit_test.dart` | 1-50 | Fake service with `noSuchMethod` |

## External Documentation
No external research needed — feature uses established internal patterns (Firestore `getAfter` lock claim already used at registration).

---

## Patterns to Mirror

### NAMING_CONVENTION
```dart
// SOURCE: lib/bloc/credit_approval/credit_approval_cubit.dart:10,35
class CreditApprovalState extends Equatable { ... }
class CreditApprovalCubit extends Cubit<CreditApprovalState> { ... }
```
New: `lib/bloc/identity_document/identity_document_cubit.dart` with `IdentityDocumentState` + `IdentityDocumentCubit`. Widgets: `lib/widgets/document_fields.dart`, `lib/widgets/identity_document_dialog.dart`.

### ERROR_HANDLING (client)
```dart
// SOURCE: lib/services/user_service.dart:5-10, 41-57
class DocumentAlreadyRegistered implements Exception {
  const DocumentAlreadyRegistered();
  @override
  String toString() => 'Este documento ya está registrado.';
}
...
      // Return a flag instead of throwing inside the transaction: custom
      // exceptions are not guaranteed to survive the platform channel.
      final taken = await _firestore.runTransaction<bool>((tx) async {
        if ((await tx.get(docRef)).exists) return true;
        ...
      });
      if (taken) throw const DocumentAlreadyRegistered();
```
Other errors go through `userMessage(e)` (`lib/utils/error_message.dart`).

### ERROR_HANDLING (server)
```ts
// SOURCE: functions/src/joinSession.ts:62-68
    if (!userSnap.exists) {
      throw new HttpsError('failed-precondition', 'No encontramos tu perfil.');
    }
    const user = userSnap.data()!;
    const until: number | undefined = user.blockedUntil?.toMillis?.();
    if (isBlocked(until, nowMs)) throw new HttpsError('failed-precondition', blockedMessage(until!));
```
Client side, `callableError` (`lib/utils/error_message.dart`) already turns a `failed-precondition` with Spanish copy into `Exception(msg)`, so the message reaches the snackbar unchanged.

### LOGGING_PATTERN
No logging in these paths (callables throw `HttpsError`, client shows `userMessage`). Add none.

### POLICY_PATTERN (pure server helper)
```ts
// SOURCE: functions/src/joinPolicy.ts:20-30
export type JoinError = {
  code: 'permission-denied' | 'failed-precondition';
  message: string;
};
export const joinError = (c: JoinCheck): JoinError | null => { ... }
```

### RULES_PATTERN
```
// SOURCE: firestore.rules:47-57, 76-83
    function isValidNewUser(userId, d) {
      return d.documentType in ['dni', 'ce']
        && d.documentNumber is string
        && (d.documentType == 'dni'
            ? d.documentNumber.matches('^[0-9]{8}$')
            : d.documentNumber.matches('^[A-Z0-9]{9,12}$'))
        ...
        && getAfter(/databases/$(database)/documents/documents/$(documentKey(d))).data.uid == userId;
    }
  // documents/{key} create: lock uid == auth.uid and getAfter(users/{auth.uid}) declares exactly this key
```

### TEST_STRUCTURE (client cubit)
```dart
// SOURCE: test/credit_approval_cubit_test.dart:7-25
class _FakeService implements CreditHistoryService {
  Object? reviewError;
  @override
  Future<void> reviewCreditPurchase(String entryId, {required bool approve}) async {
    if (reviewError != null) throw reviewError!;
    ...
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

### TEST_STRUCTURE (emulator)
```js
// SOURCE: functions/emulator-tests/rules.test.mjs:145-151
await t('[theirs] register: users doc + documents lock in one batch', async () => {
  const db = as('reg1'); const b = writeBatch(db);
  b.set(doc(db, 'users/reg1'), newUser('11111111'));
  b.set(doc(db, 'documents/dni_11111111'), {uid: 'reg1', createdAt: serverTimestamp()});
  await assertSucceeds(b.commit());
});
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `firestore.rules` | UPDATE | Allow a one-time empty → DNI/CE claim on `users/{uid}`, with the lock in the same write |
| `functions/src/joinPolicy.ts` | UPDATE | `hasIdentityDocument(user)` + `DOCUMENT_REQUIRED_MESSAGE` |
| `functions/src/joinSession.ts` | UPDATE | Refuse join without a document |
| `functions/src/waitlistCallables.ts` | UPDATE | Refuse `joinWaitlist` without a document |
| `functions/test/joinPolicy.test.ts` | UPDATE | Unit tests for `hasIdentityDocument` |
| `functions/emulator-tests/join.test.mjs` | UPDATE | Join refused for a legacy user |
| `functions/emulator-tests/waitlist.test.mjs` | UPDATE | Waitlist refused for a legacy user |
| `functions/emulator-tests/rules.test.mjs` | UPDATE | First-time claim allowed; every bypass denied |
| `lib/models/user_model.dart` | UPDATE | `bool get hasDocument` |
| `lib/services/user_service.dart` | UPDATE | `claimDocument(uid, type, number)` |
| `lib/bloc/identity_document/identity_document_cubit.dart` | CREATE | Saves the document, exposes saving / saved / error |
| `lib/widgets/document_fields.dart` | CREATE | Shared DNI/CE selector + number field (registration + dialog) |
| `lib/widgets/identity_document_dialog.dart` | CREATE | `askIdentityDocument(context) → Future<bool>` |
| `lib/screens/registration_screen.dart` | UPDATE | Use `DocumentFields` (no behavior change) |
| `lib/screens/session_detail_screen.dart` | UPDATE | Ask for the document before join / waitlist |
| `test/user_model_document_test.dart` | CREATE | `hasDocument` cases |
| `test/identity_document_cubit_test.dart` | CREATE | Cubit success / taken / generic failure |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATE | Document the gate and the rule change (keep CLAUDE.md and AGENTS.md in sync) |

## NOT Building

- Document correction / 30-day limit (Milestone 2 of the PRD).
- External validation (RENIEC, Migraciones, APIs) or document photo.
- Backfilling documents onto tickets legacy players already hold (accepted gap).
- Showing documents in the organizer's player list.
- A prompt at login or anywhere outside the join flow.
- A new client-side `JoinBlock` value: the dialog runs before the join, the bar does not change.

---

## Step-by-Step Tasks

### Task 1: Server policy helper
- **ACTION**: Add to `functions/src/joinPolicy.ts`.
- **IMPLEMENT**:
  ```ts
  /** Join and waitlist need a DNI or CE on the account (legacy docs have ''). */
  export const hasIdentityDocument = (u: {documentType?: unknown; documentNumber?: unknown}): boolean =>
    (u.documentType === 'dni' || u.documentType === 'ce') &&
    typeof u.documentNumber === 'string' && u.documentNumber.length > 0;

  export const DOCUMENT_REQUIRED_MESSAGE =
    'Registra tu DNI o carnet de extranjería para unirte a eventos. ' +
    'Si no ves la opción, actualiza la app.';
  ```
- **MIRROR**: POLICY_PATTERN.
- **IMPORTS**: none.
- **GOTCHA**: The format is already enforced by the rules at write time; only check presence here.
- **VALIDATE**: `cd functions && npm test` with the new unit tests (Task 9).

### Task 2: Gate in `joinSession`
- **ACTION**: In `functions/src/joinSession.ts`, right after the `isBlocked` line (≈68).
- **IMPLEMENT**: `if (!hasIdentityDocument(user)) throw new HttpsError('failed-precondition', DOCUMENT_REQUIRED_MESSAGE);`
- **MIRROR**: ERROR_HANDLING (server).
- **IMPORTS**: add `hasIdentityDocument, DOCUMENT_REQUIRED_MESSAGE` to the existing `./joinPolicy` import.
- **GOTCHA**: Keep it after the "already joined" retry branch (≈49): a legacy player already in the event who retries must still get their ticket back, not this error.
- **VALIDATE**: emulator join test (Task 10).

### Task 3: Gate in `joinWaitlist`
- **ACTION**: Same check in `functions/src/waitlistCallables.ts` after the `isBlocked` line (≈47).
- **IMPLEMENT**: as Task 2.
- **IMPORTS**: extend `import {joinError} from './joinPolicy';`.
- **GOTCHA**: Leave `leaveWaitlist` alone: a legacy player already on a waitlist must still be able to leave. Confirming an offer goes through `joinSession`, so it is covered.
- **VALIDATE**: emulator waitlist test (Task 10).

### Task 4: Rules — first-time claim
- **ACTION**: In `firestore.rules`.
- **IMPLEMENT**:
  ```
  // DNI 8 digits, CE 9-12 uppercase alphanumerics (same as lib/utils/document.dart).
  function isValidDocument(d) {
    return d.documentType in ['dni', 'ce']
      && d.documentNumber is string
      && (d.documentType == 'dni'
          ? d.documentNumber.matches('^[0-9]{8}$')
          : d.documentNumber.matches('^[A-Z0-9]{9,12}$'));
  }
  // A legacy account (no document) may claim one once, with its lock in the
  // SAME write. Changing an existing document stays server-only.
  function documentFirstClaim(userId) {
    return resource.data.get('documentType', '') == ''
      && isValidDocument(request.resource.data)
      && getAfter(/databases/$(database)/documents/documents/$(documentKey(request.resource.data))).data.uid == userId;
  }
  ```
  Use `isValidDocument(d)` inside `isValidNewUser` (replace the duplicated lines). In `users/{userId}` update, replace `&& documentUnchanged()` with `&& (documentUnchanged() || (isOwner(userId) && documentFirstClaim(userId)))`. Update the comment above it ("never the document" → "the document only once, if it had none").
- **MIRROR**: RULES_PATTERN.
- **GOTCHA**:
  - The `documents/{key}` create rule already checks `getAfter(users/{auth.uid})` and needs no change: it works for an update batch too.
  - `isOwner(userId)` is required: a superUser must not set someone else's document (the lock create would fail anyway, but make it explicit).
  - The other update conditions (credits, blockedUntil, superUser unchanged) still apply because they are ANDed.
  - Per CLAUDE.md: diff `firestore.rules` against the console before deploying.
- **VALIDATE**: rules emulator tests (Task 11).

### Task 5: `UserModel.hasDocument`
- **ACTION**: In `lib/models/user_model.dart`, next to `isMatchInfoComplete` (≈105).
- **IMPLEMENT**:
  ```dart
  /// Legacy accounts have '' (no DNI/CE); joining events needs one.
  bool get hasDocument =>
      (documentType == 'dni' || documentType == 'ce') &&
      documentNumber.isNotEmpty;
  ```
- **GOTCHA**: Compare the `DocumentType.name` strings; do not parse with `byName` (throws on '').
- **VALIDATE**: Task 12.

### Task 6: `UserService.claimDocument`
- **ACTION**: In `lib/services/user_service.dart`, below `createUserWithDocument`.
- **IMPLEMENT**:
  ```dart
  /// Adds a document to an account that has none (legacy), claiming its
  /// lock in the same transaction. Throws [DocumentAlreadyRegistered] when
  /// another account owns it.
  Future<void> claimDocument(String uid, DocumentType type, String number) async {
    final normalized = normalizeDocument(number);
    final lockRef = _firestore.collection('documents').doc(documentKey(type, normalized));
    final taken = await _firestore.runTransaction<bool>((tx) async {
      if ((await tx.get(lockRef)).exists) return true;
      tx.set(lockRef, {'uid': uid, 'createdAt': FieldValue.serverTimestamp()});
      tx.update(_firestore.collection(usersCollection).doc(uid), {
        'documentType': type.name,
        'documentNumber': normalized,
      });
      return false;
    });
    if (taken) throw const DocumentAlreadyRegistered();
  }
  ```
- **MIRROR**: ERROR_HANDLING (client), `createUserWithDocument`.
- **GOTCHA**: Do not wrap other errors in `Exception('Failed to …: $e')`; let `FirebaseException` through so `userMessage` maps it to Spanish (e.g. `permission-denied`).
- **VALIDATE**: rules tests cover the write; cubit test covers the call.

### Task 7: `IdentityDocumentCubit`
- **ACTION**: Create `lib/bloc/identity_document/identity_document_cubit.dart`.
- **IMPLEMENT**:
  ```dart
  enum IdentityDocumentStatus { idle, saving, saved, failure }

  class IdentityDocumentState extends Equatable {
    final IdentityDocumentStatus status;
    final String? error;
    const IdentityDocumentState({this.status = IdentityDocumentStatus.idle, this.error});
    @override
    List<Object?> get props => [status, error];
  }

  /// Saves a legacy account's first DNI/CE before joining an event.
  class IdentityDocumentCubit extends Cubit<IdentityDocumentState> {
    final UserService _userService;
    final String _uid;
    IdentityDocumentCubit(this._userService, this._uid) : super(const IdentityDocumentState());

    static const takenMessage =
        'Este documento ya está registrado en otra cuenta, así que no puedes '
        'unirte con él. Si es tuyo, escríbenos a ricardo@cotillo.dev.';

    Future<void> save(DocumentType type, String number) async {
      emit(const IdentityDocumentState(status: IdentityDocumentStatus.saving));
      try {
        await _userService.claimDocument(_uid, type, number);
        emit(const IdentityDocumentState(status: IdentityDocumentStatus.saved));
      } on DocumentAlreadyRegistered {
        emit(const IdentityDocumentState(status: IdentityDocumentStatus.failure, error: takenMessage));
      } catch (e) {
        emit(IdentityDocumentState(status: IdentityDocumentStatus.failure, error: userMessage(e)));
      }
    }
  }
  ```
- **MIRROR**: NAMING_CONVENTION, `CreditApprovalCubit`.
- **IMPORTS**: `package:equatable/equatable.dart`, `package:flutter_bloc/flutter_bloc.dart`, `package:proplay/services/user_service.dart`, `package:proplay/utils/document.dart`, `package:proplay/utils/error_message.dart`.
- **GOTCHA**: Format validation happens in the form (`validateDocument`) before `save` is called.
- **VALIDATE**: Task 13.

### Task 8: Shared fields, dialog, wiring
- **ACTION A**: Create `lib/widgets/document_fields.dart` — a `StatelessWidget` `DocumentFields({required DocumentType type, required ValueChanged<DocumentType> onTypeChanged, required TextEditingController controller, GlobalKey<FormFieldState<String>>? fieldKey, bool enabled = true})`. Move the `SegmentedButton<DocumentType>` + `SizedBox(height: 16)` + `TextFormField` from `registration_screen.dart:142-178` as is (labels "DNI", "Carnet de extranjería", "Número de documento", `Icons.badge`, keyboard type by type, `validator: (v) => validateDocument(type, v)`). Pass `null` to `onSelectionChanged` when `enabled` is false.
- **ACTION B**: In `registration_screen.dart`, replace those lines with `DocumentFields(...)`, passing `_docType`, `_documentController`, `_docFieldKey`, `enabled: !isLoading`, and an `onTypeChanged` that keeps the existing `setState` + re-validate body.
- **ACTION C**: Create `lib/widgets/identity_document_dialog.dart`:
  ```dart
  /// Asks a legacy player for their DNI/CE before joining. True once saved.
  Future<bool> askIdentityDocument(BuildContext context) async {
    final uid = context.currentUser!.uid;
    final userService = context.read<UserService>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => IdentityDocumentCubit(userService, uid),
        child: const _IdentityDocumentDialog(),
      ),
    );
    return saved ?? false;
  }
  ```
  `_IdentityDocumentDialog` is a `StatefulWidget` holding a `Form` key, controller and `DocumentType` (default `dni`). `AlertDialog` title "Tu documento de identidad"; content: explanatory text (see UX After), `DocumentFields`, and the cubit's `error` in `AppColors.error` when status is `failure`. Actions: "Cancelar" (`pop(false)`), "Guardar y continuar" (disabled while `saving`; validates the form, then `cubit.save(type, controller.text)`). `BlocListener`: on `saved` → `context.read<AuthBloc>().add(const AuthRefreshUserRequested())` and `Navigator.of(context).pop(true)`.
- **ACTION D**: In `session_detail_screen.dart`:
  - Make `_showJoinConfirmationDialog` `Future<void> … async` and add at its start:
    ```dart
    if (!(context.currentUser?.hasDocument ?? false)) {
      if (!await askIdentityDocument(context) || !context.mounted) return;
    }
    ```
  - Same guard for the waitlist button (≈679): move the dispatch into a small `_joinWaitlist(context)` async method with that guard, then `context.read<SessionDetailBloc>().add(const JoinWaitlist())`.
- **MIRROR**: CLAUDE.md UI rules — colors from `Theme.of(context)` / `AppColors`, no inline colors, no Firebase in widgets (the dialog only talks to the cubit).
- **IMPORTS**: `package:proplay/utils/auth_helper.dart` (for `context.currentUser`), `package:proplay/bloc/auth/auth_bloc.dart` + `auth_event.dart`, `package:proplay/services/user_service.dart`, `package:proplay/bloc/identity_document/identity_document_cubit.dart`, `package:proplay/widgets/document_fields.dart`, `package:proplay/theme/app_colors.dart`. `session_detail_screen.dart` already imports `app_colors.dart` and `auth_helper.dart`; it only needs `package:proplay/widgets/identity_document_dialog.dart`.
- **GOTCHA**:
  - `UserService` is a `RepositoryProvider` in `lib/main.dart:102`; read it from the outer `context` before `showDialog`.
  - After the dialog, `context.currentUser` may be stale until `AuthRefreshUserRequested` completes; the join goes on anyway (the server reads the fresh user doc), so do not re-check `hasDocument` after saving.
  - Check `context.mounted` after every `await`.
- **VALIDATE**: `flutter analyze`; manual run (see Manual Validation).

### Task 9: Policy unit tests
- **ACTION**: Extend `functions/test/joinPolicy.test.ts`.
- **IMPLEMENT**: `hasIdentityDocument` is true for `{documentType: 'dni', documentNumber: '12345678'}` and `'ce'`; false for `{}`, `{documentType: '', documentNumber: ''}`, `{documentType: 'dni', documentNumber: ''}`, `{documentType: 'passport', documentNumber: 'X'}`, `{documentType: 'dni', documentNumber: 123}`.
- **VALIDATE**: `cd functions && npm test`.

### Task 10: Emulator tests — callables
- **ACTION**: `join.test.mjs`: add `doc = true` to `seed()` options; when false, write `documentType: '', documentNumber: ''`. New test: legacy user → `rejects(join(uid, id), 'failed-precondition', /DNI/)`, credits unchanged, no ticket. `waitlist.test.mjs`: a legacy user on a `fullEvent()` → `joinWaitlist` rejects with `failed-precondition` `/DNI/`, no waitlist entry.
- **GOTCHA**: Existing fixtures already set `documentType: 'dni'`, so no other test changes.
- **VALIDATE**: `cd functions && npm run test:emulator`.

### Task 11: Emulator tests — rules
- **ACTION**: In `rules.test.mjs`, seed (rules disabled) legacy users `legacy1`..`legacy6` with `{credits: '0.00'}` (no document fields), and `docowner` with `documentType: 'dni', documentNumber: '55555555'` plus lock `documents/dni_55555555 {uid: 'docowner'}`.
- **IMPLEMENT** tests:
  - Legacy claims a DNI with its lock in one batch → succeeds.
  - Legacy sets a document without the lock → fails.
  - Legacy claims a number whose lock exists (`dni_55555555`) → fails.
  - Legacy claims with invalid format (`'1234'`) → fails.
  - After a successful claim, the same user changes the number (new lock in a batch) → fails (correction is server-only).
  - Legacy claim that also changes `credits` → fails.
  - The existing `[theirs] user cannot change own document number` still passes.
- **VALIDATE**: `cd functions && npm run test:emulator`.

### Task 12: `hasDocument` test
- **ACTION**: Create `test/user_model_document_test.dart`: true for dni/ce with a number; false for `''`, unknown type, empty number. Build `UserModel` like `test/credit_approval_cubit_test.dart:36-44`.
- **VALIDATE**: `flutter test test/user_model_document_test.dart`.

### Task 13: Cubit test
- **ACTION**: Create `test/identity_document_cubit_test.dart` with a `_FakeUserService implements UserService` (override `claimDocument`, `noSuchMethod` for the rest).
- **IMPLEMENT**: success → states `[saving, saved]` and the fake received `(uid, DocumentType.dni, '12345678')`; `DocumentAlreadyRegistered` → `failure` with `takenMessage` (contains `ricardo@cotillo.dev`); `Exception('x')` → `failure` with `'x'`.
- **GOTCHA**: `UserService` creates `FirebaseFirestore.instance` in a field initializer, so use `implements` (not `extends`) to avoid touching Firebase in tests.
- **VALIDATE**: `flutter test test/identity_document_cubit_test.dart`.

### Task 14: Docs
- **ACTION**:
  - `docs/ARCHITECTURE.md` §7: in the `users` table row for `documentType`, add "legacy accounts add one once when they first join an event; `joinSession` / `joinWaitlist` refuse without one". In the `documents/` paragraph (≈337), add the first-claim rule. In the join flow (≈443), add the document check step.
  - `CLAUDE.md` and `AGENTS.md` (same text): in the Firebase paragraph next to "`joinSession` / `joinWaitlist` refuse" (blocked users), add "and refuse accounts without a DNI/CE". In "Do not regress", extend the identity-document line: "legacy accounts add one with `UserService.claimDocument` (one-time rule); correcting it is server-only".
- **VALIDATE**: read the diff; CLAUDE.md and AGENTS.md match in those lines.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected Output | Edge Case? |
|---|---|---|---|
| `hasIdentityDocument` | dni + 8 digits | true | |
| `hasIdentityDocument` | `{}` / `''` / number not a string / unknown type | false | yes |
| `UserModel.hasDocument` | `documentType: ''` | false | yes |
| `IdentityDocumentCubit.save` | fake succeeds | saving → saved | |
| `IdentityDocumentCubit.save` | `DocumentAlreadyRegistered` | failure with support email | yes |
| `IdentityDocumentCubit.save` | generic exception | failure with `userMessage` | yes |
| `joinSession` (emulator) | legacy user | `failed-precondition`, no charge, no ticket | yes |
| `joinWaitlist` (emulator) | legacy user | `failed-precondition`, no entry | yes |
| rules (emulator) | first claim with lock | allowed | |
| rules (emulator) | no lock / taken / bad format / second change / credits change | denied | yes |

### Edge Cases Checklist
- [x] Empty input — form validator (`validateDocument`)
- [x] Invalid format — form + rules
- [x] Concurrent access — two accounts claiming the same number: the second lock write hits an existing doc (update) → denied; the transaction returns `taken`
- [x] Network failure — `userMessage` maps `unavailable`
- [x] Permission denied — rules reject; message "No tienes permiso para hacer esto."
- [x] Legacy player already joined retries `joinSession` — gets the ticket back (gate is after the retry branch)
- [x] Legacy player already on a waitlist confirms an offer — client dialog shows first; old builds get the server message

---

## Validation Commands

### Static Analysis
```bash
flutter analyze
```
EXPECT: no new issues (the known `include_file_not_found` from `analysis_options.yaml` stays).

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
EXPECT: all pass, including the new rules / join / waitlist cases (needs Java).

### Browser Validation
```bash
flutter run -d chrome
```
EXPECT: feature works as in Manual Validation.

### Manual Validation
- [ ] Legacy account (set `documentType: ''`, `documentNumber: ''` in the emulator or a test project, never production) → "Unirse" shows the document dialog; cancel does nothing.
- [ ] Enter a valid DNI → dialog closes, join confirm appears, join succeeds; the ticket QR scan shows `DNI ########`.
- [ ] Enter a number already used by another account → inline error with ricardo@cotillo.dev; dialog stays open.
- [ ] Full event → "Unirme a la lista de espera" shows the dialog first.
- [ ] Account with a document → no dialog, flow unchanged.
- [ ] Registration still validates DNI/CE and switches the keyboard by type.

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
- [ ] No hard-coded colors; errors use `AppColors.error`
- [ ] Documentation updated (ARCHITECTURE.md, CLAUDE.md, AGENTS.md)
- [ ] No unnecessary scope additions
- [ ] Self-contained — no questions needed during implementation

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Functions deployed before rules + hosting: legacy players are refused and cannot add a document | Medium | Legacy players blocked | Deploy order for this change: **rules → hosting → functions** (overrides the usual functions-first order); state it in the PR |
| Old mobile builds cannot show the dialog | High | Legacy players on old builds are refused | Server message tells them to update the app |
| Rules change opens more than intended | Low | Document squatting / overwrite | Claim only when the stored type is empty, lock in the same write, owner only; one emulator test per bypass |
| Live rules differ from the repo | Medium | Deploy overwrites console edits | Diff against the console before deploying (CLAUDE.md) |

## Notes
- Decision from the PRD: first-time add uses a narrow rules change; correction (Milestone 2) will be a callable.
- Tickets already copy the holder's document snapshot in `joinSession`; nothing to change there.
- Waitlist offer confirmation needs no separate prompt: joining the waitlist already requires a document, and `_showJoinConfirmationDialog` has the guard for old entries.
