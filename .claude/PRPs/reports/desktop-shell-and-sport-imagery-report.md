# Implementation Report: Desktop top-nav shell and sport photos

## Summary
`ShellRoute` + `AppShell` + `AppTopBar` give every desktop screen (signed in, and guests on `/events*`) one top bar. Credit history/approval are routes (`/credit-approval` guarded by `adminRedirect`). Home drops its sidebar/app bar on desktop; `app_sidebar.dart` deleted. 9 Unsplash photos + `sportPhoto(sport, seed)` replace the icon fallback and landing tile art.

## Tasks
All 8 tasks done. Minor deviation: landing tile uses `sportPhoto(value, value)` (stable variant), not strictly variant 1. Old `assets/images/landing/sport-*.webp` left in place (unused).

## Validation
| Check | Result |
|---|---|
| `flutter analyze` | only `include_file_not_found` |
| shell_nav, sport_photo, auth_redirect, event_card, skeleton tests | pass |
| `flutter test` | only known failures: `landing_screen_test` (3), `widget_test` (Firebase init) |
| `flutter build web` | pass |
| Browser, guest, 1920/1280/1024/390 | bar on desktop, none on mobile; photos on cards/hero/landing; event detail keeps bar, Eventos active |

## Not verified
Signed-in views (wallet, avatar menu, super-user guard, logout, Home without sidebar): no test account available. Live resize across 1024 not exercised.

## Notes
- `baloncesto-2` shows small arena signage in the background (see CREDITS.md); swap if unwanted.
