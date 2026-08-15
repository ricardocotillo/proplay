# ProPlay — Agent Working Guide

This file matches [AGENTS.md](AGENTS.md). The living human/dev architecture doc is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Onboarding is [README.md](README.md).

If anything here drifts, treat **docs/ARCHITECTURE.md** as source of truth for how the app actually works.

---

ProPlay is a Flutter + Firebase app for organizing and discovering amateur sports sessions in Peru. Users join groups, match into nearby sessions, spend **pro coins**, and check in with QR tickets.

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

There is no Cloud Functions package and no rules/index files in git. Client code currently performs sensitive writes (join + credit debit). Treat that as a known risk; do not loosen it further.

### Collections that exist in code

```
users/{uid}
  └─ groups/{groupId}                 # { role, joinedAt }
groups/{groupId}
  └─ members/{userId}                 # { role, joinedAt }  source of truth for membership
sessionTemplates/{templateId}
liveSessions/{sessionId}              # players[] embedded on the document
tickets/{sessionId}_{userId}
creditHistory/{id}
yape/{firstDoc}                       # { name, phone, qr }
```

Credits on the **user** are a **string** with 2 decimals (`"15.00"`). Ledger amounts are **doubles**. Always use `UserModel.formatCredits` / `creditsValue`.

Sport values must stay canonical: `fútbol`, `baloncesto`, `voleibol`, `tenis`, `natación`, `running`, `ciclismo`, `gimnasio`, `pádel`, `béisbol`.

Full field lists: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#7-firestore-data-model).

---

## Routing

`go_router` in `lib/main.dart` is auth-gated. Unauthenticated users only see `/login` and `/registration`.

Primary routes: `/`, `/sessions`, `/create-group`, `/edit-profile`, `/purchase-credits`, `/tickets`, `/validate-ticket`, `/group/:id`, `/group/:id/edit`, `/group/:id/info`, `/payment/{success,pending,failure}`.

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
| Tickets | `TicketService`, `MyTicketsBloc`, `ValidateTicketBloc` | Created atomically on join; validate via token URL |

Join transaction (`SessionService.joinSession`): check seats + balance → debit credits → ledger spend → append player → write ticket. Leave/remove does **not** refund or delete the ticket.

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
flutter test          # default counter test only — not a real suite
flutter build web
npx -y firebase-tools@latest deploy --only hosting
```

Version: `1.0.7+10` (`pubspec.yaml`). Dart SDK `^3.8.0`.

---

## Do not regress these

- Do not put Firebase calls in new widgets.
- Do not store user credits as a raw `num` without going through `formatCredits`.
- Do not add a sport in only one of the duplicated sport lists — extract a shared constant if you touch them.
- Do not treat `GroupService.streamUserGroups` as correct membership (it queries a `members` array that create/join do not write).
- Do not implement card collection against `CardDetails` (PCI). Gateway SDK / redirect only.
- Do not hand-roll another credit write outside a transaction if a race is possible.

---

## Status

**Done:** auth (email + Google + reset), profiles, groups + roles, session create/join, matchmaking (sport/gender/age/distance), Yape credits + admin approval, tickets + QR validation, responsive shell, Firebase Hosting.

**Not done / leftover:** automated payment gateway, recurring sessions, waitlist, refunds on leave/cancel, email verification, rules/indexes in repo, real tests, moving join/credits server-side, aligning remaining screens on GoRouter.

Pitfalls and full flows: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
