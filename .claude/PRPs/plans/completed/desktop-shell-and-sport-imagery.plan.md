# Plan: Desktop top-nav shell and sport photo imagery

## Summary
Third design pass. (1) Replace the Home-only sidebar with one shared top navigation bar on desktop, rendered for every signed-in screen and for guests on `/events`, built as a `ShellRoute` so it persists across navigation. (2) Replace the flat sport-icon fallback on event cards, hero and landing tiles with bundled free-license sport photos, chosen per event with a stable hash. Mobile layout (drawer, per-screen app bars) does not change.

## User Story
As a desktop user, I want persistent top navigation and real sport photos, so that the app feels like a website I can move around in and the feed looks alive.

## Problem → Solution
Sidebar, wallet and avatar menu exist only inside `HomeScreen`; every other signed-in screen (tickets, groups, profile, `/events`, event detail) is a bare `Scaffold` with no navigation on desktop. No-banner events show a basketball icon on orange. → One `AppShell` (top bar) around all signed-in and guest-feed routes; photo fallbacks per sport.

## Metadata
- **Complexity**: Large
- **Source PRD**: N/A (follows the owner's choices: top nav on every screen, free stock photos)
- **PRD Phase**: standalone
- **Estimated Files**: 5 create + 9 photos, 7 update, 1 delete, 3 tests

---

## UX Design

### Before
```
desktop, Home only:  [bell]                              [wallet][avatar]
                     ┌──────────┬───────────────────────────────────────┐
                     │ sidebar  │ hero, feed, groups                    │
                     └──────────┴───────────────────────────────────────┘
desktop, any other signed-in screen: plain AppBar, no nav, no wallet, no sidebar
no-banner card image: orange tile + basketball icon
```

### After
```
desktop, every screen (signed in):
┌──────────────────────────────────────────────────────────────────────┐
│ [logo] ProPlay   Inicio  Eventos  Mis tickets      [S/ 38.89 ⟳] [R ▾] │  64px, max width 1400
└──────────────────────────────────────────────────────────────────────┘
│ page content (each page keeps its own title/back app bar, flattened)  │

guest on /events:   ... Eventos                       [Ingresar] [Crear cuenta]
avatar menu: Editar perfil · Historial de créditos · (Aprobar créditos) · Cerrar sesión
card/hero image without banner: real sport photo (stable variant per event)
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Navigation on desktop | Home sidebar only | top bar on every screen | `ShellRoute` |
| Wallet / credits | Home app bar only | top bar everywhere | opens `/purchase-credits` |
| Profile, history, logout | sidebar | avatar menu | credit history and approval become GoRoutes |
| Active section | none | underlined/tinted nav link | pure helper `activeNavPath` |
| No-banner event image | icon tile | photo | deterministic per event id |
| Landing sport tiles | art with baked label | photo + overlay label | |
| Mobile | drawer + per-screen bars | unchanged | shell renders only the child |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/main.dart` | 105-260, 298-335 | route table, redirect, `MaterialApp.router`, breakpoints |
| P0 | `lib/screens/home_screen.dart` | 123-300, 540-543 | its AppBar, sidebar, `Row` layout; `_showAddCreditsDialog` = `context.push('/purchase-credits')` |
| P0 | `lib/widgets/app_sidebar.dart` | 1-237 | avatar, menu items, logout dialog to reuse in the avatar menu |
| P0 | `lib/widgets/wallet_indicator.dart` | all | reuse as is |
| P0 | `lib/widgets/event_banner.dart` | all | `EventImage` fallback to change |
| P0 | `lib/utils/sports.dart` | all | `kSports`, `sportImage` |
| P1 | `lib/utils/auth_redirect.dart` + `test/auth_redirect_test.dart` | all | redirect rules and test style |
| P1 | `lib/screens/landing_screen.dart` | `_Brand`, `_NavBar`, `_SportTile` | brand widget to extract, tile to restyle |
| P1 | `lib/widgets/event_card.dart`, `lib/widgets/event_hero.dart` | `EventImage(` calls | pass the event id as seed |
| P1 | `lib/theme/app_theme.dart`, `lib/theme/app_colors.dart` | all | `AppColors.bar/border/page`, `kDisplayFont`, AppBar theme |
| P1 | `lib/widgets/app_drawer.dart` | 1-190 | mobile drawer stays; do not break |
| P2 | `docs/ARCHITECTURE.md` | 116-140 | routing table to update |

## External Documentation
| Topic | Source | Key Takeaway |
|---|---|---|
| `ShellRoute` | pub.dev/documentation/go_router (v18) | `ShellRoute(builder: (context, state, child) => ...)`; child pages render in a nested Navigator, so `Navigator.push` from them stays inside the shell; `showDialog` uses the root navigator |
| Unsplash / Pexels licenses | unsplash.com/license, pexels.com/license | free for commercial use, no attribution required; do not redistribute the photos as a standalone collection; avoid images with visible brand logos or recognizable private individuals |

---

## Patterns to Mirror

### ROUTE_DEFINITION
// SOURCE: lib/main.dart:115-129
```dart
GoRoute(
  path: '/',
  name: 'home',
  builder: (context, state) => const HomeScreen(),
  routes: [
    GoRoute(path: 'sessions', name: 'sessions', builder: (context, state) => const EventsFeedScreen()),
```

### AUTH_REDIRECT
// SOURCE: lib/main.dart:249-253
```dart
final authState = context.read<AuthBloc>().state;
return authRedirect(loggedIn: authState is AuthAuthenticated, location: state.matchedLocation);
```
`AuthAuthenticated` carries `userModel` (`UserModel.superUser`).

### BREAKPOINT
// SOURCE: lib/screens/home_screen.dart:126
```dart
final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);
```

### CURRENT_USER
// SOURCE: lib/widgets/wallet_indicator.dart:16
```dart
final user = context.watchUser; // null for guests
```

### LOGOUT_DIALOG
// SOURCE: lib/widgets/app_sidebar.dart:172-196
```dart
showDialog(context: context, builder: (dialogContext) => AlertDialog(... TextButton(onPressed: () { Navigator.pop(dialogContext); context.read<AuthBloc>().add(AuthLogoutRequested()); } ...
```

### IMAGE_FALLBACK
// SOURCE: lib/widgets/event_banner.dart:16-24
```dart
return Image.asset(sportImage(sport), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
  errorBuilder: (c, _, _) => ColoredBox(color: Theme.of(c).colorScheme.surfaceContainerHighest));
```

### TEST_STRUCTURE
// SOURCE: test/auth_redirect_test.dart:1-12
```dart
import 'package:flutter_test/flutter_test.dart';
void main() { test('guest ...', () { expect(authRedirect(loggedIn: false, location: '/'), '/welcome'); }); }
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `lib/widgets/brand.dart` | CREATE | logo + "ProPlay" extracted from landing `_Brand`, shared with the top bar |
| `lib/widgets/app_top_bar.dart` | CREATE | the bar: brand, nav links, wallet, avatar menu / guest buttons |
| `lib/widgets/app_shell.dart` | CREATE | `AppShell(location, child)`: bar on desktop, flattened page headers |
| `lib/utils/shell_nav.dart` | CREATE | pure `activeNavPath(location)` and the nav item list |
| `lib/main.dart` | UPDATE | wrap `/` and `/events` routes in `ShellRoute`; add `credit-history`, `credit-approval` routes + super-user guard |
| `lib/utils/auth_redirect.dart` | UPDATE | `adminOnlyRoutes` guard helper (keeps logic testable) |
| `lib/screens/home_screen.dart` | UPDATE | on desktop: no AppBar, no sidebar, content centered at max 1400 |
| `lib/widgets/app_sidebar.dart` | DELETE | dead after this change (check no imports first) |
| `lib/screens/landing_screen.dart` | UPDATE | use `Brand`; sport tiles use photos with overlay label |
| `lib/utils/sports.dart` | UPDATE | `sportPhoto(sport, seed)`, `kSportPhotoVariants` |
| `lib/widgets/event_banner.dart` | UPDATE | `EventImage` takes `seed`, uses `sportPhoto` |
| `lib/widgets/event_card.dart`, `lib/widgets/event_hero.dart` | UPDATE | pass `session.id` as seed |
| `assets/images/sports/{futbol,baloncesto,voleibol}-{1,2,3}.webp`, `assets/images/sports/CREDITS.md` | CREATE | 9 photos + sources |
| `pubspec.yaml` | UPDATE | add `assets/images/sports/` |
| `docs/ARCHITECTURE.md`, `CLAUDE.md`, `AGENTS.md` | UPDATE | routing table, "still Navigator.push only" list, shell note |
| `test/shell_nav_test.dart`, `test/sport_photo_test.dart`, `test/auth_redirect_test.dart` | CREATE/UPDATE | see Testing |

## NOT Building
- A right-hand rail on Home (next ticket, credits summary): needs ticket loading; later pass.
- Notifications bell (it is a TODO no-op today; dropped from the desktop bar, still on mobile Home).
- Any change to mobile layout, `AppDrawer`, BLoCs, services, models, Firestore.
- Group management links in the top bar (Home already lists groups).
- Photo upload or per-event photo picking by organizers (banner upload already exists).
- New packages.

---

## Step-by-Step Tasks

### Task 1: Shared `Brand` widget
- **ACTION**: Create `lib/widgets/brand.dart`.
- **IMPLEMENT**: Move `_Brand` from `landing_screen.dart` (logo + `Text.rich` "Pro" + "Play" in `AppColors.selectedText`) to a public `Brand({super.key, this.onTap})`; landing imports it and drops its private copy.
- **MIRROR**: existing `_Brand` code, unchanged visually.
- **IMPORTS**: `material_ui`, `proplay/theme/app_colors.dart`.
- **GOTCHA**: logo is `assets/images/landing/logo.webp` (already declared in pubspec).
- **VALIDATE**: landing still renders the same brand; `flutter analyze`.

### Task 2: Pure nav helper
- **ACTION**: Create `lib/utils/shell_nav.dart`.
- **IMPLEMENT**:
  - `const kShellNav = <({String label, String path})>[(label: 'Inicio', path: '/'), (label: 'Eventos', path: '/events'), (label: 'Mis tickets', path: '/tickets')]`.
  - `String? activeNavPath(String location)`: `/` exactly → `/`; `/events…` or `/sessions…` → `/events`; `/tickets…` → `/tickets`; anything else (groups, profile, credits) → `null`.
  - Guests only see Eventos: `List<…> navFor({required bool signedIn})`.
- **GOTCHA**: `/sessions` is an alias of the feed (CLAUDE.md); keep it active under Eventos. Match on path segments, not raw `startsWith('/')`.
- **VALIDATE**: `test/shell_nav_test.dart`.

### Task 3: `AppTopBar`
- **ACTION**: Create `lib/widgets/app_top_bar.dart`.
- **IMPLEMENT**: `AppTopBar({required String location})`, height 64, `AppColors.bar` with bottom `AppColors.border`, inner `ConstrainedBox(maxWidth: 1400)` + 24 horizontal padding (same as landing). Left: `Brand(onTap: () => context.go('/'))` (guests: `/welcome`). Then nav links as `TextButton` with active style (`AppColors.selectedText` + 2px brand underline) via `activeNavPath`; hover from theme. Right, signed in: `WalletIndicator(onTap: () => context.push('/purchase-credits'))` then avatar `PopupMenuButton<String>` (same avatar/initials logic as `home_screen.dart:146-184`) with items Editar perfil → `context.push('/edit-profile')`, Historial de créditos → `context.push('/credit-history')`, Aprobar créditos (only `user.superUser`) → `context.push('/credit-approval')`, divider, Cerrar sesión → LOGOUT_DIALOG. Right, guest: `TextButton` Ingresar → `/login`, `FilledButton` Crear cuenta → `/registration`.
- **MIRROR**: CURRENT_USER, LOGOUT_DIALOG, BREAKPOINT.
- **IMPORTS**: `go_router`, `flutter_bloc`, auth bloc + event, `app_colors.dart`, `auth_helper.dart`, `brand.dart`, `shell_nav.dart`, `wallet_indicator.dart`, `cached_image.dart`.
- **GOTCHA**: Widgets must not call Firebase: only dispatch `AuthLogoutRequested`. Avatar initials must guard empty names (`home_screen.dart:175-178` indexes `firstName[0]` without a guard; do not copy that bug). Extract the avatar into a small private `_UserAvatar` so Home (mobile) and the bar do not diverge only if trivial; otherwise leave Home alone.
- **VALIDATE**: visual check at 1280 and 1920 wide, guest and signed in.

### Task 4: `AppShell` + ShellRoute
- **ACTION**: Create `lib/widgets/app_shell.dart`; edit `lib/main.dart`.
- **IMPLEMENT**:
  - `AppShell({required String location, required Widget child})`: if `!ResponsiveBreakpoints.of(context).largerThan(TABLET)` return `child`. Otherwise `Column([AppTopBar(location), Expanded(child: Theme(data: flattened, child: child))])` on a `Material(color: AppColors.page)`. `flattened` = current theme with `appBarTheme.copyWith(backgroundColor: AppColors.page, toolbarHeight: 56)` so each page's own app bar reads as a page header under the nav, not a second nav.
  - `main.dart`: wrap the existing top-level `GoRoute('/')` and `GoRoute('/events')` in `ShellRoute(builder: (context, state, child) => AppShell(location: state.uri.path, child: child), routes: [...])`. `/login`, `/welcome`, `/registration` stay outside the shell.
- **MIRROR**: ROUTE_DEFINITION, BREAKPOINT.
- **GOTCHA**: `Navigator.push` from pages inside the shell stays in the shell's nested navigator (bar stays visible); `showDialog`/`showModalBottomSheet` use the root navigator (fine). The `GoRouterRefreshStream` and `redirect` are unchanged. Do not give the shell its own `Scaffold` (pages already have one). Keep `refreshListenable` as is. Verify the web URL/hash strategy still works (deep link `/#/events/abc`).
- **VALIDATE**: navigate Home → Eventos → event detail → back, and Home → Mis tickets: bar never disappears; resize across 1024px: bar appears/disappears without errors.

### Task 5: Router changes for credit pages and guard
- **ACTION**: Edit `lib/main.dart` and `lib/utils/auth_redirect.dart`.
- **IMPLEMENT**: Add child routes under `/`: `credit-history` → `CreditHistoryScreen`, `credit-approval` → `CreditApprovalScreen` (both already `const` constructors). In `auth_redirect.dart` add `String? adminRedirect({required bool superUser, required String location})` returning `/` for `/credit-approval` when not super user; call it from `redirect:` using `authState is AuthAuthenticated && authState.userModel.superUser`. Update `AppDrawer` and any remaining `Navigator.push` to these two screens to use `context.push` only if trivial; otherwise leave (mobile unchanged).
- **MIRROR**: AUTH_REDIRECT.
- **GOTCHA**: Client guard only hides the screen; money safety stays in Firestore rules (do not loosen). Unauthenticated users already redirect to `/welcome`.
- **VALIDATE**: `test/auth_redirect_test.dart` cases; signed-in non-admin opening `/#/credit-approval` lands on `/`.

### Task 6: Home screen without its own shell on desktop
- **ACTION**: Edit `lib/screens/home_screen.dart`.
- **IMPLEMENT**: When `isDesktop`: `appBar: null`, no `endDrawer`, no `AppSidebar`; content column wrapped in `Align(topCenter, ConstrainedBox(maxWidth: 1400))` with 24 horizontal padding so the hero, feed and groups line up with the top bar and the welcome page. Mobile branch keeps the AppBar, bell, wallet, avatar drawer exactly as today. Delete `lib/widgets/app_sidebar.dart` after `grep -rn app_sidebar lib test` shows no imports.
- **GOTCHA**: `_scaffoldKey`/`_openDrawer` stay for mobile. Profile-setup dialog logic (`_showProfileSetupDialog`) untouched. `_buildGroupsList` has its own horizontal padding per breakpoint: avoid double padding inside the 1400 box.
- **VALIDATE**: desktop Home shows one bar; mobile Home unchanged.

### Task 7: Sport photos
- **ACTION**: Source, convert and wire photos.
- **IMPLEMENT**:
  - Pick 3 photos per sport (fútbol, baloncesto, voleibol) from Unsplash or Pexels: action or court scenes, no visible brand logos or text, works under a dark gradient. Ask the owner before downloading each file (name, source, size). Convert with ImageMagick (already installed, WEBP supported): `magick in.jpg -resize 960x -strip -quality 78 assets/images/sports/<sport>-<n>.webp`; target ≤ 90 KB each. Write `assets/images/sports/CREDITS.md` with photographer, URL and license per file.
  - `sports.dart`: `const kSportPhotoVariants = 3;` and `String sportPhoto(String sport, String seed)`: strip accents like `sportImage`, `n = 1 + stableHash(seed) % kSportPhotoVariants`, return `assets/images/sports/$name-$n.webp`. `stableHash` = fold over `codeUnits` (`(h * 31 + c) & 0x7fffffff`); never `String.hashCode` (not stable across runs).
  - `EventImage` gains `required String seed`; fallback uses `sportPhoto(sport, seed)`; callers in `event_card.dart` and `event_hero.dart` pass `session.id`. Keep `sportImage()` for any remaining callers, then remove it if unused.
  - Landing `_SportTile`: use `sportPhoto(value, value)` variant 1, gradient + overlay label (icon + `display` in the display font, as in the first landing iteration), keep the tap target to `/events`.
  - `pubspec.yaml`: add `- assets/images/sports/`.
- **MIRROR**: IMAGE_FALLBACK.
- **GOTCHA**: Do not commit photos you cannot name a source and license for. `errorBuilder` must stay so a missing asset never throws. Photos must not be preloaded in bulk (lazy `Image.asset` only). Keep the dark `Color(0xCC000000)` gradient so card text stays readable.
- **VALIDATE**: `test/sport_photo_test.dart`; feed shows photos with no flicker between rebuilds (same event, same photo).

### Task 8: Docs
- **ACTION**: Update docs.
- **IMPLEMENT**: `docs/ARCHITECTURE.md` routing table: add `/credit-history`, `/credit-approval`; note the `ShellRoute`; mention `lib/utils/shell_nav.dart` and photo assets. `CLAUDE.md` and `AGENTS.md` (keep in sync): remove credit history and credit approval from the "still `Navigator.push` only" list, mention the desktop shell.
- **VALIDATE**: docs match the code.

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge? |
|---|---|---|---|
| active nav root | `/` | `/` | |
| active nav events | `/events`, `/events/abc`, `/sessions` | `/events` | yes (alias) |
| active nav tickets | `/tickets` | `/tickets` | |
| active nav none | `/group/1`, `/edit-profile`, `/purchase-credits` | `null` | yes |
| nav items for guest | `signedIn: false` | only Eventos | |
| photo deterministic | same sport + seed twice | same path | |
| photo range | 200 random seeds per sport | variant 1..3 only | yes |
| photo accents | `fútbol` | `futbol-<n>.webp` | yes |
| photo assets exist | every sport × variant | `File(path).existsSync()` | yes |
| admin guard | non-super `/credit-approval` | `/` | yes |
| admin guard ok | super user | `null` | |

### Edge Cases Checklist
- [ ] Window resized across the 1024px breakpoint while on a page
- [ ] Guest on `/events` and `/events/:id` sees guest bar, not wallet
- [ ] Logout from the avatar menu returns to `/welcome` and the bar disappears
- [ ] User with empty first/last name (avatar initials)
- [ ] Very long user name / wallet text does not overflow the bar at 1024px
- [ ] Pushed (non-GoRoute) pages keep the bar
- [ ] Missing photo asset falls back to a flat box
- [ ] Mobile Home and drawer unchanged

---

## Validation Commands

### Static analysis
```bash
flutter analyze
```
EXPECT: only the known `include_file_not_found`.

### Unit tests
```bash
flutter test test/shell_nav_test.dart test/sport_photo_test.dart test/auth_redirect_test.dart test/event_card_test.dart test/skeleton_test.dart
```
EXPECT: all pass (event card and skeleton tests may need the new `seed` argument).

### Full suite
```bash
flutter test
```
EXPECT: no new failures (`landing_screen_test` and `widget_test` already fail on Firebase init).

### Browser validation
```bash
flutter build web --no-tree-shake-icons
```
Serve `build/web` on a free port (check with `ss -ltn`; 8099 is often taken by another dev server) and look at it at 1920, 1280, 1024 and 390 wide, signed in and as guest.
EXPECT: top bar on every desktop screen, photos on cards, nothing broken on mobile.

### Manual validation
- [ ] Home → Eventos → event detail → back keeps the bar and the active link
- [ ] Avatar menu: profile, history, approve (super user only), logout
- [ ] Wallet opens `/purchase-credits`; refresh icon still works
- [ ] Photos: same event shows the same photo after reload
- [ ] Landing sport tiles and cards use photos; text stays readable
- [ ] `CREDITS.md` lists all 9 photos

---

## Acceptance Criteria
- [ ] All tasks done, validation commands pass
- [ ] Tests written and passing
- [ ] No new analyze issues
- [ ] One top bar on every desktop screen; mobile unchanged
- [ ] Every bundled photo has a recorded source and license

## Completion Checklist
- [ ] No Firebase calls added to widgets
- [ ] Sports only from `kSports`; credits only via `UserModel.formatCredits`
- [ ] No new packages
- [ ] Spanish copy, English docs/comments
- [ ] ARCHITECTURE, CLAUDE and AGENTS updated and in sync

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `ShellRoute` changes where pushed pages render or how dialogs/back behave | Med | High | Task 4 manual matrix; keep shell outside the three auth pages; roll back by removing the wrapper |
| Double headers (top bar + each page's AppBar) look heavy | Med | Med | flattened AppBar theme in the shell; revisit per screen if still heavy |
| Stock photos with wrong license or visible logos | Low | Med | owner approves each download; `CREDITS.md`; avoid logos/faces in focus |
| App size growth | Low | Low | ≤ 90 KB each, 9 files under 1 MB |
| Avatar initials crash on empty names | Low | Med | guard like `app_sidebar.dart:55-59` |
| Super-user guard only client-side | Low | Low | already the case; rules remain the real control |

## Notes
- Verified findings: sidebar/wallet/avatar/bell live only in `home_screen.dart` (lines 130-193); credit history and approval are only reachable via `Navigator.push` (sidebar, drawer); `authRedirect` already treats everything except `/welcome`, `/login`, `/registration` and `/events*` as protected.
- Port 8099 on this machine is commonly held by another Flutter dev server; use another port for local web checks.
- Follow-ups not in scope: Home right rail (next ticket), notifications, group quick-switcher, organizer-selectable photos.
