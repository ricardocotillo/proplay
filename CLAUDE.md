# ProPlay — Agent Working Guide

Same contract as [AGENTS.md](AGENTS.md) (keep the two in sync; `GEMINI.md` / `QWEN.md` are pointers). The living human/dev architecture doc is [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). UI rules (tokens, layout, components, imagery) are in [docs/DESIGN.md](docs/DESIGN.md). Onboarding is [README.md](README.md).

If anything here drifts, treat **docs/ARCHITECTURE.md** as source of truth for how the app actually works.

---

ProPlay is a Flutter + Firebase app for organizing and discovering sports sessions in Peru. Users join groups, match into nearby sessions, pay from their **saldo** (credits, 1 credit = S/ 1), and check in with QR tickets. User-facing copy says "saldo" in S/, never "pro coins".

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

1. Widgets dispatch events. They do not call Firebase (do not copy `CreditHistoryScreen`).
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

Rules (`firestore.rules`), indexes and Cloud Functions (`functions/`, TypeScript, region `southamerica-east1`) are in git but **deployed by hand** (order: functions → backfill → hosting → rules, once mobile users are on the current build; see README). `joinSession` (callable) joins server-side (balance, seats, ledger, ticket in one transaction); `cancelParticipation` (callable) refunds server-side; `reviewCreditPurchase` (callable, superUser) approves or rejects a Yape top-up in one transaction; `cancelEvent` / `removePlayer` (callables, organizer) refund every player / the removed player in full; `checkInPlayer` (callable, organizer) toggles a player's check-in; `autoCancelUnderfilled` (scheduled) cancels and refunds an event with `minPlayers` that is short of players in the hour after the 24 h mark (same transaction as `cancelEvent`); `joinWaitlist` / `leaveWaitlist` (callables) and `expireWaitlistOffers` (scheduled) run the waitlist: a freed seat is offered to the first in line for 30 min and held (`joinSession` counts held seats as taken), they confirm with `joinSession`, and a late canceller is paid back when a waitlist fill takes their seat; `sendReminders` (scheduled, every 10 min), `notifyCreditApproved` and `claimDeviceToken` (triggers) send web push via FCM to `users/{uid}/fcmTokens`; `mirrorPublicEvent` (Firestore trigger) projects public `liveSessions` into `publicEvents`. Money and seats are server-only: clients cannot write `users.credits`, `liveSessions.players` / `playerCount`, tickets (except staff validation) or any `creditHistory` row other than their own pending Yape top-up, and nobody deletes a `liveSessions` doc from the client. Never loosen these; add a callable instead. Event limits in the rules: with players joined the date is frozen and `minPlayers` can only go down; `maxPlayers` is capped at 60 (one-transaction refunds). Identity-document locks live in `documents/` (see docs/ARCHITECTURE.md); `firestore.rules` is the single source for rules, so never deploy it without first diffing against the console. `firestore.indexes.json` mirrors the live indexes (export with `npx -y firebase-tools@latest firestore:indexes`); a new composite query needs its index added there, or the deploy offers to delete the live one.

### Collections that exist in code

```
users/{uid}
  └─ groups/{groupId}                 # { role, joinedAt }
groups/{groupId}
  └─ members/{userId}                 # { role, joinedAt }  source of truth for membership
sessionTemplates/{templateId}
liveSessions/{sessionId}              # players[] embedded on the document
  ├─ waitlist/{uid}                   # server-written; the user reads only their own
  └─ lateCancels/{uid}                # server-only: late cancels waiting for a waitlist fill
publicEvents/{sessionId}              # server-written projection of public events (no players), readable by anyone
tickets/{sessionId}_{userId}
documents/{type}_{number}              # DNI/CE uniqueness lock { uid, createdAt }
users/{uid}/fcmTokens/{token}         # web push device { createdAt, platform, token }
notificationsSent/{kind}_{id}         # server-only: claims a notification
creditHistory/{id}
yape/{firstDoc}                       # { name, phone, qr }
```

Credits on the **user** are a **string** with 2 decimals (`"15.00"`). Ledger amounts are **doubles**. Always use `UserModel.formatCredits` / `creditsValue`.

Sport values must stay canonical: `fútbol`, `baloncesto`, `voleibol`.

Full field lists: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#7-firestore-data-model).

---

## Routing

`go_router` in `lib/main.dart` is auth-gated. Unauthenticated users only see `/welcome` (landing), `/login`, `/registration` and the public feed `/events` + `/events/:id` (read-only, `publicEvents` only). Other deep links send guests to `/login?from=<link>`. URLs are real paths (`usePathUrlStrategy`), not `/#/`.

Primary routes: `/welcome`, `/`, `/events`, `/events/:id`, `/sessions` (same feed), `/create-group`, `/edit-profile`, `/groups`, `/profile`, `/purchase-credits`, `/credit-history`, `/credit-approval` (super user), `/tickets`, `/tickets/:id`, `/validate-ticket`, `/group/:id`, `/group/:id/create-event`, `/group/:id/edit`, `/group/:id/info`, `/payment/{success,pending,failure}`.

`/events/:id` is the one event page (`EventScreen`): the full view (`SessionDetailScreen`) when signed in, the read-only public view for guests, switching in place on sign-in. Link to events, tickets and event creation with `eventPath` / `ticketPath` / `createEventPath` (`lib/utils/app_paths.dart`) and `context.push`. Only the session map is still `Navigator.push`.

Every primary route is inside a `ShellRoute` (`AppShell`): desktop gets `AppTopBar`, mobile gets a bottom bar (`AppBottomNav`) for signed-in users on the top level of each destination. The four destinations are Explorar (`/`, `/events`), Mis partidos (`/tickets`), Grupos (`/groups`), Perfil (`/profile`), defined once in `lib/utils/shell_nav.dart`. There is no drawer.

New primary destinations go in `GoRouter`. Update the table in `docs/ARCHITECTURE.md`.

---

## Feature map (shipped)

| Area | Entry | Notes |
| --- | --- | --- |
| Auth | `AuthBloc` + `AuthService` | Email, Google, password reset, optional group code on register |
| Profile | `UserBloc` | Name, photo, gender/age, sports |
| Groups | `GroupBloc` / `GroupDetailBloc` / `GroupEditBloc` | Create, join by 6-char code, roles `owner`/`admin`/`member` |
| Sessions | `CreateSessionBloc`, `SessionBloc`, `SessionDetailBloc` | Template + first live session; join is the `joinSession` callable |
| Matchmaking | `SessionService.getAllUpcomingSessions` | Sport, gender, age, optional geohash radius |
| Credits | `CreditBloc` + Yape | Pending purchase; `superUser` approves or rejects in `CreditApprovalScreen` (`CreditApprovalCubit` → `reviewCreditPurchase`) |
| Tickets | `TicketService`, `MyTicketsBloc`, `ValidateTicketBloc` | Created atomically on join; validate via token URL; a cancelled ticket is deleted |
| Events feed | `EventsFeedBloc`, `PublicEventBloc` | Public feed with sport/district/day-part/price/format filters; guests allowed; Home leads with it |

Join (`SessionService.joinSession` → callable `joinSession`): server checks access, start time, seats and balance → debit → ledger spend → append player → write ticket; a retry returns the existing ticket. Cancel: `SessionDetailBloc` `CancelParticipation` → `SessionService.cancelParticipation` → callable `cancelParticipation` frees the seat, deletes the ticket and refunds in full (once per ledger `spend` row, capped at the event price) when the event is 24 h or more away (server time); otherwise no refund. Cancelling after the event started is rejected. Organizer actions (group owner/admin, event `creatorId` or superUser, one rule `canManageEvent` on client and server; cancel/remove before the event starts; check-in any time): "Cancelar evento" in the event's menu → `SessionDetailBloc` `CancelEvent` → callable `cancelEvent` refunds every player in full (no 24 h window), deletes tickets and the event; "Retirar" on a player → callable `removePlayer` frees the seat, deletes the ticket and refunds in full (refused for a used ticket). The group list has no swipe-to-delete. There is no client-side leave.

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
- Theme primary: `#BA1B1D`. Dark theme only (`AppTheme.dark`). Responsive via `responsive_framework` (`ResponsiveLayout`, bottom bar on mobile vs `AppTopBar` on desktop).
- Before building or restyling UI read [docs/DESIGN.md](docs/DESIGN.md): colors and text come from the theme, headings use the bundled display font, event cards and skeletons share size constants.

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
(cd functions && npm run test:emulator)   # rules + join, cancel, organizer, credit-review and reminders + trigger + backfill on the Firestore/Functions emulators (needs Java)
flutter build web
npx -y firebase-tools@latest deploy --only hosting
```

Version: `1.0.7+10` (`pubspec.yaml`). Dart SDK `^3.13.0`.

---

## Do not regress these

- Do not put Firebase calls in new widgets.
- `analysis_options.yaml` includes `flutter_lints` but the dev dependency is commented out in `pubspec.yaml`; `flutter analyze` always reports `include_file_not_found`. Uncomment it to fix.
- Do not store user credits as a raw `num` without going through `formatCredits`.
- Sports live only in `kSports` (`lib/utils/sports.dart`); never add a local sport list.
- Identity document (DNI/CE) is mandatory and unique: always create users via `UserService.createUserWithDocument`, never `createUser`.
- Do not treat `GroupService.streamUserGroups` as correct membership (it queries a `members` array that create/join do not write).
- Do not implement card collection against `CardDetails` (PCI). Gateway SDK / redirect only.
- Do not hand-roll another credit write outside a transaction if a race is possible.
- Do not hard-code `Colors.white` / `Colors.green` / `Colors.red` or inline `TextStyle` colors in screens: use `Theme.of(context)` or `AppColors` (`lib/theme/`). Errors use `AppColors.error`, never the brand red.
- Headings use the theme's display styles (`headlineMedium`, `headlineSmall`, `titleLarge`, bundled Barlow Condensed via `kDisplayFont`); do not add fonts or `google_fonts`.
- Event card size lives in `kEventCardHeight` / `eventCardImageWidth` (`lib/widgets/event_card.dart`) and is shared with `EventCardSkeleton`; never hard-code a second copy.
- Every photo in `assets/images/` needs a source and license in the `CREDITS.md` next to it. Seed photo variants with `stableHash`, never `String.hashCode`.
- Overlays on images or text go in a `Stack` behind the content, not in `foregroundDecoration` (it paints over the text).

---

## Status

**Done:** auth (email + Google + reset), profiles, groups + roles, session create/join, matchmaking (sport/gender/age/distance), Yape credits + admin approval, tickets + QR validation, public events feed (guests), cancel with refund (Cloud Function), responsive shell, Firebase Hosting.

**Not done / leftover:** email and mobile push (web push only), automated payment gateway, recurring sessions, email verification, more tests (blocs, widgets), aligning remaining screens on GoRouter.

Pitfalls and full flows: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
