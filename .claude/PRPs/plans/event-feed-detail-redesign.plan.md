# Plan: Display font, event cards, event detail

## Summary
Second design pass after the dark theme (PR #15). Add a bundled sports-style display font, rebuild the feed event card (richer info, seat progress, always an image, hover on web, two columns on wide screens) and unify the event detail screens (full-width hero, bottom action bar). Pure presentation: no BLoC, service, model, routing or Firestore changes.

## User Story
As a player browsing events, I want cards and event pages that look modern and tell me when, where, how full and how much at a glance, so that I join with confidence.

## Problem → Solution
Stock Roboto headings, a plain `ListTile` card (text-only when no banner, price/seats cramped in `trailing`), a 120px banner on detail, hard-coded `Colors.green/red` and "PEN 10.00" left on the signed-in detail → bundled display font, `EventCard` with image-or-sport-photo, relative date, seat bar, hover; `EventHero` + `EventBottomBar` shared by guest and signed-in detail.

## Metadata
- **Complexity**: Medium
- **Source PRD**: N/A (follows `docs/superpowers/specs/2026-11-25-dark-theme-redesign-design.md`)
- **PRD Phase**: standalone
- **Estimated Files**: 5 create (+ font files), 6 update, 3 tests

---

## UX Design

### Before
```
feed card:  [banner 120w | title        S/ 10 ]   no banner → round sport icon, ListTile
            [          | Fútbol · Miraf  11/14 ]   price + seats squeezed in trailing
detail:     appbar · banner 120px · tinted info box · player list · [Unirse] (signed in)
            appbar · 16:9 banner · icon rows · FilledButton (guest, scrolls away)
```

### After
```
feed card (banner stays LEFT, owner asked for it in PR #14; photo fallback when none):
  ┌─────────┬──────────────────────────────────────┐
  │  photo  │ FÚTBOL · Miraflores            S/ 12 │
  │  or     │ FÚTBOL 7 NOCTURNO   (display font)   │
  │ banner  │ [Hoy 20:00]  Av. Larco 123           │
  │         │ ▓▓▓▓▓▓▓░░░ 11/14 cupos   [ Unirme ]  │
  └─────────┴──────────────────────────────────────┘
  ≥ tablet: two columns, hover lifts the border to brand red.

detail (both screens):
  ┌──────────────────────────────────────────────┐
  │ hero image + dark gradient                    │
  │ [FÚTBOL]  TITLE (display font)                │
  └──────────────────────────────────────────────┘
  info rows (when, until, where + ver en mapa, price, organizer)
  players list (signed in)
  ─ bottom bar: S/ 12 · 3 cupos      [ Unirme ] ─  (fixed, always visible)
```

### Interaction Changes
| Touchpoint | Before | After | Notes |
|---|---|---|---|
| Card without banner | sport icon avatar | sport photo (`sportImage`) | every card same height |
| Date | `EEE d MMM, HH:mm` | "Hoy 20:00" / "Mañana 19:00" / date | pure helper, tested |
| Seats | "11/14 cupos" text | progress bar + "Últimos 3 cupos" when ≤3 | |
| Card hover (web) | none | border → brand, cursor pointer | |
| Guest detail button | scrolls with content | fixed bottom bar | |
| Signed-in detail | fixed Column, can overflow | scrollable body + fixed bottom bar | fixes short-screen overflow |

---

## Mandatory Reading

| Priority | File | Lines | Why |
|---|---|---|---|
| P0 | `lib/widgets/events_feed_view.dart` | 245-344 | current `_EventCard`, `open()` logic, banner/avatar branch |
| P0 | `lib/screens/session_detail_screen.dart` | 36-150, 146-277, 339-450 | bloc listener (do not touch), header, players, bottom action area |
| P0 | `lib/screens/public_event_screen.dart` | 54-152 | guest detail rows + CTA |
| P0 | `lib/theme/app_theme.dart` | 39-63 | text theme to extend with the display family |
| P0 | `lib/theme/app_colors.dart` | all | palette, `heroGradient`, `success`, `error` |
| P1 | `lib/widgets/event_banner.dart` | all | banner widget, `height` param |
| P1 | `lib/utils/sports.dart` | all | `kSports` record, `sportImage()`; assets in `assets/images/landing/sport-*.webp` |
| P1 | `lib/widgets/responsive_layout.dart` | all | `ResponsiveBreakpoints.of(context).largerThan(MOBILE)` pattern |
| P1 | `lib/widgets/cached_image.dart` | all | `PlatformCachedImage` |
| P2 | `test/feed_filters_test.dart` | 1-40 | `session()` SessionModel test helper |
| P2 | `test/app_theme_test.dart` | all | theme test to extend |

## External Documentation
| Topic | Source | Key Takeaway |
|---|---|---|
| Barlow Condensed | github.com/google/fonts `ofl/barlowcondensed` | SIL OFL; ship TTFs (SemiBold 600, Bold 700, ExtraBold 800) + `OFL.txt`; covers Spanish accents |
| Flutter custom fonts | docs.flutter.dev/cookbook/design/fonts | declare under `flutter: fonts:` with `weight:`; reference by `fontFamily` |

---

## Patterns to Mirror

### THEME_TEXT
// SOURCE: lib/theme/app_theme.dart:42-56
```dart
headlineSmall: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text),
titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
```

### CARD_SHELL
// SOURCE: lib/widgets/events_feed_view.dart:276-282
```dart
return Card(margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias, child: SizedBox(height: ..., child: Row(...)));
```

### OPEN_NAVIGATION (keep exactly, it stays in the feed view and is passed to the card as `onTap`)
// SOURCE: lib/widgets/events_feed_view.dart:263-274
```dart
if (context.isAuthenticated) { Navigator.push(context, MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: session.id))); } else { context.go('/events/${session.id}'); }
```

### CREDITS_FORMAT
// SOURCE: lib/widgets/events_feed_view.dart:321-323
```dart
session.costPerPlayer > 0 ? 'S/ ${UserModel.formatCredits(session.costPerPlayer)}' : 'Gratis'
```

### RESPONSIVE
// SOURCE: lib/widgets/responsive_layout.dart:38-44
```dart
ResponsiveBreakpoints.of(context).largerThan(MOBILE)
```

### TEST_STRUCTURE
// SOURCE: test/app_theme_test.dart:6-15
```dart
void main() { test('...', () { final t = AppTheme.dark; expect(...); }); }
```

---

## Files to Change

| File | Action | Justification |
|---|---|---|
| `assets/fonts/BarlowCondensed-{SemiBold,Bold,ExtraBold}.ttf`, `assets/fonts/OFL.txt` | CREATE | bundled display font + license |
| `pubspec.yaml` | UPDATE | `fonts:` family `BarlowCondensed` |
| `lib/theme/app_theme.dart` | UPDATE | display family on headline/title-large styles |
| `lib/utils/event_format.dart` | CREATE | `eventWhenLabel`, `seatsInfo` pure helpers |
| `lib/widgets/event_card.dart` | CREATE | public dumb `EventCard` (session + `onTap`) |
| `lib/widgets/event_hero.dart` | CREATE | hero image + gradient + sport chip + title |
| `lib/widgets/event_bottom_bar.dart` | CREATE | fixed bottom bar wrapper (SafeArea, max width) |
| `lib/widgets/events_feed_view.dart` | UPDATE | use `EventCard`; two-column wrap on wide; delete `_EventCard` |
| `lib/screens/public_event_screen.dart` | UPDATE | hero + rows + bottom bar |
| `lib/screens/session_detail_screen.dart` | UPDATE | scrollable body, hero, bottom bar, theme colors |
| `docs/ARCHITECTURE.md` | UPDATE | Typography note + new widgets |
| `test/event_format_test.dart`, `test/event_card_test.dart`, `test/app_theme_test.dart` | CREATE/UPDATE | see Testing |

## NOT Building
- Filters bar redesign (dropdowns stay), desktop top nav, feed two-column right rail.
- Skeleton loaders, page transitions, empty-state art (later pass).
- Any change to BLoCs, services, models, routes, join/cancel/ticket logic, Firestore.
- New packages (no `google_fonts`: it fetches fonts at runtime).
- Copy changes except: signed-in detail price uses "S/ 12.00" like the feed instead of "PEN 12.00 por jugador" (consistency call, easy to revert).

---

## Step-by-Step Tasks

### Task 1: Bundle display font and wire the theme
- **ACTION**: Download Barlow Condensed SemiBold/Bold/ExtraBold TTF and `OFL.txt` from github.com/google/fonts (`ofl/barlowcondensed`) into `assets/fonts/`. Declare in `pubspec.yaml`:
  `fonts: - family: BarlowCondensed  fonts: [ {asset: assets/fonts/BarlowCondensed-SemiBold.ttf, weight: 600}, {…Bold.ttf, weight: 700}, {…ExtraBold.ttf, weight: 800} ]`.
- **IMPLEMENT**: In `AppTheme.dark` text theme set `fontFamily: 'BarlowCondensed'` on `headlineSmall`, `headlineMedium`, `titleLarge` only (add `headlineMedium` 28/800). Body, labels and buttons stay on the default font. Add `const String kDisplayFont = 'BarlowCondensed';` in `app_theme.dart` for widgets that need it directly.
- **MIRROR**: THEME_TEXT
- **GOTCHA**: `flutter build web` caches fonts aggressively; verify with a hard reload. Letter-spacing of condensed uppercase titles looks better at +0.3. Keep `titleMedium`/`labelLarge` unchanged so buttons and list tiles do not change width.
- **VALIDATE**: `flutter pub get`; theme test asserts `headlineSmall.fontFamily == 'BarlowCondensed'`; headings render condensed on web.

### Task 2: Pure formatting helpers
- **ACTION**: Create `lib/utils/event_format.dart`.
- **IMPLEMENT**:
  - `String eventWhenLabel(DateTime now, DateTime date)`: same calendar day → `Hoy HH:mm`; next day → `Mañana HH:mm`; else `EEE d MMM, HH:mm` via `DateFormat(..., 'es')`. Compare using year/month/day of the local values.
  - `({double fraction, String label, bool urgent}) seatsInfo(int playerCount, int maxPlayers)`: `maxPlayers <= 0` → fraction 0; full → label `Lleno`, urgent false, fraction 1; left ≤ 3 → `Últimos N cupos` (singular `Último cupo`), urgent true; else `$playerCount/$maxPlayers cupos`.
- **IMPORTS**: `package:intl/intl.dart`
- **GOTCHA**: `DateFormat(..., 'es')` needs `initializeDateFormatting('es')` (app does it at startup; tests must call it in `setUpAll`). No `DateTime.now()` inside the helpers; callers pass `now` so tests are deterministic.
- **VALIDATE**: `flutter test test/event_format_test.dart`

### Task 3: `EventCard` widget
- **ACTION**: Create `lib/widgets/event_card.dart` with `EventCard({required SessionModel session, required VoidCallback onTap})`. Stateful only for hover (`bool _hover`).
- **IMPLEMENT**:
  - `MouseRegion(cursor: click)` + `AnimatedContainer` border (`AppColors.border` → `AppColors.brand` on hover) around the same `Card`; `InkWell(onTap)` over the whole card (the banner tap and tile tap become one tap target).
  - Left image 132 wide on mobile, 168 wide when `largerThan(MOBILE)`; fixed card height 148 (always, because every card now has an image). Image = `EventBanner` / `PlatformCachedImage` when `bannerUrl != null`, otherwise `Image.asset(sportImage(session.sport), fit: BoxFit.cover)` with `errorBuilder` returning a flat `surfaceContainerHighest` box; add a bottom-to-top black 35% gradient overlay.
  - Right column: kicker `SPORT · district` (labelSmall, muted, uppercase), title (`titleLarge`, display font, max 2 lines, ellipsis), when-chip (`eventWhenLabel(DateTime.now(), session.eventDate)`, brand-tint background `AppColors.selectedTint`, text `AppColors.selectedText`), address single line muted (omit if null), bottom row: seat `LinearProgressIndicator` (`value: fraction`, color `AppColors.brand`, or `AppColors.warning` when `urgent`) + seats label + price (`CREDITS_FORMAT`, accent red, w800) and a small "Unirme" `FilledButton` only when not full.
  - Full events: dim the image, label `Lleno`, no button; still tappable.
- **MIRROR**: CARD_SHELL, CREDITS_FORMAT, RESPONSIVE
- **IMPORTS**: `material_ui`, `responsive_framework`, `proplay/models/session_model.dart`, `proplay/models/user_model.dart`, `proplay/theme/app_colors.dart`, `proplay/utils/event_format.dart`, `proplay/utils/sports.dart`, `proplay/widgets/event_banner.dart`
- **GOTCHA**: Card has no BLoC or `context.isAuthenticated` call: navigation stays in the feed view (CLAUDE.md: widgets do not call Firebase). The sport lookup must use `kSports.firstWhere(... orElse: first)` like today; do not add a local sport list. Fixed 148px height needs the right column to fit at small text scales: use `Expanded` + `Flexible` and test with text scale 1.3 for overflow.
- **VALIDATE**: widget test (Task 7); view on web at 360 and 1280 wide.

### Task 4: Feed uses `EventCard`
- **ACTION**: Edit `lib/widgets/events_feed_view.dart`.
- **IMPLEMENT**: Replace `_EventCard` with `EventCard(session: s, onTap: () => _open(context, s))`, moving the OPEN_NAVIGATION code into a private `_open` helper. For `largerThan(MOBILE)` render the cards in a `Wrap(spacing: 12, runSpacing: 12)` with each child width `(constraints.maxWidth - 12) / 2` via `LayoutBuilder`; on mobile keep the current column. Remove now-unused imports (`intl`, `sports.dart` if unused, `user_model`, `event_banner`).
- **MIRROR**: OPEN_NAVIGATION, RESPONSIVE
- **GOTCHA**: Feed is non-scrolling and hosted inside the Home `ListView` and `/events` scroll view: no `Expanded`/`ListView` inside. Max width stays 1100. `Card` margin `bottom: 12` goes away in the Wrap (use `runSpacing`).
- **VALIDATE**: `flutter analyze`; feed renders 1 column at 390px and 2 at 1280px.

### Task 5: `EventHero` and `EventBottomBar`
- **ACTION**: Create `lib/widgets/event_hero.dart` and `lib/widgets/event_bottom_bar.dart`.
- **IMPLEMENT**:
  - `EventHero({required SessionModel session, double height = 200})`: image (banner or sport photo, same logic as the card; extract a tiny shared `EventImage` inside `event_hero.dart` or `event_banner.dart` only if both files need it, otherwise duplicate nothing), `AppColors.page` gradient from bottom (0% → 90%), bottom-left: sport chip (icon + `display`) and title (`headlineMedium`, display font, white, max 2 lines). Constrain with `ConstrainedBox(maxWidth: 900)` centered on wide screens, rounded 16 when wide.
  - `EventBottomBar({required Widget child})`: `Material` color `AppColors.bar`, top border `AppColors.border`, `SafeArea(top: false)`, padding 16, centered max width 900.
- **GOTCHA**: Existing `EventBanner` keeps working for any other caller; leave it as is. Hero must not exceed 200px on mobile or the signed-in screen loses list space.
- **VALIDATE**: visual check; no overflow on 640px-high viewport.

### Task 6: Detail screens
- **ACTION**: Edit `public_event_screen.dart` and `session_detail_screen.dart`.
- **IMPLEMENT (public)**: body `Column` → `Expanded(SingleChildScrollView(hero + info rows))` + `EventBottomBar(child: Row(price + seats label, FilledButton CTA))`. CTA logic (signed in → `SessionDetailScreen`, else `/registration`) unchanged.
- **IMPLEMENT (signed in)**: In `build` return `Column(children: [Expanded(ListView(children: [EventHero, info block (existing rows, same map button), players section or empty-state widget])), EventBottomBar(child: <existing isProcessing/isJoined/join widget unchanged>)])`. Remove the 120px `EventBanner` and the tinted `Container`. Keep `_buildBadge`, `_buildPlayerTile`, `_showJoinConfirmationDialog`, `_showCancelDialog`, the `BlocConsumer` listener and `_wasProcessingJoin` exactly as they are. Replace `Colors.green`/`Colors.red` with `AppColors.success`/`AppColors.error` (lines ~97, 117, 273, 297, 373-381, 421: leftovers from the theme sweep). Price row: `S/ ${UserModel.formatCredits(session.costPerPlayer)} por jugador`.
- **MIRROR**: existing structure; CREDITS_FORMAT
- **GOTCHA**: The old body was a non-scrolling `Column` with `Expanded` list: moving the header into the `ListView` is what removes the overflow risk (a previous Codex finding in this area). `hasPlayers == false` empty state used `Center` inside `Expanded`: turn it into a padded `Column` child instead. Do not change anything in the join, cancel or ticket paths or the `AuthRefreshUserRequested` dispatch. Use `Theme.of(context).primaryColor` only where already present; prefer `colorScheme.primary`.
- **VALIDATE**: join flow, cancel flow and "Ver mi Ticket" still work on a test account; guest `/events/:id` shows the fixed bar.

### Task 7: Tests and docs
- **ACTION**: Write tests and update docs.
- **IMPLEMENT**:
  - `test/event_format_test.dart`: today/tomorrow/other-date labels with fixed `now`; `seatsInfo` for 0/14, 11/14, 12/14 (urgent "Últimos 2 cupos"), 13/14 (`Último cupo`), 14/14 (`Lleno`), `maxPlayers == 0`.
  - `test/event_card_test.dart`: pump `EventCard` inside `MaterialApp(theme: AppTheme.dark)` with a `SessionModel` built like `session()` in `test/feed_filters_test.dart`; expect title, `Gratis` for cost 0, `S/ 12.00`-style price, `Lleno` when full (no "Unirme"), tap calls `onTap`. No `bannerUrl` (avoids network); `errorBuilder` covers missing asset in the test bundle.
  - `test/app_theme_test.dart`: add the display-font assertion.
  - `docs/ARCHITECTURE.md`: short Typography line and list `EventCard`, `EventHero`, `EventBottomBar`.
- **GOTCHA**: call `initializeDateFormatting('es')` in `setUpAll`. `landing_screen_test` and `widget_test` fail on `main` already (need Firebase): ignore.
- **VALIDATE**: `flutter test test/event_format_test.dart test/event_card_test.dart test/app_theme_test.dart`

---

## Testing Strategy

### Unit Tests
| Test | Input | Expected | Edge? |
|---|---|---|---|
| when label today | now 18:00, event 20:00 same day | `Hoy 20:00` | |
| when label tomorrow | event next day 19:00 | `Mañana 19:00` | |
| when label across midnight | now 23:30, event 00:30 next day | `Mañana 00:30` | yes |
| seats urgent | 12/14 | `Últimos 2 cupos`, urgent | yes |
| seats full | 14/14 | `Lleno`, fraction 1 | yes |
| seats zero max | 0/0 | fraction 0, no crash | yes |
| card full | full session | `Lleno`, no `Unirme` | yes |

### Edge Cases Checklist
- [ ] No banner (photo fallback) and broken banner URL
- [ ] Long title (2-line ellipsis) and long address
- [ ] Free event (`Gratis`)
- [ ] Text scale 1.3 on the card (no overflow)
- [ ] Full event, urgent event, null district, null address
- [ ] Guest vs signed-in navigation from the card
- [ ] Short viewport (640px high) on signed-in detail

---

## Validation Commands

### Static analysis
```bash
flutter analyze
```
EXPECT: only the known `include_file_not_found`.

### Unit and widget tests
```bash
flutter test test/event_format_test.dart test/event_card_test.dart test/app_theme_test.dart
```
EXPECT: all pass.

### Full suite
```bash
flutter test
```
EXPECT: no new failures (`landing_screen_test`, `widget_test` already fail on `main`).

### Browser validation
```bash
flutter run -d chrome
```
EXPECT: feed at 390px (1 column) and 1280px (2 columns, hover border), event detail guest and signed in, display font on titles.

### Manual validation
- [ ] Card with banner, without banner, full, urgent
- [ ] Hover and click on card (web); keyboard focus visible
- [ ] Guest `/events/:id` bottom bar CTA → `/registration`
- [ ] Signed in: join (credits debited, ticket opens), "Ver mi Ticket", cancel dialog
- [ ] Map button still opens `SessionMapScreen`
- [ ] No white or hard-coded green/red left on detail

---

## Acceptance Criteria
- [ ] All tasks done, validation commands pass
- [ ] Tests written and passing
- [ ] No new analyze issues
- [ ] Matches UX design; banner stays on the left of the feed card
- [ ] Join/cancel/ticket flows unchanged

## Completion Checklist
- [ ] No Firebase or auth calls added to widgets (`EventCard` is dumb)
- [ ] Sports only from `kSports`, credits only via `UserModel.formatCredits`
- [ ] No new packages
- [ ] Spanish copy, English docs/comments
- [ ] `docs/ARCHITECTURE.md` updated

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Fixed card height overflows at large text scale | Med | Med | `Flexible`/ellipsis; test at 1.3 scale |
| Restructuring signed-in detail breaks the join listener | Low | High | Do not touch the `BlocConsumer`; only the `builder` return; test join/cancel manually |
| Font file download blocked / wrong weights | Low | Low | Fall back to system font; theme still works because `fontFamily` just falls back |
| Reverting the owner's "banner on the left" layout | Low | Med | Plan keeps it; flag in PR if changed |
| Sport photos (`landing/*.webp`) look off in a 168px crop | Med | Low | `BoxFit.cover` + overlay; adjust alignment per sport if needed |

## Notes
- Owner asked in PR #14 for banner-left cards; this plan builds on that rather than switching to image-top.
- Signed-in detail still has hard-coded `Colors.green/red` after the dark sweep; fixed in Task 6.
- Follow-ups not in scope: filters as chips, desktop top nav, skeleton loaders, empty-state illustrations, page transitions.
