# ProPlay — Agent Working Guide

ProPlay is a Flutter + Firebase app for organizing and discovering amateur sports sessions in Peru. Users join groups, match into nearby sessions, spend **pro coins**, and check in with QR tickets.

**Human onboarding:** [README.md](README.md)
**Living architecture (update this when the app changes):** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

This file is the short contract for coding agents. Prefer it over older copies in `CLAUDE.md` / `GEMINI.md` / `QWEN.md` if they disagree with the architecture guide.

---

## Architecture: BLoC only

Business logic stays out of widgets.

```
lib/
├── bloc/{feature}/     # *_bloc.dart, *_event.dart, *_state.dart
├── models/             # Firestore / payment models
├── services/           # Auth, Firestore, Storage, payments — I/O only
├── screens/            # Full-page UI
├── widgets/            # Shared UI
└── utils/              # Helpers (auth, geohash, ticket URLs, breakpoints)
```

1. Widgets dispatch events. They do not call Firebase (do not copy `CreditApprovalScreen` / `CreditHistoryScreen`).
2. BLoCs orchestrate use cases and emit `Equatable` states.
3. Services are constructor-injected into BLoCs.
4. After a write that changes the signed-in user, dispatch `AuthRefreshUserRequested`.

```dart
// Correct
context.read<AuthBloc>().add(AuthLoginRequested(email: email, password: password));

// Wrong
await AuthService().signInWithEmailAndPassword(email, password);
```

Current user:

```dart
final user = context.currentUser; // read
final user = context.watchUser;   // rebuild on auth change
bool ok = context.isAuthenticated;
```

---

## Firebase

Project: **`proplay-eac23`**. Hosted web app: https://proplayapp.com

Services in use: Auth (email/password + Google), Firestore, Storage, Hosting.

**Do not hand-edit:** `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`.

Rules (`firestore.rules`), indexes and Cloud Functions (`functions/`, TypeScript, region `southamerica-east1`) are in git but **deployed by hand** (order: rules → functions → backfill → hosting; see README). `cancelParticipation` (callable) refunds server-side; `mirrorPublicEvent` (Firestore trigger) projects public `liveSessions` into `publicEvents`. Join and credit approval are still client writes. Treat that as a known risk; do not loosen it further.

### Collections that exist in code

```
users/{uid}
  └─ groups/{groupId}                 # { role, joinedAt }
groups/{groupId}
  └─ members/{userId}                 # { role, joinedAt }  source of truth for membership
sessionTemplates/{templateId}
liveSessions/{sessionId}              # players[] embedded on the document
publicEvents/{sessionId}              # server-written projection of public events (no players), readable by anyone
tickets/{sessionId}_{userId}
creditHistory/{id}
yape/{firstDoc}                       # { name, phone, qr }
```

Credits on the **user** are a **string** with 2 decimals (`"15.00"`). Ledger amounts are **doubles**. Always use `UserModel.formatCredits` / `creditsValue`.

Sport values must stay canonical: `fútbol`, `baloncesto`, `voleibol`, `tenis`, `natación`, `running`, `ciclismo`, `gimnasio`, `pádel`, `béisbol`.

Full field lists: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#7-firestore-data-model).

---

## Routing

`go_router` in `lib/main.dart` is auth-gated. Unauthenticated users only see `/welcome` (landing), `/login`, `/registration` and the public feed `/events` + `/events/:id` (read-only, `publicEvents` only).

Primary routes: `/`, `/events`, `/events/:id`, `/sessions` (same feed), `/create-group`, `/edit-profile`, `/purchase-credits`, `/tickets`, `/validate-ticket`, `/group/:id`, `/group/:id/edit`, `/group/:id/info`, `/payment/{success,pending,failure}`.

These screens are still `Navigator.push` only (no deep link): session create/detail/map, ticket detail, credit history, credit approval.

New primary destinations go in `GoRouter`. Update the table in `docs/ARCHITECTURE.md`.

---

## Feature map (shipped)

| Area | Entry | Notes |
| --- | --- | --- |
| Auth | `AuthBloc` + `AuthService` | Email, Google, password reset, optional group code on register |
| Profile | `UserBloc` | Name, photo, gender/age, sports |
| Groups | `GroupBloc` / `GroupDetailBloc` / `GroupEditBloc` | Create, join by 6-char code, roles `owner`/`admin`/`member` |
| Sessions | `CreateSessionBloc`, `SessionBloc`, `SessionDetailBloc` | Template + first live session; join is a Firestore transaction |
| Matchmaking | `SessionService.getAllUpcomingSessions` | Sport, gender, age, optional geohash radius |
| Credits | `CreditBloc` + Yape | Pending purchase; `superUser` approves in `CreditApprovalScreen` |
| Tickets | `TicketService`, `MyTicketsBloc`, `ValidateTicketBloc` | Created atomically on join; validate via token URL; a cancelled ticket is deleted |
| Events feed | `EventsFeedBloc`, `PublicEventBloc` | Public feed with sport/district/day-part/price/format filters; guests allowed; Home leads with it |

Join transaction (`SessionService.joinSession`): check seats + balance → debit credits → ledger spend → append player → write ticket. Cancel: `SessionDetailBloc` `CancelParticipation` → `SessionService.cancelParticipation` → callable `cancelParticipation` frees the seat, deletes the ticket and refunds in full (once per ledger `spend` row, capped at the event price) when the event is 24 h or more away (server time); otherwise no refund. Cancelling after the event started is rejected. Admin remove (`removeUserFromSession`) does **not** refund. There is no client-side leave.

Live payment path is **manual Yape**, not the stub `PaymentService` / Mercado Pago samples. Details: [docs/PAYMENT_SYSTEM.md](docs/PAYMENT_SYSTEM.md).

---

## Conventions

### File names

- Screens: `{name}_screen.dart`
- Loaders: `{name}_screen_loader.dart`
- Widgets: `{name}.dart`
- Models: `{name}_model.dart`
- Services: `{name}_service.dart`
- BLoCs: `{name}_bloc.dart`, `{name}_event.dart`, `{name}_state.dart`

### Imports

Flutter → package imports → `package:proplay/...`

### UI

- `BlocBuilder` for rebuilds, `BlocListener` for snackbars/navigation, `BlocConsumer` when both.
- Product copy is Spanish. Developer docs are English.
- Theme primary: `#BA1B1D`. Responsive via `responsive_framework` (`ResponsiveLayout`, drawer vs `AppSidebar`).

### Adding work

| Task | Steps |
| --- | --- |
| New screen | File in `lib/screens/`, BLoC if needed, `GoRoute`, update architecture doc |
| New BLoC | Folder under `lib/bloc/`, inject services, provide near the screen |
| New collection | Model `toMap`/`fromMap`, service, BLoC, document in architecture §7 |
| New auth action | `AuthService` → event → handler → UI dispatch |

---

## Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test          # pure-function/model tests; the default counter smoke test (needs Firebase) fails and is pre-existing
(cd functions && npm install && npm run build && npm test)
(cd functions && npm run test:emulator)   # rules + cancelParticipation + trigger + backfill on the Firestore/Functions emulators (needs Java)
flutter build web
npx -y firebase-tools@latest deploy --only hosting
```

Version: `1.0.7+10` (`pubspec.yaml`). Dart SDK `^3.13.0`.

---

## Do not regress these

- Do not put Firebase calls in new widgets.
- `analysis_options.yaml` includes `flutter_lints` but the dev dependency is commented out in `pubspec.yaml`; `flutter analyze` always reports `include_file_not_found`. Uncomment it to fix.
- Do not store user credits as a raw `num` without going through `formatCredits`.
- Do not add a sport in only one of the duplicated sport lists — extract a shared constant if you touch them.
- Do not treat `GroupService.streamUserGroups` as correct membership (it queries a `members` array that create/join do not write).
- Do not implement card collection against `CardDetails` (PCI). Gateway SDK / redirect only.
- Do not hand-roll another credit write outside a transaction if a race is possible.

---

## Status

**Done:** auth (email + Google + reset), profiles, groups + roles, session create/join, matchmaking (sport/gender/age/distance), Yape credits + admin approval, tickets + QR validation, public events feed (guests), cancel with refund (Cloud Function), responsive shell, Firebase Hosting.

**Not done / leftover:** automated payment gateway, recurring sessions, waitlist, refund on organizer deletion / admin removal, email verification, more tests (blocs, widgets), locking `users.credits` / `liveSessions` rules, moving join/credits server-side, aligning remaining screens on GoRouter.

Pitfalls and full flows: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
