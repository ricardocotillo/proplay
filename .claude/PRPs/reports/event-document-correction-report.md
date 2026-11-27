# Implementation Report: Document correction (30-day limit)

## Summary
A player with a DNI/CE can correct it from Profile → "Documento de identidad", at most once every 30 days since the last change. A new callable, `changeDocument`, checks the cooldown, claims the new lock, releases the old one and updates the profile in one transaction. Clients cannot write `users.documentChangedAt` (rules). Tickets already issued keep the old document snapshot.

## Assessment vs Reality

| Metric | Predicted (Plan) | Actual |
|---|---|---|
| Complexity | Medium | Medium |
| Confidence | 8/10 | 9/10 (no rework needed) |
| Files Changed | ~20 (5 new, 15 updated) | 22 (5 new, 17 updated; 4 of the new/updated are docs and `package.json`) |

## Tasks Completed

| # | Task | Status | Notes |
|---|---|---|---|
| 1 | Server policy `documentPolicy.ts` | Complete | |
| 2 | Export `fmtDate` | Complete | |
| 3 | Callable `changeDocument` + export | Complete | |
| 4 | Rules: freeze `documentChangedAt` | Complete | Also rejected on user create |
| 5 | Client policy, model, service | Complete | |
| 6 | Server unit tests | Complete | |
| 7 | Register emulator test | Complete | |
| 8 | Emulator test for the callable | Complete | 12 cases |
| 9 | Rules tests | Complete | 5 cases |
| 10 | Cubit + dialog + profile tile | Complete | |
| 11 | Client tests | Complete | |
| 12 | Docs | Complete | ARCHITECTURE.md, CLAUDE.md, AGENTS.md (CLAUDE.md and AGENTS.md diffs identical) |

## Validation Results

| Level | Status | Notes |
|---|---|---|
| Static Analysis | Pass | `flutter analyze lib test`: no issues; `npm run build` (tsc) clean |
| Unit Tests | Pass | Flutter 168 (4 new); functions 67 (5 new) |
| Emulator | Pass | Java 27; `changeDocument` 12/12, rules 174/174, join 17/17, trigger 12/12, backfill 7/7, all other suites pass |
| Build | Not run | `flutter build web` not run |
| Manual / browser | Not run | The profile tile and the correction dialog were never exercised in a browser or on a device |

## Files Changed

| File | Action |
|---|---|
| `functions/src/documentPolicy.ts` | CREATED |
| `functions/src/changeDocument.ts` | CREATED |
| `functions/src/index.ts` | UPDATED (export) |
| `functions/src/attendancePolicy.ts` | UPDATED (`export const fmtDate`) |
| `functions/package.json` | UPDATED (`test:emulator` chain) |
| `functions/test/documentPolicy.test.ts` | CREATED |
| `functions/emulator-tests/changeDocument.test.mjs` | CREATED |
| `functions/emulator-tests/rules.test.mjs` | UPDATED (+5 cases) |
| `firestore.rules` | UPDATED (2 lines + comment) |
| `lib/utils/document.dart` | UPDATED |
| `lib/models/user_model.dart` | UPDATED |
| `lib/services/user_service.dart` | UPDATED |
| `lib/bloc/identity_document/identity_document_cubit.dart` | UPDATED (`change`) |
| `lib/widgets/identity_document_dialog.dart` | UPDATED (`correcting`) |
| `lib/screens/profile_screen.dart` | UPDATED (`_DocumentTile`) |
| `test/document_test.dart`, `test/user_model_document_test.dart`, `test/identity_document_cubit_test.dart` | UPDATED |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATED |

## Deviations from Plan
- **Profile tile snackbars**: the tile captures `ScaffoldMessenger.of(context)` before the first `await`, instead of checking `context.mounted` after it. Same effect, no analyzer warning, and the tile does not use the context after the dialog closes.
- **Docs**: added the deploy-order note for this milestone (functions → hosting → rules) next to the milestone 1 note in `docs/ARCHITECTURE.md`.

## Issues Encountered
- None. `dart format` printed a package-resolution warning about `flutter_lints` (the known `include_file_not_found` issue from `analysis_options.yaml`); formatting still ran.

## Tests Written

| Test File | Tests | Coverage |
|---|---|---|
| `functions/test/documentPolicy.test.ts` | 5 | Cooldown boundary, format, normalize, key, message |
| `functions/emulator-tests/changeDocument.test.mjs` | 12 | Success, cooldown, boundary, taken, same, legacy, invalid/auth, CE switch, tickets kept, missing old lock, race, old number reclaimable |
| `functions/emulator-tests/rules.test.mjs` | +5 | Client cannot set/delete/add/create `documentChangedAt`; normal update still passes |
| `test/document_test.dart` | +1 | `nextDocumentChange` |
| `test/user_model_document_test.dart` | +1 | `documentChangedAt` read, never written |
| `test/identity_document_cubit_test.dart` | +2 | `change` success and failure |

## Next Steps
- [ ] Try the tile and dialog in the browser against the emulator or a test project
- [ ] Code review via `/code-review`
- [ ] Deploy order: functions → hosting → rules (diff `firestore.rules` against the console first)
- [ ] Create PR via `/prp-pr`
