# ProPlay design guide

Rules for how the app looks and how new UI should be built. How the app works is in [ARCHITECTURE.md](ARCHITECTURE.md) (see its "Theming" section); agent rules are in [../CLAUDE.md](../CLAUDE.md). If code and this file disagree, the code wins: fix this file.

---

## 1. Principles

- **Dark only.** One theme, `AppTheme.dark`. There is no light theme or toggle.
- **Brand red is an accent**, not a background. `#BA1B1D` is for primary actions, the hero gradient and highlights. Errors use a different red so they never look like primary actions.
- **Dense, photo-led, web-first.** Content uses the width of the screen up to a cap; cards carry an image; hover and focus states exist on web.
- **Consistency by construction.** Screens read colors and text styles from the theme. They do not invent their own.
- Product copy is Spanish.

## 2. Tokens

Source of truth: `lib/theme/app_colors.dart` (palette) and `lib/theme/app_theme.dart` (component themes).

### Colors

| Token | Value | Use |
| --- | --- | --- |
| `AppColors.page` | `#0F1115` | page background |
| `AppColors.bar` | `#16181D` | top bar, bottom bar, app bars, footer |
| `AppColors.card` | `#1A1D23` | cards, dialogs, sheets |
| `AppColors.field` | `#20232A` | inputs, skeletons, disabled fills |
| `AppColors.border` | `#262A31` | 1px borders and dividers |
| `AppColors.text` / `muted` | `#F2F3F5` / `#8A909B` | text / secondary text |
| `AppColors.brand` | `#BA1B1D` | primary buttons, progress, focus |
| `AppColors.selectedTint` / `selectedText` | `#2A1517` / `#FF5A5C` | selected chips, active nav, prices, links |
| `AppColors.success` / `warning` / `error` | `#3DDC84` / `#FFB020` / `#FF8A80` | status; never use `Colors.green` / `Colors.red` |
| `AppColors.heroGradient` | brand → `#6E0F11` | Home hero |

Prefer `Theme.of(context).colorScheme` for anything the scheme covers; use `AppColors` for the rest.

### Typography

- **Display font** `BarlowCondensed` (bundled in `assets/fonts/`, SIL OFL, constant `kDisplayFont`). Applied by the theme to `headlineMedium` (28), `headlineSmall` (24) and `titleLarge` (22). Use those styles for headings, card titles and big numbers.
- Body, labels and buttons use the default font: `titleMedium` 16, `bodyMedium` 14, `bodySmall` 12 (muted).
- Need a one-off display size (for example the landing hero)? Use `TextStyle(fontFamily: kDisplayFont, ...)`, not a new font.
- No runtime font fetching (no `google_fonts`).

### Shape

Cards 14, buttons and inputs 12, dialogs 16, chips and pills stadium. Card borders are 1px `AppColors.border`; hover on web turns the border `AppColors.brand`.

## 3. Layout

- **Breakpoints** (`lib/main.dart`): mobile < 640, tablet 768–1023, desktop ≥ 1024, then xl 1280, 2xl 1536. "Desktop shell" means above tablet.
- **Content width caps:** top bar, landing, Home content and `/events` 1400 (the feed widget itself allows up to 1600 if a host gives it room); event detail, hero and bottom bar 900.
- **Columns follow the available width, not the screen:** event grids use 1 column on mobile, 2 above mobile, 3 when the box is ≥ 1200 px (a narrower host, such as a window around 1280 px wide with the page padding, gets 2). Landing sports tiles 3 at ≥ 900, step cards 3 at ≥ 700.
- **Centered sections shrink to their content.** Wrap a capped section in `SizedBox(width: double.infinity)` (see `landing_screen.dart` `_Section`) or left-aligned copy floats in the middle.

## 4. Shell

- Four destinations, one list (`kShellNav`): **Explorar** (`/`, the feed first, then "De tus grupos"), **Mis partidos** (`/tickets`), **Grupos** (`/groups`), **Perfil** (`/profile`: saldo, edit profile, saldo history, approve saldo for superUsers, log out). Guests only get Explorar (`/events`).
- Desktop: `AppShell` + `AppTopBar` (64 px: brand, the four destinations, wallet, avatar menu; guests get Ingresar / Crear cuenta) wrap every primary route through a `ShellRoute`. Each page keeps its own app bar; the shell flattens it so it reads as a page header.
- Mobile and tablet: `AppBottomNav` (a `NavigationBar`) under signed-in users' pages, only on the top level of a destination (`showsBottomNav`); detail pages (an event, a ticket, a group) keep a back button. There is no drawer.
- `/welcome`, `/login`, `/registration` are outside the shell and have their own nav (landing) or none.
- Active nav logic is pure and tested: `lib/utils/shell_nav.dart`.

## 4b. Glossary (user-facing words)

One word per thing in every screen, message and share text:

| Say | Never | Notes |
| --- | --- | --- |
| **evento** | pichanga, sesión, partido (for the thing you join) | The code still says `session` / `liveSession`; users never see it. "Mis partidos" is the one exception: it lists the events you joined or played. |
| **saldo** | créditos, pro coins, monedas | Always in S/ ("S/ 15.00"). A top-up is a **recarga**; the screen is "Recargar saldo". |
| **ticket** | boleto, entrada | The QR you show at the door. |
| **grupo** | club, equipo | Owned by an organizer; events belong to a group. |
| **organizador** | admin (in copy) | Group owner/admin, or the event creator. |

## 5. Components

| Component | File | Notes |
| --- | --- | --- |
| `EventCard` | `lib/widgets/event_card.dart` | image on the **left** (owner decision), fixed height `kEventCardHeight` (164), image width `eventCardImageWidth` (168 above mobile, else 132). Dumb: takes the session and `onTap`; navigation lives in the caller. Seat bar turns `warning` at 3 seats or fewer |
| `EventCardSkeleton`, `Skeleton` | `lib/widgets/skeleton.dart` | loading placeholder with the same size constants; stops pulsing under reduced motion |
| `EventHero`, `EventBottomBar` | `lib/widgets/event_hero.dart`, `event_bottom_bar.dart` | detail screens: hero image with title, fixed action bar |
| `EventImage` | `lib/widgets/event_banner.dart` | banner if set, otherwise a sport photo |
| Filters | `lib/widgets/events_feed_view.dart` | sport and day-part chips, district menu pill, price and format fields, "Limpiar" chip, empty state with "Limpiar filtros" |
| Brand | `lib/widgets/brand.dart` | logo + "Pro" in text color, "Play" in `selectedText` |

Date and seat copy come from `lib/utils/event_format.dart` (`eventWhenLabel`, `seatsInfo`), tested.

If you change `EventCard`'s height or image width, change the shared constants, never a literal: the skeleton must stay the same size or the list jumps when it loads.

## 6. Imagery

- Events without a banner show a bundled stock photo: `sportPhoto(sport, seed)` in `lib/utils/sports.dart`, files `assets/images/sports/{sport}-{1..3}.webp`. The event id is the seed, so an event always shows the same photo. Never seed with `String.hashCode` (not stable across runs); use `stableHash`.
- Every photo needs a row in `assets/images/sports/CREDITS.md` (file, photographer, source URL, license). No photo without a recorded license. Avoid visible brand logos and text.
- Convert with ImageMagick: `magick in.jpg -resize 960x -strip -quality 78 out.webp`, aim for about 90 KB.
- Always keep an `errorBuilder` on `Image.asset` so a missing file shows a flat box instead of throwing.
- Sports and their icons come only from `kSports`.

## 7. Do and don't

- **Don't** hard-code `Colors.white`, `Colors.green`, `Colors.red` or inline `TextStyle` colors in screens. Use the theme or `AppColors`.
- **Don't** paint overlays with `foregroundDecoration`: it draws on top of the child and dims the text. Use a `Stack` with the gradient as a sibling behind the content.
- **Don't** restyle a card in one screen. Extend `EventCard` or the theme instead.
- **Don't** add a widget that calls Firebase or `AuthService`; widgets dispatch events.
- **Do** check changes in a built web app at 1920, 1280, 1024 and 390 px wide, as a guest and signed in.
- **Do** serve the build on a free port. Port 8099 is often held by another Flutter dev server, which then shows an older build and looks like your change did nothing (`ss -ltn | grep <port>`).
- **Do** keep text readable over photos: the dark bottom gradient stays.
- Web builds cache hard. After a rebuild, unregister the service worker or hard reload before judging.

## 8. Checklist for a new screen or component

1. Colors and text from the theme; headings via `headlineMedium` / `headlineSmall` / `titleLarge`.
2. Works at 390 px and 1280 px; respects the width caps above.
3. Has loading, empty and error states (use `Skeleton` for loading).
4. Hover and focus visible on web for anything tappable.
5. Spanish copy; no new packages; no Firebase calls in the widget.
6. If it is a primary destination: `GoRoute`, and update the routing table in `ARCHITECTURE.md`.
