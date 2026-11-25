# Dark Theme Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** Whole app dark with one shared `ThemeData`; screens read colors/text styles from the theme.

**Architecture:** `lib/theme/app_colors.dart` holds constants the `ColorScheme` cannot; `lib/theme/app_theme.dart` exposes `AppTheme.dark`; `main.dart` uses it in both `MaterialApp`s. Then sweep screens replacing hard-coded colors and inline `TextStyle` with `Theme.of(context)` lookups.

**Tech Stack:** Flutter, Material 3, responsive_framework. No new packages or fonts.

**Spec:** `docs/superpowers/specs/2026-11-25-dark-theme-redesign-design.md`

## Global Constraints

- Brand primary `#BA1B1D`; page `#0F1115`, bars `#16181D`, cards `#1A1D23`, borders `#262A31`, text `#F2F3F5`, muted `#8A909B`, selected tint `#2A1517` / text `#FF5A5C`, hero gradient `#BA1B1D -> #6E0F11`.
- Error color differs from primary. Dark only. QR background stays light.
- No BLoC/service/model/routing/Firestore changes. Spanish copy unchanged.
- `flutter analyze`: only known `include_file_not_found`.

## Review Focus

- White-on-white / dark-on-dark leftovers: grep `Colors.white|black|grey|red` after each task.
- QR image keeps light background (ticket detail).
- Inputs (login/registration/forms) readable: filled dark, visible label and focus.
- Dialogs, bottom sheets, snackbars inherit dark.
- Wide web: feed content not stretched past ~1100px.

---

### Task 1: Theme files, test, wiring
**Files:** Create `lib/theme/app_colors.dart`, `lib/theme/app_theme.dart`, `test/app_theme_test.dart`; modify `lib/main.dart`.
**Produces:** `AppColors.{page,bar,card,border,text,muted,selectedTint,selectedText,success,warning,error}` (`static const Color`), `AppColors.heroGradient` (`LinearGradient`), `AppTheme.dark` (`static ThemeData get`).
- [ ] Test: brightness dark; primary `0xFFBA1B1D`; `error != primary`; `inputDecorationTheme.filled == true`; `appBarTheme.backgroundColor == AppColors.bar`.
- [ ] Implement theme (AppBar, Card, buttons, InputDecoration, Chip, Drawer, Dialog, BottomSheet, SnackBar, Divider, ListTile, Switch, Checkbox, TabBar, progress). Wire `theme: AppTheme.dark` in both MaterialApps.
- [ ] Run `flutter test test/app_theme_test.dart`; commit.

### Task 2: Shell, feed, home hero
**Files:** `widgets/{app_sidebar,app_drawer,wallet_indicator,events_feed_view}.dart`, `screens/home_screen.dart`, `screens/groups_sessions_screen.dart`.
- [ ] Theme lookups; sidebar hover; red wallet pill; hero = existing heading on `AppColors.heroGradient`; feed max width ~1100; commit.

### Task 3: Event detail — `session_detail_screen.dart`. Sweep; commit.
### Task 4: Tickets — `my_tickets`, `ticket_detail`, `validate_ticket`. Sweep; QR container stays white with comment; commit.
### Task 5: Credits — `purchase_credits`, `credit_history`, `credit_approval`, `payment_{success,pending,failure}`. Sweep; commit.
### Task 6: Groups, auth, landing, profile — `create_group`, `group_detail`, `group_edit`, `group_info`, `edit_profile`, `landing`, login/registration, create-session. Sweep; commit.
### Task 7: Docs, gitignore, verify, PR
- [ ] `.gitignore` add `.superpowers/`; ARCHITECTURE.md Theming section.
- [ ] Run web at 390px and 1280px, check each screen; fix leftovers.
- [ ] `flutter analyze`, `flutter test`; open PR to `main`.
