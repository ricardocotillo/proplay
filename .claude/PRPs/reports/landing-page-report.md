# Implementation Report: Landing page (`/welcome`)

## Summary
Public `/welcome` landing (navbar, hero, deportes, eventos placeholder, cómo funciona, footer). Unauth redirect now goes to `/welcome`; logged-in users hitting `/welcome` go to `/`.

## Tasks Completed
All 5 code/doc tasks done. Task 6 (manual `flutter run -d chrome`) NOT run.

## Validation Results
| Level | Status | Notes |
|---|---|---|
| Static Analysis | Pass | Only known `include_file_not_found` + 1 pre-existing `unnecessary_import` |
| Unit Tests | Pass | 3 tests (hero, CTAs, 360px no overflow) |
| Build | FAIL (pre-existing) | `flutter build web` fails on clean main too: `google_maps_apis-5.1.0` `errorLogger.logError(response:)` |
| Manual E2E | Not run | |

## Files Changed
CREATED: lib/screens/landing_screen.dart, lib/utils/sports.dart, test/landing_screen_test.dart
UPDATED: lib/main.dart, docs/ARCHITECTURE.md, CLAUDE.md, AGENTS.md

## Deviations
- Events/steps grids use `LayoutBuilder` + `Wrap` (width of the section) instead of `ResponsiveBreakpoints` columns.
- Only 360px and 1280px covered by tests; 768px not tested.

## Next Steps
- [ ] Fix/pin `google_maps_apis` so web build works
- [ ] Manual check in Chrome
- [ ] Migrate other 3 sport lists to `kSports`
