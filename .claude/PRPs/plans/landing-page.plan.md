# Plan: Landing page (`/welcome`)

## Summary
Public landing page shown first to unauthenticated users, modeled on fuchigol.com. Replaces the current "straight to `/login`" behavior. Pure UI, no BLoC, no Firestore. Placeholder content.

## User Story
As a visitor without a session, I want to see what ProPlay is before signing in, so that I understand the product and choose to log in or register.

## Problem → Solution
Unauthenticated users are redirected to `/login` (`lib/main.dart:229-231`) → they land on `/welcome` with hero, sports, events, how-it-works, footer, and CTAs to `/login` and `/registration`.

## Metadata
- **Complexity**: Small-Medium
- **Source PRD**: N/A
- **Estimated Files**: 3 new (screen, sports util, test), 4 edits (main.dart + 3 docs)
- **Decision (user)**: Option A — URL is `/welcome`; `/` stays `HomeScreen`.

---

## UX Design

### Before
```
open app (no session) -> /login form
```

### After
```
open app (no session) -> /welcome
  navbar:  [ProPlay]                       [Ingresar]
  hero:    label · headline · subtitle · [Crear cuenta] [Ingresar] · stats row
  deportes: 10 chips/cards (icon + name)
  eventos:  6 fake cards (sport, place, time, price coins, seats)
  como funciona: 3 numbered steps
  footer:  brand, tagline, links, copyright
[Ingresar] -> /login     [Crear cuenta] -> /registration
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| App open, no session | `/login` | `/welcome` | |
| Logout | `/login` | `/welcome` | via refreshListenable, automatic |
| Session + visit `/welcome` | n/a | `/` | same rule as login/registration |
| Unauth deep link (e.g. `/group/x`) | `/login` | `/welcome` | target not preserved (same as before) |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/main.dart` | 106-243 | Router + redirect to edit; add route and change redirect |
| P0 | `lib/widgets/responsive_layout.dart` | all | `ResponsiveLayout`, `ResponsiveConstrainedBox` (maxWidth default 480; pass larger for landing) |
| P1 | `lib/screens/login_screen.dart` | 1-9, 61-95 | Screen conventions: imports order, Spanish copy |
| P1 | `lib/screens/home_screen.dart` | 626-651 | Only sports list with icons (private to a dialog) |
| P2 | `lib/utils/breakpoints.dart` | all | Breakpoint names (MOBILE, TABLET, DESKTOP, SM, XL...) |
| P2 | `docs/ARCHITECTURE.md` | 100-135 | Redirect rules + route table to update |

## External Documentation
None needed. Uses only `go_router`, `responsive_framework`, Material icons already in the project.

---

## Patterns to Mirror

### NAVIGATION
```dart
// SOURCE: lib/screens/payment_pending_screen.dart:36
onPressed: () => context.go('/'),
```
Use `context.go('/login')` / `context.go('/registration')`. Never `Navigator.push`.

### IMPORT ORDER (CLAUDE.md)
Flutter -> package imports -> `package:proplay/...`
```dart
// SOURCE: lib/screens/login_screen.dart:1-7
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:proplay/widgets/responsive_layout.dart';
```

### SPORTS (canonical values, with icons)
```dart
// SOURCE: lib/screens/home_screen.dart:629-651 (shape to copy; values must stay canonical)
{'display': 'Fútbol', 'value': 'fútbol', 'icon': Icons.sports_soccer},
...
```

### RESPONSIVE
```dart
// SOURCE: lib/widgets/responsive_layout.dart:33-43
ResponsiveBreakpoints.of(context).largerThan(TABLET)  // desktop
ResponsiveBreakpoints.of(context).largerThan(MOBILE)  // tablet
```

### REDIRECT RULES
```dart
// SOURCE: lib/main.dart:223-238
final loggedIn = authState is AuthAuthenticated;
final loggingIn = state.matchedLocation == '/login';
final registering = state.matchedLocation == '/registration';
if (!loggedIn && !loggingIn && !registering) return '/login';
if (loggedIn && (loggingIn || registering)) return '/';
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/screens/landing_screen.dart` | CREATE | Landing UI, all sections, placeholder data as consts |
| `lib/utils/sports.dart` | CREATE | Shared canonical sports const (display, value, icon). Avoids a 4th inline copy |
| `lib/main.dart` | UPDATE | Add `/welcome` GoRoute, update redirect, import screen |
| `test/landing_screen_test.dart` | CREATE | One smoke test: renders, CTAs navigate |
| `docs/ARCHITECTURE.md` | UPDATE | Redirect rules (line ~106) + route table (~133) |
| `CLAUDE.md` | UPDATE | Routing section line 84 |
| `AGENTS.md` | UPDATE | Routing section line 83 (keep in sync with CLAUDE.md) |

## NOT Building
- FAQ, districts, features grid, sticky download bar, App Store / Play buttons (not requested).
- BLoC, Firestore reads, or any service call. Events are fake.
- Migrating `create_group_screen.dart`, `group_edit_screen.dart`, `home_screen.dart` to the new shared sports const (separate follow-up; see Risks).
- SEO / meta tags / OG tags in `web/index.html`.
- Preserving the original deep-link target through login.
- Real images; use icons/gradients as placeholders.

---

## Step-by-Step Tasks

### Task 1: Shared sports constant
- **ACTION**: Create `lib/utils/sports.dart`.
- **IMPLEMENT**: `const List<({String display, String value, IconData icon})> kSports` with the 10 canonical sports in the order from CLAUDE.md.
- **MIRROR**: SPORTS pattern above.
- **IMPORTS**: `package:flutter/material.dart`.
- **GOTCHA**: values must be exactly `fútbol, baloncesto, voleibol, tenis, natación, running, ciclismo, gimnasio, pádel, béisbol` (accents included).
- **VALIDATE**: `flutter analyze` clean for the file.

### Task 2: LandingScreen
- **ACTION**: Create `lib/screens/landing_screen.dart`, `StatelessWidget`, `Scaffold` + `SingleChildScrollView`.
- **IMPLEMENT**: sections in order: navbar row, hero, deportes (from `kSports`), eventos (6 const fake cards), cómo funciona (3 steps), footer. Wrap each section body in `ResponsiveConstrainedBox(maxWidth: 1100)`. Grid columns: mobile 1-2, tablet 2-3, desktop 3-5 via `ResponsiveBreakpoints`. Use `Wrap` or `GridView(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` inside the scroll view.
- **MIRROR**: NAVIGATION, IMPORT ORDER, RESPONSIVE.
- **IMPORTS**: `flutter/material.dart`, `go_router`, `responsive_framework`, `proplay/utils/sports.dart`, `proplay/widgets/responsive_layout.dart`.
- **GOTCHA**: no `context.currentUser` or any BLoC (no user here). Do not hard-code `#BA1B1D`; use `Theme.of(context).colorScheme.primary`. Copy is Spanish; fake data has no real people/venues. Event cards must not look purchasable (no "Unirme" button; CTA is "Crear cuenta para unirte").
- **VALIDATE**: renders at 390 / 768 / 1280 px with no overflow.

### Task 3: Route + redirect
- **ACTION**: Edit `lib/main.dart`.
- **IMPLEMENT**:
  1. `import 'package:proplay/screens/landing_screen.dart';`
  2. Add top-level `GoRoute(path: '/welcome', name: 'welcome', builder: (context, state) => const LandingScreen())` next to `/login`.
  3. In redirect add `final welcoming = state.matchedLocation == '/welcome';`; change first rule to `if (!loggedIn && !loggingIn && !registering && !welcoming) return '/welcome';`; change second to `if (loggedIn && (loggingIn || registering || welcoming)) return '/';`.
- **MIRROR**: REDIRECT RULES.
- **GOTCHA**: keep the `proplay://` scheme block (lines 207-221) untouched and before the auth checks.
- **VALIDATE**: manual flow in Task 6.

### Task 4: Docs
- **ACTION**: Edit `docs/ARCHITECTURE.md` (redirect rules bullet ~106: unauth may visit `/welcome`, `/login`, `/registration`; add table row `/welcome | welcome | LandingScreen`), `CLAUDE.md:84` and `AGENTS.md:83` (same sentence).
- **GOTCHA**: CLAUDE.md and AGENTS.md must stay identical on this line.

### Task 5: Smoke test
- **ACTION**: Create `test/landing_screen_test.dart`.
- **IMPLEMENT**: pump a `MaterialApp.router` with a `GoRouter` (`/welcome` -> `LandingScreen`, `/login` and `/registration` -> placeholder `Text`s), wrapped by `ResponsiveBreakpoints.builder` with the same breakpoints as main. Assert hero text appears; tap "Ingresar", expect `/login` stub; go back, tap "Crear cuenta", expect `/registration` stub.
- **GOTCHA**: the existing `test/widget_test.dart` counter test is stale and needs Firebase; do not depend on it. Set a tall surface size (`tester.view.physicalSize`) so CTAs are on-screen.
- **VALIDATE**: `flutter test test/landing_screen_test.dart` passes.

### Task 6: End-to-end check
- **VALIDATE** (manual, `flutter run -d chrome`): no session -> `/welcome`; Ingresar -> login; Crear cuenta -> registration; log in -> `/`; manual URL `/welcome` while logged in -> `/`; log out -> `/welcome`; resize 390 / 768 / 1280 px.

---

## Testing Strategy

| Test | Input | Expected | Edge? |
|---|---|---|---|
| Renders hero | pump landing | headline text found | no |
| Ingresar CTA | tap | route `/login` | no |
| Crear cuenta CTA | tap | route `/registration` | no |
| Narrow width | 360px surface | no overflow exception | yes |

---

## Validation Commands
```bash
flutter pub get
flutter analyze        # EXPECT: only the known include_file_not_found for flutter_lints
flutter test test/landing_screen_test.dart
flutter build web      # EXPECT: success
```

## Acceptance Criteria
- [ ] No session -> `/welcome` is first screen (web and mobile).
- [ ] Hero CTA + navbar link reach `/login` and `/registration`.
- [ ] Sections present: hero, deportes, eventos, cómo funciona, footer.
- [ ] Logged-in users never see `/welcome`.
- [ ] Logout lands on `/welcome`.
- [ ] No Firebase call in the new widget; no new BLoC.
- [ ] Docs updated; CLAUDE.md and AGENTS.md in sync.
- [ ] No overflow at 360 / 768 / 1280 px.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| New `kSports` becomes a 4th duplicate of the sport list | High | Low | Migrate the other 3 in a follow-up |
| Overflow on very narrow screens with fixed-width cards | Medium | Low | Use `Wrap`/flexible grid, test at 360px |
| Unauth deep link target lost | Certain | Low | Same as today; out of scope |
| Fake events mistaken for real data | Low | Medium | Label "Ejemplo" or use generic copy |

## Notes
- Fuchigol has no login link; ProPlay needs Ingresar/Crear cuenta CTAs instead of store buttons.
- Out of scope but noticed: Google Maps API keys are hard-coded in `lib/utils/constants.dart`.
