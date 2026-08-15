# ProPlay

ProPlay is a Flutter app for organizing and discovering amateur sports sessions ("pichangas") in Peru. Players join groups, find nearby public sessions that match their sport / age / gender, pay with **pro coins**, and check in with a QR ticket.

This README is the onboarding entry point. Architecture, data model, and how-to-change-the-app live in the living guide:

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — keep this file up to date as the app grows.

## What the product does

- **Accounts**: email/password, Google sign-in, password reset, profile + sports preferences.
- **Groups**: create or join with a 6-character code. Owners/admins manage members and sessions.
- **Sessions**: multi-step create flow (location, date/time, details). Templates write the first `liveSession`.
- **Matchmaking**: upcoming list is filtered by sport, gender, age, group membership, and geohash distance.
- **Credits ("pro coins")**: users buy packages via **Yape** and wait for a `superUser` to approve. Joining a session debit-charges credits.
- **Tickets**: joining a session creates a ticket with a QR / shareable validation URL. Group owners, admins, and super users can mark tickets used.

UI language is Spanish. Currency is PEN.

## Stack

| Layer | Choice |
| --- | --- |
| App | Flutter (Dart SDK `^3.8.0`), current version `1.0.7+10` |
| State | BLoC (`flutter_bloc` + `equatable`) |
| Routing | `go_router` (auth + primary screens) plus `Navigator.push` for some detail flows |
| Backend | Firebase project **`proplay-eac23`** |
| Auth | Firebase Auth (email/password + Google) |
| Data | Cloud Firestore |
| Files | Firebase Storage (profile, group, receipt images) |
| Maps | Google Maps + `map_location_picker`, `geolocator`, `dart_geohash` |
| Layout | `responsive_framework` (mobile drawer / desktop sidebar) |
| Hosting | Firebase Hosting serves `build/web` at [proplayapp.com](https://proplayapp.com) |

There is **no Cloud Functions package** in this repo. Business writes currently happen from the client (including credit debit and ticket create).

## Documentation map

Read these in this order if you are new:

1. This README — setup and product overview
2. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — layers, Firestore, flows, conventions, known pitfalls
3. Feature notes (some are design history; the architecture guide says what is actually shipped):

| Document | What it is |
| --- | --- |
| [docs/PAYMENT_SYSTEM.md](docs/PAYMENT_SYSTEM.md) | Current Yape + admin-approval credit flow |
| [docs/PAYMENT_GATEWAY_MIGRATION_PLAN.md](docs/PAYMENT_GATEWAY_MIGRATION_PLAN.md) | Planned automated gateway (not the live path) |
| [docs/MATCHMAKING.md](docs/MATCHMAKING.md) / [docs/MATCHMAKING_2.md](docs/MATCHMAKING_2.md) | Matchmaking criteria and status |
| [docs/multi_step_session_creation.md](docs/multi_step_session_creation.md) | Session create wizard |
| [docs/sessions.md](docs/sessions.md) | Early sessions design (players subcollection was **not** implemented) |
| [docs/geofirestore.md](docs/geofirestore.md) | Reference for geohash queries |
| [docs/map_picker.md](docs/map_picker.md) | Vendor notes for `map_location_picker` |
| [docs/reporte.md](docs/reporte.md) / [docs/reporte_pasarela.md](docs/reporte_pasarela.md) | Investor / payment reports (Spanish) |

Agent working notes: [AGENTS.md](AGENTS.md), [CLAUDE.md](CLAUDE.md).

## Prerequisites

- Flutter SDK that satisfies `sdk: ^3.8.0` (`flutter doctor` should be clean for the platform you target)
- A Firebase login with access to **`proplay-eac23`**
- Android Studio / Xcode only if you run native Android or iOS
- Google Maps keys are already wired for Android, iOS, and web (see architecture guide)

## Setup

```bash
git clone <repo-url>
cd proplay
flutter pub get
```

Do **not** hand-edit generated Firebase files:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

If you need to reconfigure platforms, use the FlutterFire CLI.

## Run

```bash
# list devices
flutter devices

flutter run                     # default device
flutter run -d chrome           # web
flutter run -d <android-id>
flutter run -d <ios-id>
```

Spanish date formatting is initialized at startup (`initializeDateFormatting('es')`).

## Common commands

```bash
flutter pub get
flutter analyze
flutter test                    # currently still the default counter smoke test
flutter build apk
flutter build ios
flutter build web
```

Web deploy (Hosting public dir is `build/web`, SPA rewrite to `index.html`):

```bash
flutter build web
npx -y firebase-tools@latest deploy --only hosting
```

App icon generation:

```bash
dart run flutter_launcher_icons
```

## Repo layout

```
lib/
  main.dart                 # Firebase init, providers, GoRouter, theme
  bloc/                     # Feature BLoCs (events / states / logic)
  models/                   # Firestore / payment models
  services/                 # Firebase and payment I/O only
  screens/                  # Full-page UI
  widgets/                  # Shared UI (drawer, sidebar, maps helpers)
  utils/                    # Auth helpers, geohash, ticket URLs, breakpoints
docs/                       # Living architecture + feature notes
android/ ios/ web/          # Platform shells and Firebase / Maps config
```

## First-week orientation

1. Skim `lib/main.dart` — providers, auth redirect, route table.
2. Read `lib/models/user_model.dart`, `group_model.dart`, `session_model.dart`, `ticket_model.dart`, `credit_history_model.dart`.
3. Follow one vertical slice end to end, for example **join session**:
   `SessionDetailScreen` → `SessionDetailBloc` → `SessionService.joinSession` (transaction: credits + players + ticket).
4. Then read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the data model, roles, and current pitfalls.

## Support / conventions

- Keep business logic out of widgets. Dispatch BLoC events; put I/O in services.
- After you change architecture, data shape, routes, or a product flow, update **`docs/ARCHITECTURE.md`** in the same PR.
- Product UI copy is Spanish; developer docs in this repo are English unless the file is an existing Spanish report.
