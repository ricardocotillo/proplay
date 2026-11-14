# Plan: Welcome corrections (3 sports) + mandatory identity document

## Summary
Reduce canonical sports from 10 to 3 (`fútbol`, `baloncesto`, `voleibol`), remove "amateur" from the landing, and make a Peruvian identity document (DNI or carnet de extranjería) mandatory at registration (email and Google), unique per account, and shown to door staff when validating a ticket.

## User Story
As a door validator, I want to see the ticket holder's name and DNI/CE, so that I can verify the buyer even without the QR.

## Problem → Solution
10 sports, "amateur" copy, no identity data → 3 sports in ONE shared constant, no "amateur", `documentType` + `documentNumber` stored on user, uniqueness lock in `documents/`, snapshot on ticket, shown in `ValidateTicketScreen`.

## Metadata
- **Complexity**: Medium
- **Source PRD**: N/A
- **Estimated Files**: ~16 (3 new, 13 updated) + asset deletions

---

## UX Design

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Landing hero tag | "DEPORTE AMATEUR EN PERÚ" | "DEPORTE EN PERÚ" | + footer line |
| Landing stat | "10 deportes" | "3 deportes" | sports grid 3 cols |
| Landing sample events | 6 cards | 3 cards (fútbol, voleibol, baloncesto) | drop pádel/running/tenis |
| Registration form | no document | selector DNI/CE + number, required | below Apellido |
| Google button (registration) | opens popup immediately | validates document fields first, then popup | |
| Google button (login) | creates account silently | existing account → login; new account → deleted + "Regístrate primero" | no account without document |
| Validate ticket | name only | name + `DNI 12345678` | both the review card and the success view |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/bloc/auth/auth_bloc.dart` | 1-272 | register/google handlers to extend |
| P0 | `lib/models/user_model.dart` | 67-173 | `UserModel` toMap/fromMap pattern |
| P0 | `lib/services/user_service.dart` | 1-20 | `createUser` pattern (wrap errors in `Exception`) |
| P0 | `lib/screens/registration_screen.dart` | 1-258 | form + Google button |
| P0 | `lib/models/ticket_model.dart` | all | denormalized user snapshot pattern |
| P0 | `lib/services/ticket_service.dart` | 17-41 | `buildTicketForJoin` |
| P1 | `lib/screens/validate_ticket_screen.dart` | 154, 274 | where name is rendered |
| P1 | `lib/utils/sports.dart` | all | shared `kSports` |
| P1 | `lib/screens/home_screen.dart` | 626-646 | duplicated sport list (record icons) |
| P1 | `lib/screens/create_group_screen.dart` / `group_edit_screen.dart` | 22-33 / 29-40 | duplicated sport lists (display/value maps) |
| P1 | `lib/screens/landing_screen.dart` | 8-72, 219, 266, 316, 478 | copy, stats, events, grid |
| P2 | `test/landing_screen_test.dart`, `test/auth_redirect_test.dart` | all | test style (flutter_test, no mocks) |

---

## Patterns to Mirror

### SHARED_CONSTANT
```dart
// SOURCE: lib/utils/sports.dart:4
const List<({String display, String value, IconData icon})> kSports = [
  (display: 'Fútbol', value: 'fútbol', icon: Icons.sports_soccer),
```

### MODEL_MAP
```dart
// SOURCE: lib/models/user_model.dart:107-121, 149-162
Map<String, dynamic> toMap() => {'uid': uid, ..., 'sports': sports};
factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
  firstName: map['firstName'] ?? '', ...
```

### SERVICE_ERROR
```dart
// SOURCE: lib/services/user_service.dart:8-14
try { await _firestore.collection(usersCollection).doc(user.uid).set(user.toMap()); }
catch (e) { throw Exception('Failed to create user: $e'); }
```

### TICKET_SNAPSHOT
```dart
// SOURCE: lib/services/ticket_service.dart:37-39
userFirstName: user.firstName,
userLastName: user.lastName,
userProfileImageUrl: user.profileImageUrl,
```

### BLOC_ERROR
```dart
// SOURCE: lib/bloc/auth/auth_bloc.dart:171-174
} catch (e) { emit(AuthError(e.toString())); emit(AuthUnauthenticated()); }
```

### TEST_STRUCTURE
```dart
// SOURCE: test/auth_redirect_test.dart
void main() { test('...', () { expect(fn(...), ...); }); }
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/utils/sports.dart` | UPDATE | 3 sports only |
| `lib/screens/home_screen.dart` | UPDATE | use `kSports` instead of private list |
| `lib/screens/create_group_screen.dart` | UPDATE | use `kSports` |
| `lib/screens/group_edit_screen.dart` | UPDATE | use `kSports` |
| `lib/screens/landing_screen.dart` | UPDATE | copy, stat, 3 events, grid cols |
| `assets/images/landing/` | DELETE | `sport-{beisbol,ciclismo,gimnasio,natacion,padel,running,tenis}.webp`, `event-{2-padel,5-running,6-tenis}.webp` |
| `lib/utils/document.dart` | CREATE | `DocumentType`, `validateDocument`, `normalizeDocument`, `documentKey` |
| `lib/models/user_model.dart` | UPDATE | `documentType`, `documentNumber` |
| `lib/models/ticket_model.dart` | UPDATE | `userDocumentType`, `userDocumentNumber` snapshot |
| `lib/services/ticket_service.dart` | UPDATE | fill snapshot in `buildTicketForJoin` |
| `lib/services/user_service.dart` | UPDATE | `createUserWithDocument` (transaction) |
| `lib/services/auth_service.dart` | UPDATE | `deleteCurrentUser()` |
| `lib/bloc/auth/auth_event.dart` | UPDATE | document fields on register + google events |
| `lib/bloc/auth/auth_bloc.dart` | UPDATE | claim document; rollback on conflict |
| `lib/screens/registration_screen.dart` | UPDATE | selector + field, gate Google button |
| `lib/screens/validate_ticket_screen.dart` | UPDATE | show document |
| `test/document_test.dart` | CREATE | validator tests |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATE | data model, sports list, new collection |

## NOT Building
- Migration of existing users (none exist).
- Editing the document after registration (add to `edit_profile_screen` later if needed).
- Cloud Functions / server-side uniqueness (client transaction + rules, per repo's current model).
- Changes to `ticket_detail_screen` (holder's own ticket stays as is).
- Checksum validation of DNI (format only).

---

## Step-by-Step Tasks

### Task 1: Shared sports = 3
- **ACTION**: Trim `kSports` to fútbol, baloncesto, voleibol.
- **MIRROR**: SHARED_CONSTANT.
- **GOTCHA**: values keep accents exactly (`fútbol`).
- **VALIDATE**: `flutter analyze`.

### Task 2: Replace duplicated sport lists
- **ACTION**: Delete `_availableSports` in home/create_group/group_edit; iterate `kSports`.
- **IMPLEMENT**: home uses `sport.icon/display/value` (record fields instead of map keys). Group screens: `sport['display']` → `sport.display`, `sport['value']` → `sport.value`.
- **GOTCHA**: CLAUDE.md "do not add a sport in only one list" — this task removes the duplication.
- **VALIDATE**: grep finds no `natación` in `lib/`; analyze clean.

### Task 3: Landing copy + data
- **ACTION**: line 219 → `'DEPORTE EN PERÚ'`; line 478 → `'Organiza y descubre deporte en Perú.'`; `_Stat('10', ...)` → `_Stat('${kSports.length}', ...)` (drop `const` on the Wrap); sports grid `cols` → `constraints.maxWidth >= 900 ? kSports.length : 2`; remove events 2/5/6 from the sample list.
- **GOTCHA**: check `_EventsGrid` (~line 339) layout still looks right with 3 cards.
- **VALIDATE**: `flutter test test/landing_screen_test.dart`.

### Task 4: Delete orphan images
- **ACTION**: `git rm` the 10 unused webp files listed above. `pubspec.yaml` already declares the whole folder — no change.
- **VALIDATE**: `flutter build web` finds no missing asset.

### Task 5: Document util + test
- **IMPLEMENT** `lib/utils/document.dart`:
  - `enum DocumentType { dni, ce }` with `label` ('DNI', 'CE').
  - `String normalizeDocument(String s) => s.trim().toUpperCase();`
  - `String? validateDocument(DocumentType t, String? v)` → Spanish message or null. DNI: `^\d{8}$`. CE: `^[A-Z0-9]{9,12}$` (after normalize).
  - `String documentKey(DocumentType t, String n) => '${t.name}_${normalizeDocument(n)}'`.
- **TEST** `test/document_test.dart`: valid/invalid DNI (7 digits, letters), CE 9 and 12 chars ok, 8/13 fail, lowercase normalized, empty → message, `documentKey`.
- **VALIDATE**: `flutter test test/document_test.dart`.

### Task 6: Models
- **UserModel**: add `final String documentType; final String documentNumber;` (required in constructor). `toMap` adds both; `fromMap` uses `?? ''`.
- **TicketModel**: add `userDocumentType`, `userDocumentNumber` (required, `?? ''` in `fromMap`); add to `toMap`; `copyWith` passes them through. Getter `userDocumentLabel` → `'DNI 12345678'`.
- **TicketService.buildTicketForJoin**: fill from `user`.
- **GOTCHA**: `TicketModel.copyWith` re-lists every field — update it or analysis flags a missing required arg. Fix every `UserModel(` constructor call (auth_bloc ×2, any tests).
- **VALIDATE**: analyze.

### Task 7: Uniqueness transaction
- **IMPLEMENT** `UserService.createUserWithDocument(UserModel user)`:
  ```dart
  final docRef = _firestore.collection('documents')
      .doc(documentKey(DocumentType.values.byName(user.documentType), user.documentNumber));
  await _firestore.runTransaction((tx) async {
    if ((await tx.get(docRef)).exists) throw const DocumentAlreadyRegistered();
    tx.set(docRef, {'uid': user.uid, 'createdAt': FieldValue.serverTimestamp()});
    tx.set(_firestore.collection(usersCollection).doc(user.uid), user.toMap());
  });
  ```
  Define `class DocumentAlreadyRegistered implements Exception` (message: 'Este documento ya está registrado.').
- **MIRROR**: SERVICE_ERROR (but rethrow `DocumentAlreadyRegistered` untouched).
- **GOTCHA**: lock + user doc written in one transaction, per CLAUDE.md "no racy credit-style writes".

### Task 8: Auth service helper
- **IMPLEMENT**: `Future<void> deleteCurrentUser() async => await _auth.currentUser?.delete();`
- **GOTCHA**: `delete()` needs a recent login — fine right after sign-in.

### Task 9: Bloc + events
- **Events**: `AuthRegisterRequested` gains `documentType`, `documentNumber` (required). `AuthGoogleSignInRequested` gains nullable `documentType`, `documentNumber`; add to `props`.
- **Register handler**: after `registerWithEmailAndPassword`, build `UserModel` with document, call `createUserWithDocument` (replaces `createUser`). On any failure: `await _authService.deleteCurrentUser()` then emit `AuthError` + `AuthUnauthenticated`.
- **Google handler**: after popup, if `userModel == null` (new account):
  - no document in event (login-screen path) → `deleteCurrentUser()`, `AuthError('Primero regístrate con tu documento (DNI o carnet de extranjería).')`, `AuthUnauthenticated`;
  - document present → `createUserWithDocument`; on failure delete auth user and emit error.
- **GOTCHA**: `_onAuthUserChanged` already ignores Auth users without a Firestore doc — no change needed.
- **MIRROR**: BLOC_ERROR.

### Task 10: Registration UI
- **IMPLEMENT** in `registration_screen.dart`: `DocumentType _docType = DocumentType.dni;` + `_documentController`; `SegmentedButton<DocumentType>` then a `TextFormField` (`validator: (v) => validateDocument(_docType, v)`, `keyboardType` number for DNI / text for CE, `prefixIcon: Icons.badge`, label 'Número de documento').
- **Google**: `GlobalKey<FormFieldState<String>> _docFieldKey`; in `_signInWithGoogle` return early unless `_docFieldKey.currentState!.validate()`; dispatch with normalized document.
- **Email**: pass document to `AuthRegisterRequested`.
- **GOTCHA**: widgets only dispatch events; no Firebase calls.

### Task 11: Validate ticket screen
- **IMPLEMENT**: under `ticket.userFullName` (lines 154 and 274) add `Text(ticket.userDocumentLabel)` when the number is non-empty.

### Task 12: Docs
- **ARCHITECTURE §7**: add `documents/{type_number}` to the tree + table (`uid`, `createdAt`); add fields to `users` and `tickets` tables; update the sports list and the register + Google flow.
- **CLAUDE.md + AGENTS.md** (keep in sync): collections tree, canonical sports now 3, update the "duplicated sport lists" bullet.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge? |
|---|---|---|---|
| DNI ok | `12345678` | null | |
| DNI short | `1234567` | error | yes |
| DNI letters | `1234567A` | error | yes |
| CE 9 / 12 chars | `A12345678`, `ABC123456789` | null | yes |
| CE 8 / 13 chars | | error | yes |
| Lowercase CE | `ab1234567` | valid, key uppercased | yes |
| Empty | `''` | error | yes |
| `documentKey` | dni + ` 12345678 ` | `dni_12345678` | yes |

Landing widget test keeps passing (asserted strings unchanged).

### Edge Cases Checklist
- [ ] Same document, second registration → error, no orphan Auth user
- [ ] Email already used → email error first, nothing written
- [ ] Google new account via login screen → account deleted, error shown
- [ ] Google popup closed by user → no document claimed
- [ ] Network failure mid-transaction → Auth user rolled back

---

## Validation Commands
```bash
flutter pub get
flutter analyze            # include_file_not_found is a known pre-existing warning
flutter test
flutter build web
```
Manual: register with email (DNI), retry same DNI, register with Google (CE), login with Google on an unknown account, join a session, open `/validate-ticket`, confirm name + document.

---

## Acceptance Criteria
- [ ] Only 3 sports anywhere (grep `natación|béisbol|pádel|tenis` in `lib/` returns nothing)
- [ ] No "amateur" in `lib/`
- [ ] Cannot register (email or Google) without a valid document
- [ ] Duplicate document rejected, no orphan Auth user
- [ ] Door screen shows name + document
- [ ] Analyze + tests + web build pass; docs updated

## Completion Checklist
- [ ] No Firebase calls in new widget code
- [ ] User-facing copy in Spanish, comments/docs in English
- [ ] No duplicate sport lists remain

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Firestore rules not in repo; `documents/` unprotected | High | Duplicate/overwritten locks | Owner deploys rules below before release |
| Owner's existing superUser account has no document | Med | Empty document in UI | `fromMap` defaults `''`; edit the doc by hand in console |
| `user.delete()` fails (network) → Auth user without Firestore doc | Low | User retries → "email already in use" | Acceptable for launch |
| Signed-in users can probe whether a document is registered (needs `get`) | Low | Minor info leak | `documents/` stores no PII |

### Firestore rules to deploy (manual)
```
match /documents/{key} {
  allow get: if request.auth != null;
  allow create: if request.auth != null
                && request.resource.data.uid == request.auth.uid;
  allow update, delete, list: if false;
}
```

## Notes
- Sports removal only touches the canonical list; no data migration since there are no users.
- Door flow can match by number alone: the number is on the ticket snapshot, so validation never reads `users/`.
