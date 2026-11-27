# Implementation Report: Document gate at join

## Summary
Joining an event or a waitlist now requires a DNI/CE on the account. `joinSession` and `joinWaitlist` refuse accounts without one. Legacy accounts add theirs once in a dialog shown before the join / waitlist action; it is saved with the `documents/` lock in one transaction, allowed by a narrow `firestore.rules` change. Registration reuses the same `DocumentFields` widget.

## Assessment vs Reality

| Metric | Predicted (Plan) | Actual |
|---|---|---|
| Complexity | Medium | Medium |
| Confidence | 8/10 | Single pass; one test bug and one regression caught on the way (see Issues) |
| Files Changed | 18 (5 new, 13 updated) | 22 (7 new, 15 updated) incl. the plan/PRD/report files; 5 new code files + 2 new test files |

## Tasks Completed

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Server policy helper | Done | `hasIdentityDocument`, `DOCUMENT_REQUIRED_MESSAGE` |
| 2 | Gate in `joinSession` | Done | After the block check, after the retry branch |
| 3 | Gate in `joinWaitlist` | Done | `leaveWaitlist` untouched |
| 4 | Rules first claim | Done | `isValidDocument`, `documentFirstClaim`; `isValidNewUser` reuses `isValidDocument` |
| 5 | `UserModel.hasDocument` | Done | |
| 6 | `UserService.claimDocument` | Done | |
| 7 | `IdentityDocumentCubit` | Done | |
| 8 | `DocumentFields`, dialog, wiring | Done | Deviated slightly, see below |
| 9 | Policy unit tests | Done | |
| 10 | Emulator tests: callables | Done | Plus a retry test (legacy player already joined still gets the ticket) |
| 11 | Emulator tests: rules | Done | 9 `[claim]` tests |
| 12 | `hasDocument` test | Done | |
| 13 | Cubit test | Done | |
| 14 | Docs | Done | ARCHITECTURE.md, CLAUDE.md, AGENTS.md (in sync), deploy order note |

## Validation Results

| Level | Status | Notes |
|---|---|---|
| Static Analysis | Pass | `flutter analyze lib test`: no issues. A bare `flutter analyze` also reports `include_file_not_found` (known) and errors inside `functions/node_modules` (git-ignored, created by `npm install` for this run) |
| Unit Tests | Pass | `flutter test` 164 passed; `functions` `npm test` 62 passed |
| Build | Pass | `functions` `tsc` clean. `flutter build web` not run |
| Emulator | Pass | `npm run test:emulator` (Java 27): every suite passed with no FAIL line (join 17/17, rules 169/169, backfill 7/7, trigger 12/12, the others 18/18, 20/20, 10/10, 19/19, 11/11, 12/12) |
| Manual UI | Not run | The dialog and join flow were not exercised in a browser or device |

## Files Changed

| File | Action |
|---|---|
| `firestore.rules` | UPDATED |
| `functions/src/joinPolicy.ts`, `joinSession.ts`, `waitlistCallables.ts` | UPDATED |
| `functions/test/joinPolicy.test.ts` | UPDATED |
| `functions/emulator-tests/join.test.mjs`, `waitlist.test.mjs`, `rules.test.mjs` | UPDATED |
| `lib/models/user_model.dart`, `lib/services/user_service.dart` | UPDATED |
| `lib/screens/registration_screen.dart`, `lib/screens/session_detail_screen.dart` | UPDATED |
| `lib/bloc/identity_document/identity_document_cubit.dart` | CREATED |
| `lib/widgets/document_fields.dart`, `lib/widgets/identity_document_dialog.dart` | CREATED |
| `test/user_model_document_test.dart`, `test/identity_document_cubit_test.dart` | CREATED |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATED |

## Deviations from Plan
- `registration_screen.dart` / dialog: the type-change re-validation runs in `addPostFrameCallback` instead of inside `setState`. WHY: the shared widget's validator closes over the `type` of the last build, so validating inside `setState` would use the previous type (the old inline code read the field at call time).
- Cubit tests flush the stream with `Future.delayed(Duration.zero)`. WHY: the last emitted state is delivered a microtask after `save()` returns.
- Docs: also added the deploy order note (rules → hosting → functions) to ARCHITECTURE.md.

## Issues Encountered
- `npm run build` failed through `mise` (node version); ran `./node_modules/.bin/tsc` and put `node_modules/.bin` on `PATH` for the emulator suite.
- Cubit test failure (stream timing) fixed in the test, not the implementation.

## Tests Written

| Test File | Tests | Coverage |
|---|---|---|
| `functions/test/joinPolicy.test.ts` | +1 | `hasIdentityDocument` |
| `functions/emulator-tests/join.test.mjs` | +2 | legacy join refused; retry still returns the ticket |
| `functions/emulator-tests/waitlist.test.mjs` | +1 | legacy waitlist join refused |
| `functions/emulator-tests/rules.test.mjs` | +9 | first claim allowed; no lock / taken / bad format / credits change / second change / swap / other account denied |
| `test/user_model_document_test.dart` | 2 | `hasDocument` |
| `test/identity_document_cubit_test.dart` | 3 | saved, taken (support email), generic error |

## Next Steps
- [ ] Try the dialog by hand on a legacy account (emulator or test project)
- [ ] Code review via `/code-review`
- [ ] Deploy in order rules → hosting → functions; diff `firestore.rules` against the console first
- [ ] Create PR via `/prp-pr`
