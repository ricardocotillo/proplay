# Implementation Report: Welcome corrections (3 sports) + mandatory identity document

## Summary
Sports reduced to 3 in a single shared constant (`kSports`), "amateur" removed, DNI/CE mandatory at registration (email + Google), unique via `documents/` lock, snapshotted on tickets and shown on the door validation screen.

## Tasks Completed
| # | Task | Status |
|---|---|---|
| 1 | `kSports` = 3 | Done |
| 2 | Remove 3 duplicated sport lists | Done |
| 3 | Landing copy/stat/3 events/grid | Done (Wrap no longer `const`) |
| 4 | Delete 10 orphan webp | Done |
| 5 | `utils/document.dart` + `test/document_test.dart` | Done (3 tests) |
| 6 | User/Ticket models, `buildTicketForJoin` | Done |
| 7 | `UserService.createUserWithDocument` | Done |
| 8 | `AuthService.deleteCurrentUser` | Done |
| 9 | Events + `AuthBloc` (rollback helper `_rollbackAuthUser`) | Done |
| 10 | Registration UI (selector, field, Google gate) | Done |
| 11 | Validate ticket screen (review card + success view) | Done |
| 12 | Docs: ARCHITECTURE, CLAUDE.md, AGENTS.md | Done |

## Validation
| Level | Status | Notes |
|---|---|---|
| `flutter analyze` | Pass | only pre-existing `include_file_not_found` + deprecation infos |
| `flutter test` | Pass except `widget_test.dart` | counter smoke test fails with FirebaseException (default template test, not touched) ; landing + document tests pass |
| `flutter build web` | Pass | no missing assets |
| grep `natación|béisbol|pádel|tenis|amateur` in `lib/` | Clean | |
| Manual edge cases | Not run | needs Firebase + deployed rules |

## Deviations
- `README.md` still says "amateur" (outside plan scope).
- No bloc/widget tests for rollback paths (needs Firebase mocks; repo has none).

## Next Steps
- Deploy Firestore rules for `documents/` (see plan, section "Firestore rules to deploy") before release.
- Manual run of the edge-case checklist against a real project.
- Set document by hand on the superUser account.
