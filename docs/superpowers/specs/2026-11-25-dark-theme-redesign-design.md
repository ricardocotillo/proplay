# Dark theme redesign

Date: 2026-11-25. Status: draft, awaiting approval.

## Intent

The app looks too white, too minimal, dated, inconsistent between screens, and not like a web app. The owner chose the "A · Dark sport" direction from three mockups: dark surfaces, brand red `#BA1B1D` as the accent, a red gradient hero, high contrast, a feel closer to a sports/fitness product than a generic Material app. The whole app goes dark, including login, registration and landing.

## Goals

- One dark `ThemeData` that every screen inherits, so look and feel is consistent by construction.
- Screens stop hard-coding colors and text styles; they read them from the theme.
- Web feels like a web app: max content width, hover states on cards/buttons/nav, desktop shell polished.
- Core user path restyled first: shell (sidebar/drawer/app bar), events feed, event card, event detail, join, tickets.

## Non-goals

- No light theme or theme toggle (can be added later if the theme is built on `ColorScheme`).
- No changes to BLoCs, services, models, Firestore, routing or Cloud Functions.
- No new features, no copy changes (product copy stays Spanish).
- No new top-nav layout on desktop: keep the existing `AppSidebar` (desktop) / `AppDrawer` (mobile) structure and restyle it. The mockup showed a top bar; that is a possible follow-up, not part of this work.

## Anti-goals

- A restyle that leaves some screens white or unreadable (white text on white, or dark text on dark).
- Regressing the join, credits, ticket or QR validation flows.
- Adding a design package or dependency for something the stock theme can express.

## Constraints

- Flutter app, BLoC only. Styling stays in widgets and a theme file; no Firebase calls in widgets.
- Brand primary stays `#BA1B1D`. Sports stay from `kSports`; credits formatting unchanged.
- Responsive via `responsive_framework` (`ResponsiveLayout`, `ResponsiveConstrainedBox`), existing breakpoints.
- Today the theme in `lib/main.dart` sets only a light `ColorScheme`, red AppBar and elevated button. `error` equals `primary`.
- Recon: about 172 hard-coded color references in 23 files (heaviest: `session_detail_screen`, `purchase_credits_screen`, `credit_approval_screen`, `validate_ticket_screen`, `credit_history_screen`), 29 of them white, plus about 106 inline `TextStyle(`.
- QR codes must stay scannable: keep a light background behind the QR image on ticket screens.

## Approaches considered

1. **Theme first, then sweep screens (chosen).** Build the dark theme, then replace hard-coded colors/styles screen by screen. Trade-off: screens look broken between step 1 and the sweep, so it ships as one PR or a few per area.
2. Screen by screen with no theme work. Faster first screens but recreates the inconsistency and needs a theme refactor later.
3. Light and dark together. Doubles design and testing; not requested.

Owner picked 1, dark only, whole app.

## Design

- **Theme file** `lib/theme/app_theme.dart` (new) exporting `AppTheme.dark`, used by `MaterialApp.router` in `lib/main.dart` instead of the inline theme. Includes:
  - `ColorScheme.dark` with primary `#BA1B1D`; surface/background near-black (mockup used `#0F1115` page, `#16181D` bars, `#1A1D23` cards, `#262A31` borders; text `#F2F3F5`, muted `#8A909B`). Red tint for selected states (mockup `#2A1517`, text `#FF5A5C`). A distinct error color (not the brand red) and a success color.
  - Text theme with a clear scale (display/title/body/label), consistent weights.
  - Component themes: AppBar, Card (radius ~14, 1px border), ElevatedButton/FilledButton/OutlinedButton/TextButton (pill or 12px radius), InputDecoration (filled dark fields, red focus), ChipTheme (pill, red when selected), Drawer/NavigationDrawer, Dialog, BottomSheet, SnackBar, Divider, ListTile, Switch/Checkbox.
- **Small constants file** `lib/theme/app_colors.dart` for values the `ColorScheme` can't hold (hero gradient `#BA1B1D → #6E0F11`, muted text, success). Spacing/radius constants only if screens need them.
- **Shell**: restyle `AppSidebar`, `AppDrawer`, `WalletIndicator` (credit pill in red), app bars. Add hover state to sidebar items on web.
- **Web**: wrap main content in a max width (about 1100–1200) on large screens via the existing responsive helpers; hover/pointer feedback on event cards and buttons.
- **Events feed** (`events_feed_view.dart`, `home_screen.dart`): red gradient hero ("Juega esta semana"-style), filter chips, dark event cards with the left banner kept, price in accent red, primary "Unirme" style action.
- **Sweep order**: shell and feed, event card and detail (`public_event_screen`, `session_detail_screen`), tickets (`my_tickets_screen`, `ticket_detail_screen`, `validate_ticket_screen`), credits (`purchase_credits_screen`, `credit_history_screen`, `credit_approval_screen`, payment result screens), groups, create/edit screens, auth and landing, profile.
- Replace `Colors.white`/hard-coded colors and inline `TextStyle` with `Theme.of(context)` lookups. Leave deliberate exceptions (QR background, sport/brand imagery) and comment them.
- Update `docs/ARCHITECTURE.md` with a short Theming section pointing to `lib/theme/`.

## Verification

- `flutter analyze` (known `include_file_not_found` only) and existing `flutter test`.
- Run on web at mobile and desktop widths and look at every screen: no white leftovers, readable text, visible focus/hover, QR still scannable.
- Add one small theme test (the theme builds, key component themes set, error color differs from primary).

## Left to the builder

Exact palette tweaks beyond the mockup values, font choice (system default unless a font is clearly worth bundling), per-screen layout details, how to split into PRs, and the exact max content width.

## Calls made without the owner (check these)

- **Hero is a restyle only.** `home_screen.dart` already has a "Juega como un pro" heading (around line 211). The hero is that existing heading and copy on the red gradient. No new strings, no new data, no `EventsFeedBloc` changes. The mockup's "34 partidos cerca de ti" count and "Juega esta semana" copy were illustrative and are not required.
- **Mockups are illustrative.** They live in the untracked `.superpowers/brainstorm/` folder (gitignored). The doc's hex values and layout notes are the spec; the builder should not need the mockup files.
- **Dark theme ships globally and all at once.** `AppTheme.dark` is switched on for the whole app, so the full sweep must be done before release. Work is staged as commits per area on one feature branch and merged as one PR, so `main` never has a half-dark app. "Core path first" only sets the order of the sweep, not an acceptable end state.
- Google sign-in button on the dark login screen follows the standard dark Google button style.

- Keep sidebar/drawer shell; no new top nav.
- No new fonts or packages.
- Dark only; light theme is out of scope.
- QR background stays light.
