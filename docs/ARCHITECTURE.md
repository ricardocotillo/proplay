# ProPlay Architecture & Maintainability Guide

Living document. Update this file in the same PR whenever you change architecture, Firestore shape, routes, providers, or a user-facing flow.

Last reviewed against the codebase: 2026-11-13. App version in `pubspec.yaml`: **1.0.7+10**.

---

## 1. Product snapshot

ProPlay connects amateur athletes in Peru with group and public sports sessions.

| Concept | Meaning |
| --- | --- |
| **Group** | A club/community around one sport. Join via a 6-character code. |
| **Session template** | The "recipe" written when someone creates an event. |
| **Live session** | The joinable instance shown on Home / Sessions / group pages. |
| **Pro coins** | In-app credits stored on the user. Currency of purchase is PEN. |
| **Ticket** | Proof of join. QR + `https://proplayapp.com/validate-ticket?token=...`. |
| **Super user** | Admin flag on the user document. Can approve Yape purchases and validate any ticket. |

Supported sports (canonical `value` strings — keep them identical everywhere):

`fútbol`, `baloncesto`, `voleibol`, `tenis`, `natación`, `running`, `ciclismo`, `gimnasio`, `pádel`, `béisbol`

---

## 2. High-level architecture

```
┌─────────────────────────────────────────────────────────┐
│  Screens / Widgets                                      │
│  dispatch events, listen to states, never call Firebase │
└──────────────────────────┬──────────────────────────────┘
                           │ events / states
┌──────────────────────────▼──────────────────────────────┐
│  BLoCs                                                   │
│  orchestrate use cases, map service results to UI state │
└──────────────────────────┬──────────────────────────────┘
                           │ injected services
┌──────────────────────────▼──────────────────────────────┐
│  Services                                                │
│  Firebase Auth / Firestore / Storage / payment adapters │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│  Firebase (proplay-eac23)                                │
│  Auth · Firestore · Storage · Hosting                    │
└─────────────────────────────────────────────────────────┘
```

Rules of the road:

1. **Never put business logic in widgets.** Dispatch a BLoC event.
2. **Services do I/O only.** They do not emit UI states.
3. **BLoCs receive services via constructor injection.**
4. **UI talks to BLoCs and to `context.currentUser`**, not to Firebase (except two admin/history screens — see §10).

Known exception: `CreditApprovalScreen` and `CreditHistoryScreen` query Firestore directly. New work should not copy this pattern; put it in a service + BLoC.

---

## 3. Application bootstrap

`lib/main.dart` is the composition root.

### Startup

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
3. `initializeDateFormatting('es')`
4. `runApp(MyApp())`

### Global providers

**Repositories (services)**

| Provider | Implementation |
| --- | --- |
| `AuthService` | Firebase Auth |
| `UserService` | `users` collection |
| `GroupService` | `groups` + members (depends on `UserService`) |
| `CreditHistoryService` | `creditHistory` + user balance writes |
| `PaymentService` | `StubPaymentService` (always succeeds) |
| `YapeService` | reads first doc in `yape` |

**App-wide BLoCs**

| BLoC | Responsibility |
| --- | --- |
| `AuthBloc` | login / register / Google / logout / password reset / refresh user |
| `UserBloc` | profile, match info, profile image URL |
| `GroupBloc` | create / join / list / delete groups |
| `CreditBloc` | instant stub purchase + pending Yape purchase |

Feature BLoCs (`SessionBloc`, `SessionDetailBloc`, `CreateSessionBloc`, `GroupDetailBloc`, `GroupEditBloc`, `MyTicketsBloc`, `ValidateTicketBloc`) are created closer to the screen that needs them.

`GroupBloc` currently constructs a **new** `GroupService` instead of reading the provided one. Prefer `context.read<GroupService>()` if you touch that provider.

### Auth-gated router

`GoRouter` is created once, after the first non-`AuthInitial` state. `GoRouterRefreshStream` listens to `AuthBloc` so redirects re-run on login/logout.

Redirect rules:

- Unauthenticated users may only visit `/welcome`, `/login` and `/registration`; anything else redirects to `/welcome`.
- Authenticated users hitting those three routes go to `/`.
- Custom scheme `proplay://success|pending|failure` remaps to `/payment/...` (Mercado Pago return path; not the live Yape flow).

While `AuthBloc` is still `AuthInitial`, a spinner `MaterialApp` is shown (no router yet).

---

## 4. Routing

### GoRouter table

| Path | Name | Screen |
| --- | --- | --- |
| `/` | `home` | `HomeScreen` |
| `/sessions` | `sessions` | `EventsFeedScreen` (same feed as `/events`) |
| `/events` | `events` | `EventsFeedScreen` — public feed, **open to guests** |
| `/events/:id` | `event-detail` | `PublicEventScreen` — read-only `publicEvents` detail, **open to guests** |
| `/create-group` | `create-group` | `CreateGroupScreen` |
| `/edit-profile` | `edit-profile` | `EditProfileScreen` |
| `/purchase-credits` | `purchase-credits` | `PurchaseCreditsScreen` |
| `/payment/success` | `payment-success` | `PaymentSuccessScreen` |
| `/payment/pending` | `payment-pending` | `PaymentPendingScreen` |
| `/payment/failure` | `payment-failure` | `PaymentFailureScreen` |
| `/tickets` | `tickets` | `MyTicketsScreen` |
| `/validate-ticket` | `validate-ticket` | `ValidateTicketScreen` (`?token=`) |
| `/group/:id` | `group-detail` | `GroupDetailScreenLoader` |
| `/group/:id/edit` | `group-edit` | `GroupEditScreenLoader` |
| `/group/:id/info` | `group-info` | `GroupInfoScreenLoader` |
| `/welcome` | `welcome` | `LandingScreen` (public landing, placeholder content) |
| `/login` | `login` | `LoginScreen` |
| `/registration` | `registration` | `RegistrationScreen` |

Loaders exist so a deep link with only an id can stream the document, then hand a fully built model to the real screen.

### Still using `Navigator.push`

These screens are **not** in the route table. Deep links will not open them.

- `CreateSessionScreen`
- `SessionDetailScreen`
- `SessionMapScreen`
- `TicketDetailScreen`
- `CreditHistoryScreen`
- `CreditApprovalScreen`

When you add a new primary destination, register it in `GoRouter` and navigate with `context.go` / `context.push`. Keep `Navigator.push` only for true one-off sheets if you must.

Ticket validation URL builder: `lib/utils/ticket_url_builder.dart` → `https://proplayapp.com/validate-ticket?token=<uuid>`.

---

## 5. Directory map

```
lib/
├── main.dart
├── firebase_options.dart          # generated — do not edit
├── mp.dart                        # static Mercado Pago preference samples
├── bloc/<feature>/                # *_bloc.dart, *_event.dart, *_state.dart
├── models/
├── services/
├── screens/
├── widgets/
└── utils/
```

Naming:

| Kind | File |
| --- | --- |
| Screen | `{name}_screen.dart` |
| Route loader | `{name}_screen_loader.dart` |
| Widget | `{name}.dart` |
| Model | `{name}_model.dart` |
| Service | `{name}_service.dart` |
| BLoC | `{name}_bloc.dart` / `_event.dart` / `_state.dart` |

Import order: Flutter → packages → `package:proplay/...`.

Most BLoCs keep event/state in sibling files. `SessionBloc`, `CreateSessionBloc`, and `GroupEditBloc` use `part` / `part of` instead. Either style is fine; do not mix both inside one feature.

---

## 6. State management conventions

```dart
// Correct
context.read<AuthBloc>().add(AuthLoginRequested(email: e, password: p));

// Wrong
await AuthService().signInWithEmailAndPassword(email, password);
```

- `BlocBuilder` — rebuild UI from state.
- `BlocListener` — one-shot side effects (snackbars, navigation).
- `BlocConsumer` — both.
- States and events extend `Equatable`. Prefer `const` constructors.

### Current user

```dart
final user = context.currentUser;   // read once
final user = context.watchUser;     // rebuilds on AuthBloc change
bool ok = context.isAuthenticated;
```

Defined in `lib/utils/auth_helper.dart`. After a write that changes the user document (credits, profile), dispatch `AuthRefreshUserRequested` so `AuthAuthenticated.userModel` stays fresh.

### Responsive shell

`responsive_framework` breakpoints in `main.dart` (Tailwind-ish): mobile `<640`, SM, tablet, desktop `>=1024`, XL, 2XL, 4K.

- Mobile: `AppDrawer` (end drawer).
- Desktop: `AppSidebar`.
- Helpers: `ResponsiveLayout`, `ResponsiveConstrainedBox` in `lib/widgets/responsive_layout.dart`.

Theme: primary `#BA1B1D`, light surfaces. Set in `MaterialApp.router`.

---

## 7. Firestore data model

Firebase project: **`proplay-eac23`**. There are **no rules/index files in this repo**; production indexes and rules live in the Firebase console until they are checked in.

```
users/{uid}
  └─ groups/{groupId}            # { role, joinedAt }

groups/{groupId}
  └─ members/{userId}            # { role, joinedAt }

sessionTemplates/{templateId}
liveSessions/{sessionId}         # players[] embedded on the document
tickets/{sessionId}_{userId}
creditHistory/{id}
yape/{id}                        # first doc wins — admin QR / phone / name
```

### `users/{uid}` — `UserModel`

| Field | Type | Notes |
| --- | --- | --- |
| `uid` | string | Same as Auth uid and document id |
| `email` | string | |
| `firstName`, `lastName` | string | |
| `profileImageUrl` | string? | Storage download URL |
| `gender` | string? | Used by matchmaking |
| `age` | int? | Used by matchmaking |
| `profileCompletionDismissed` | bool | Home can skip the match-info prompt |
| `createdAt` | timestamp | |
| `credits` | **string** | Always 2 decimals, e.g. `"15.00"` |
| `superUser` | bool | Admin |
| `sports` | string[] | Canonical sport values |

`isMatchInfoComplete` is `gender != null && age != null`.

Membership is **not** an array on the user document. It is `users/{uid}/groups/{groupId}`.

`GroupService.streamUserGroups` queries `groups.where('members' arrayContains userId)`. Create/join writes the **members subcollection**, not a `members` array on the group. Treat `streamUserGroups` as stale; list groups via `getUserGroups`.

### `groups/{groupId}` — `GroupModel`

| Field | Type |
| --- | --- |
| `id`, `name`, `code`, `sport` | string (`code` is 6-char A–Z / 0–9) |
| `createdBy` | uid of owner |
| `createdAt` | timestamp |
| `members` | string[]? — **often unused** |
| `profileImageUrl` | string? |

Roles in `groups/{id}/members/{uid}.role`: `owner` | `admin` | `label: administrador / miembro / propietario`.

Join/create also writes the reciprocal `users/{uid}/groups/{groupId}` doc. Role changes must update **both** sides (`GroupService.updateMemberRole` already does).

### `sessionTemplates/{id}` — `SessionTemplateModel`

Written by `SessionService.createSessionTemplate`, which also inserts the first `liveSessions` doc. Fields: `groupId`, `creatorId`, `title`, `eventDate`, `eventEndDate`, `durationInMinutes` (computed), `maxPlayers`, `totalCost`, `costPerPlayer` (`totalCost / maxPlayers`), `isPrivate`, `sport`, `minAge`, `maxAge`, `desiredGender`, location + GeoFirestore `g` / `l`.

Recurring `rrule` from `docs/sessions.md` is **not** implemented.

### `liveSessions/{id}` — `SessionModel`

Same scheduling / matchmaking / location fields, plus:

| Field | Type | Notes |
| --- | --- | --- |
| `templateId` | string | Parent template |
| `status` | string | First session is `'OPEN'` |
| `playerCount` | int | Denormalized length of `players` |
| `players` | `SessionUserModel[]` | Embedded, not a subcollection |
| `g` | string | Geohash |
| `l` | `[lat, lng]` | GeoFirestore pair |
| `district` | string? | From the map picker (`locality` → `sublocality` → `administrative_area_level_3`); absent on old events |
| `format` | string? | Optional free text (e.g. "7 vs 7"); absent on old events |

`SessionUserModel`: `uid`, `firstName`, `lastName`, `profileImageUrl`, `joinedAt`, `receiptUrl?`, `isConfirmed`.

List queries deliberately drop `players` to keep payloads small. Detail views stream the full document.

`docs/sessions.md` proposed `players` / `waitingList` subcollections. The shipped model embeds players and throws `'Session is full'` instead of a waitlist.

### `tickets/{sessionId}_{userId}` — `TicketModel`

Created **inside** the join transaction. Status: `valid` | `used`. A cancelled ticket is **deleted** by `cancelParticipation`. Includes a denormalized snapshot of event + user so the ticket screen works if the live session later changes.

Extra fields: `pricePaid` (number, written by the client at join; optional on legacy tickets), which the rule caps at the session's `costPerPlayer` and which the server caps again at refund time. Only the holder of a still-`valid` ticket can re-issue it (rule); a used ticket cannot be revived. Rejoining after a cancel is a plain create. Keeping `cancelled` tickets for history is a planned follow-up (own plan).

Lookups: by `userId` (client-sorted by `eventDate`), or by `validationToken`.

### `publicEvents/{sessionId}` — projection

Written **only** by the `mirrorPublicEvent` Cloud Function (rules: `read: true`, `write: false`). One document per `liveSessions` doc with `isPrivate == false`; deleted when the event becomes private or is deleted. Copies scheduling, price, seats (`playerCount`/`maxPlayers`), sport, age/gender, location (incl. `g`/`l`), `district`, `format`, plus `groupName` (organizer). It **never** contains `players`. The public feed and `/events/:id` read this collection only. Existing events are copied once by `functions/scripts/backfillPublicEvents.ts`.

### `creditHistory/{id}` — `CreditHistoryModel`

Ledger. Amounts are doubles. User **balance** remains a 2-decimal string.

| `status` | When |
| --- | --- |
| `pending` | Yape request waiting for super user |
| `completed` | Balance already applied |
| `approved` / `rejected` | Admin decision on a purchase |
| `failed` / `refunded` | Reserved |

| `entryType` | `direction` | Typical source |
| --- | --- | --- |
| `purchase` | `credit` | `payment` |
| `spend` | `debit` | `session` (join) |
| `refund` | `credit` | session cancel (`cancelParticipation`; doc id `refund_{sessionId}_{uid}_{ticketToken}`) |
| `adjustment` | either | `admin` |

Player cancel goes through `cancelParticipation` and refunds. The admin remove-player path (`removeUserFromSession`) still does **not** refund credits or void the ticket.

### `yape`

First document: `{ name, phone, qr }`. Shown on the purchase screen.

---

## 8. Core flows

### Authentication

```
LoginScreen / RegistrationScreen
  → AuthLoginRequested | AuthRegisterRequested | AuthGoogleSignInRequested
  → AuthService (Firebase Auth)
  → UserService.createUser / getUser
  → optional GroupService.joinGroup(code)
  → AuthAuthenticated
  → GoRouter redirect to /
```

- Google (web): `signInWithPopup`. Native: `signInWithProvider`.
- New Google users split `displayName` into first/last and copy `photoURL`.
- Invalid invite code still creates the account and emits `AuthSuccessWithInfo`.
- Password reset: `AuthPasswordResetRequested` → email → `AuthPasswordResetEmailSent` → back to unauthenticated.
- `AuthBloc` listens to `authStateChanges`. If Auth exists but the Firestore user is not written yet (Google race), it **does not** flip to unauthenticated.

### Groups

```
CreateGroupScreen → GroupCreateRequested → GroupService.createGroup
  writes groups/{id}, members/{creator}=owner, users/{uid}/groups/{id}=owner

Join (home / registration) → GroupJoinRequested → join by code
  role = member; rejects if already a member

Group detail loader streams groups/{id}
GroupDetailBloc loads members by fetching each user doc
  owner/admin can toggle admin ↔ member or remove
```

`SessionDetailBloc` treats "owner/admin" as `group.createdBy == currentUser.uid` only. Ticket validation is stricter and also accepts `role == admin` and `superUser`. Align these if you change permissions.

### Sessions

Create (pushed from the group sessions screen), 3 steps: location → date/time → details (`docs/multi_step_session_creation.md`).

```
CreateSessionBloc → SessionService.createSessionTemplate
  → sessionTemplates add
  → liveSessions add (status OPEN, playerCount 0)
```

Home / Sessions:

```
LoadAllUserSessions → getAllUpcomingSessions
  group sessions ∪ public sessions
  filter: sport ∈ user.sports, gender, age, optional radius
  sort: distance if GPS available, else eventDate
```

Home asks for location (`geolocator`) and prompts for sports / gender / age when missing.

Join:

```
SessionDetailBloc.JoinSession
  → SessionService.joinSession (Firestore transaction)
      1. reject if already joined or full or credits < costPerPlayer
      2. debit users/{uid}.credits
      3. write creditHistory spend
      4. append SessionUserModel to players[], bump playerCount
      5. write tickets/{sessionId}_{uid}
```

Admin remove only updates `players` / `playerCount`. It does not refund or void the ticket.

Cancel (player):

```
SessionDetailBloc.CancelParticipation
  → SessionService.cancelParticipation → callable `cancelParticipation` (southamerica-east1)
      one transaction, all reads before writes; uid comes from request.auth only:
      1. reject unless the uid is in players[], the ticket (if any) is `valid`, and the event has not started
         (`eventDate` missing/invalid or in the past → `failed-precondition`)
      2. refundable = eventDate - now >= 24 h (server time)
      3. refund source = latest `spend` creditHistory row for (uid, session) without `refundedAt`;
         amount = min(spend.creditAmount, session.costPerPlayer). `ticket.pricePaid` is informational only
      4. players[] filtered, playerCount updated; ticket deleted
      5. if refundable and amount > 0: users/{uid}.credits += amount, spend row gets `refundedAt`,
         creditHistory `refund` row with id `refund_{spendId}` (one refund per spend row)
  → SessionDetailCancelled → AuthRefreshUserRequested + snackbar
```

Public feed:

```
EventsFeedBloc.EventsFeedStarted → SessionService.getPublicEvents (publicEvents, next 30 days)
  → applyFeedFilters (sport, district, day part [Lima time], max price, format;
    gender/age only for signed-in users) → sortFeed (distance if GPS, else date)
```

Guests tap a card → `/events/:id` (`PublicEventScreen`, "Regístrate para unirte"). Signed-in users open `SessionDetailScreen` via `Navigator.push`. Home leads with the same `EventsFeedView`; "Mis grupos" sits below it.

### Cloud Functions (`functions/`)

TypeScript, Node 20, v2 API, all in `southamerica-east1` (the Firestore database location; a Firestore trigger must be in the DB region). `cancelParticipation` (callable) and `mirrorPublicEvent` (`onDocumentWritten('liveSessions/{id}')`). Unit tests: `cd functions && npm test` (`node --test` via `tsx`). Emulator tests: `cd functions && npm run test:emulator` (needs Java; runs `functions/emulator-tests/`: `cancel` (callable logic), `rules` (`firestore.rules` incl. the known open holes), `backfill` (script) and `trigger` (`mirrorPublicEvent` through the Functions emulator), in three emulator runs because the backfill test needs a clean database).

### Matchmaking

Implemented in `SessionService` (`getAllUpcomingSessions`, geohash helpers).

| Filter | Rule |
| --- | --- |
| Sport | Session `sport` must be in `user.sports` |
| Gender | Session `desiredGender == 'any'` **or** equals `user.gender` |
| Age | `minAge <= user.age <= maxAge` |
| Privacy | Public (`isPrivate == false`) plus the user's group sessions |
| Distance | Optional `maxDistanceKm`; geohash range query on `g`, then Haversine |

`g` / `l` are written only when lat/lng are present. Sessions without location drop out of radius queries.

More product context: [MATCHMAKING.md](MATCHMAKING.md), [MATCHMAKING_2.md](MATCHMAKING_2.md). Geo encoding: `lib/utils/geohash_utils.dart` (precision 6), background in [geofirestore.md](geofirestore.md).

### Credits

Live path is **manual Yape + super-user approval**. See [PAYMENT_SYSTEM.md](PAYMENT_SYSTEM.md).

Packages (`CreditPackage.packages`): 15 / S/17, 28 / S/32, 50 / S/57.

```
PurchaseCreditsScreen
  → YapeService.getYapeConfig()
  → user pays in the Yape app
  → CreditYapePurchaseRequested
  → creditHistory status=pending (balance unchanged)

CreditApprovalScreen (superUser, queries Firestore directly)
  → approve: increment users.credits, status=approved
  → reject: status=rejected, no credit
```

`CreditPurchaseRequested` + `StubPaymentService` is the unfinished automated path. `PaymentService` is the interface for a future gateway. [PAYMENT_GATEWAY_MIGRATION_PLAN.md](PAYMENT_GATEWAY_MIGRATION_PLAN.md) and `lib/mp.dart` are not the production checkout.

### Tickets

1. Built by `TicketService.buildTicketForJoin` (pure) during join.
2. `MyTicketsBloc` streams the user's tickets.
3. `TicketDetailScreen` shows QR for `TicketUrlBuilder.buildValidationUrl`.
4. `/validate-ticket?token=` → `ValidateTicketBloc`.
5. Validator must be group owner, group `admin`, or `superUser`.
6. `validateTicket` transaction: `valid` → `used` + `usedAt` + `validatedBy`.

---

## 9. Services cheat sheet

| Service | Owns |
| --- | --- |
| `AuthService` | Email/password, Google, reset, `authStateChanges` |
| `UserService` | User CRUD, profile image URL, user↔group links |
| `GroupService` | Group CRUD, codes, members, roles |
| `SessionService` | Templates, live sessions, matchmaking, join, `cancelParticipation` (callable), public events feed |
| `TicketService` | Ticket ids, streams, token lookup, validate |
| `CreditHistoryService` | Instant purchase transaction + pending Yape row |
| `YapeService` | Admin Yape config |
| `PaymentService` / `StubPaymentService` | Gateway interface / always-OK stub |
| `StorageService` | `profile_images/`, `group_images/` |
| `ReceiptUploadService` | Pick image + `session_receipts/{sessionId}/` |

Join uses a transaction so seat + debit + ticket stay atomic. Approval of credits in `CreditApprovalScreen` is **not** currently a single transaction — be careful if you extract it.

---

## 10. UI map

| Screen | Role |
| --- | --- |
| `LoginScreen` / `RegistrationScreen` | Auth + optional group code |
| `HomeScreen` | Public events feed (`EventsFeedView`), groups, wallet, profile-setup dialog, GPS |
| `EventsFeedScreen` / `PublicEventScreen` | `/events` feed and `/events/:id` (guests allowed; `publicEvents` only) |
| `CreateGroupScreen` | Name + one sport |
| `GroupDetailScreen` (+ loader) | Members, create session, info/edit |
| `GroupEditScreen` / `GroupInfoScreen` | Edit image/name/sport; public info |
| `CreateSessionScreen` | 3-step wizard |
| `SessionDetailScreen` | Join / cancel (refund dialog), players, ticket, map |
| `EventsFeedScreen` / `EventsFeedView` | Public feed with filters (also embedded at the top of Home) |
| `PublicEventScreen` | Read-only public event for guests |
| `SessionMapScreen` | Google Map pin |
| `EditProfileScreen` | Name + photo |
| `PurchaseCreditsScreen` | Yape wizard |
| `PaymentSuccess/Pending/Failure` | Gateway return placeholders |
| `MyTicketsScreen` / `TicketDetailScreen` | Wallet of tickets + QR |
| `ValidateTicketScreen` | Staff check-in |
| `CreditHistoryScreen` | User ledger (direct Firestore) |
| `CreditApprovalScreen` | Super-user queue (direct Firestore) |

Shared widgets: `AppDrawer`, `AppSidebar`, `WalletIndicator`, `UpcomingEvents`, `CachedImage` (`PlatformCachedImage`), `LocationPicker`, `StepIndicator`.

---

## 11. Platforms, Firebase, maps

| Platform | Config |
| --- | --- |
| Android | `android/app/google-services.json`, Maps key + location perms + `proplay://` in `AndroidManifest.xml` |
| iOS | `ios/Runner/GoogleService-Info.plist`, bundle `com.proplayapp.proplay`, Google client URL scheme, `proplay` URL scheme, photo/camera/location usage strings |
| Web | `lib/firebase_options.dart` `web` options, Maps JS in `web/index.html`, Hosting in `firebase.json` |

Do not hand-edit `lib/firebase_options.dart` or the native Google service files. Re-run FlutterFire if apps change.

Storage layout:

```
profile_images/profile_{uid}.jpg
group_images/group_{groupId}.jpg
session_receipts/{sessionId}/receipt_{uid}_{ts}.jpg
```

`cors.json` exists at repo root for Storage CORS on web.

Hosting: `public: build/web`, SPA rewrite `** → /index.html`. Public ticket links assume [https://proplayapp.com](https://proplayapp.com).

---

## 12. How to add things

### New screen

1. `lib/screens/{name}_screen.dart`.
2. If it has non-trivial state, add `lib/bloc/{name}/`.
3. Register a `GoRoute` in `main.dart` unless it is a throwaway overlay.
4. Navigate with `context.pushNamed` / `context.go`.
5. Update the routing table in **this file**.

### New BLoC

1. Folder `lib/bloc/{name}/` with event, state (`Equatable`), bloc.
2. Inject services in the constructor.
3. Provide it where the subtree needs it (`BlocProvider` on the screen or a loader).
4. UI: events in, states out.

### New Firestore collection

1. Model with `toMap` / `fromMap` (and `fromDocument` if useful).
2. Service for all reads/writes.
3. BLoC between UI and service.
4. Document the collection in §7.
5. Remember console indexes/rules — they are not in git yet.

### New auth capability

1. `AuthService` method.
2. Event on `AuthBloc`.
3. State if the UI needs a new branch.
4. Dispatch from the screen via `BlocListener` for errors.

---

## 13. Testing and quality

```bash
flutter analyze
flutter test
```

`test/widget_test.dart` is still the Flutter counter template and does **not** boot Firebase-safe UI. Replace it before relying on CI.

Intended direction (from project guidelines):

- Unit-test BLoCs with mocked services (event → state).
- Widget-test screens with a fake `AuthBloc` / router.
- Transaction-sensitive paths (`joinSession`, `validateTicket`, credit approval) deserve focused service tests.

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`. `flutter_lints` is commented out in `pubspec.yaml` — if analyze complains it is missing, add it back as a dev dependency.

---

## 14. Known pitfalls (read before you change money or seats)

1. **Credits are a string on the user**, a double on the ledger. Always go through `UserModel.formatCredits` / `creditsValue`.
2. **Join is transactional on the client; cancel is server-side.** There is no client `leaveSession` anymore. Admin remove still does not refund or void the ticket.
3. **Players live on the live session document.** Large games will hit document size / contention. A players subcollection (as in `docs/sessions.md`) is the eventual fix.
4. **Two membership models.** Subcollections are source of truth. Do not revive `streamUserGroups` without writing `groups.members[]`.
5. **Duplicate sport lists** in `HomeScreen`, `CreateGroupScreen`, `GroupEditScreen`. Extract a constant before adding a sport.
6. **Owner checks disagree** across session detail vs ticket validation.
7. **Rules and functions are in git but deployed by hand** (`firestore.rules`, `functions/`). Deploy order: rules → functions → backfill → hosting (see README). The `mirrorPublicEvent` trigger region must equal the Firestore location (`southamerica-east1`). The rules still let a client edit its own `users.credits` and any `liveSessions` doc, and overwrite its own ticket even when `used`; moving join + credit approval server-side and tightening those rules is the durable fix.
8. **`PaymentService` is a stub.** Do not hook a real card form to `CardDetails` (PCI). Use a gateway SDK / redirect.
9. **Mixed navigation.** Deep links only work for GoRouter paths.
10. **API keys in client files** (`AppConstants`, manifests, `web/index.html`) are expected for Maps but should be restricted by bundle id / HTTP referrer in Google Cloud.
11. **`creditHistory` streams require a composite index** (`userId` + `createdAt`). Create it from the console error link if queries fail.
12. **Geohash queries** fan out by range × gender × sport. Keep radius and sport count bounded.
13. **Registration success copy is Portuguese** (`Usuário registrado...`) in `AuthBloc`. Product UI is otherwise Spanish.

---

## 15. Current status

### Shipped

- Email/password + Google auth, password reset, profile image
- Groups: create, join by code, roles, edit, delete
- Session templates + first live session, 3-step create with map picker
- Matchmaking by sport, gender, age, distance
- Yape credit purchase + super-user approval
- Credit spend on join + ledger
- Tickets + QR validation URL
- Public events feed (guests) + cancel with full refund 24 h or more before kickoff (Cloud Function)
- Responsive mobile / desktop chrome
- Web hosting SPA

### Incomplete or leftover

- Automated payment gateway (interface + stub + MP sample prefs + payment result routes)
- Recurring sessions / waitlist (`docs/sessions.md`)
- Refunds when an organizer deletes a session or an admin removes a player
- Email verification
- Locking down `users.credits` / `liveSessions` update rules
- Real test suite
- Aligning all navigation on GoRouter
- Extracting admin screens off raw Firestore

---

## 16. Related docs

| File | Use |
| --- | --- |
| [../README.md](../README.md) | Setup and first-week onboarding |
| [PAYMENT_SYSTEM.md](PAYMENT_SYSTEM.md) | Live Yape flow |
| [PAYMENT_GATEWAY_MIGRATION_PLAN.md](PAYMENT_GATEWAY_MIGRATION_PLAN.md) | Future gateway |
| [MATCHMAKING.md](MATCHMAKING.md) / [MATCHMAKING_2.md](MATCHMAKING_2.md) | Matching product notes |
| [multi_step_session_creation.md](multi_step_session_creation.md) | Create-session wizard |
| [sessions.md](sessions.md) | Early sessions design (partially superseded) |
| [geofirestore.md](geofirestore.md) | Geohash query background |
| [map_picker.md](map_picker.md) | `map_location_picker` vendor notes |
| [reporte.md](reporte.md) / [reporte_pasarela.md](reporte_pasarela.md) | Spanish stakeholder reports |

---

When you change a flow or collection, update the matching section above and bump the "Last reviewed" date at the top.
