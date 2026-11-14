# ProPlay as an events marketplace — design

Date: 2026-11-13. Status: draft for approval.

## Intent and why

ProPlay today is group-first: sessions hang off a group, and the app is organised around "my groups". The owner wants ProPlay to feel like **Fuchigol** (fuchigol.com, the direct competitor in Lima): open a public feed of events, filter, pay for a spot, cancel with a refund, show up. Fuchigol is football-only; ProPlay is **multi-sport**, so nothing may be football-specific.

Why: compete on the discovery-and-trust experience Fuchigol already offers. Trust comes mostly from a clear refund rule.

Groups stay. A group becomes the **organizer** (the "club" that publishes events). Public events become the main thing users see.

## Goals

1. **Public feed first.** Home leads with upcoming public events, filterable by district, time of day, price, and (optional) format, with seats taken visible. Groups move to a secondary place.
2. **Cancel with refund.** A player can cancel their own spot. Cancelling 24 h or more before kickoff refunds the full cost in pro coins. Later cancels free the seat but refund nothing.
3. **Server-side cancel.** The cancel/refund runs in a Cloud Function, not in client code.

## Non-goals

- Football-only features: goalkeeper rate, 5v5-style presets hard-coded in logic.
- Minimum-player confirmation and auto-refund (needs scheduled jobs). Later.
- No-show strikes and account suspension. Later (will reuse the Functions package).
- Fields, academies, tournaments, MVP voting, live scores, chat.
- Organizer-initiated cancel/delete refunds, and refund on admin removal (`removeUserFromSession`). Unchanged in v1.
- Moving join or Yape approval server-side. Unchanged in v1.
- Waitlist, recurring events.

## Anti-goals (would be a failure even if it "works")

- A refund that can happen twice, or without the ticket/seat being released.
- Hiding events from users because their `sports` profile does not match.
- Breaking existing events that lack the new fields (`district`, `format`).
- Football wording or assumptions leaking into the UI or data model.

## Constraints

- BLoC-only: widgets dispatch events; services do I/O (see `CLAUDE.md`).
- Credits on the user are a 2-decimal **string**; ledger amounts are doubles; always use `UserModel.formatCredits` / `creditsValue`.
- Sport values stay canonical; product copy is Spanish.
- No Cloud Functions, no rules and no indexes in git today. Project `proplay-eac23`. Functions need the Blaze plan.
- Do not hand-edit `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`.
- Update `docs/ARCHITECTURE.md` (routes, collections, flows) and keep `CLAUDE.md` / `AGENTS.md` in sync.

## What exists today (relevant)

- `SessionService.getAllUpcomingSessions` already merges the user's group sessions with public ones and filters by sport ∈ `user.sports`, gender, age, optional radius.
- `SessionService.joinSession` is a client transaction: check seats and credits → debit → ledger `spend` → append player → write ticket `tickets/{sessionId}_{uid}`.
- `SessionService.leaveSession` only removes the player from `players[]`. It does **not** refund, void the ticket, or check who is calling.
- Tickets have status `valid | used`.
- `SessionModel` has `eventDate`, `costPerPlayer`, `maxPlayers`, `playerCount`, `sport`, geohash `g` / `l`, `isPrivate`. It has no `district` or `format`.

## Approaches considered

**Refund path**

- A. Client transaction like `joinSession`. Fast, but the client can credit itself.
- B. One Cloud Function for cancel. Server validates the 24 h rule, refunds, voids the ticket, frees the seat. Needs a Functions package and the Blaze plan. **Chosen by the owner.** It also sets up the Functions package for later features.
- C. Client now, server later. Cheapest, leaves the gap open.

**Feed**

Evolve the existing matchmaking query (chosen, cheapest, reuses geohash and filters) versus a new separate search service. A separate service buys nothing at this size.

**Groups**

Keep groups as organizers (chosen, owner's call, cheaper) versus removing them.

## Design

### 1. Feed

- Add optional fields to template and live session: `district` (string), `format` (string, free label such as `5v5`, `doubles`; suggestions can vary by sport).
- Feed no longer requires `session.sport ∈ user.sports`. Sport becomes an optional user-chosen filter; default is all sports. Gender and age rules stay.
- New filters in the sessions UI: district, time of day (morning / afternoon / night), max price (`costPerPlayer`), format, optional radius (existing). Each seat count shows `playerCount / maxPlayers`.
- Home leads with this public feed; the group list becomes a secondary section.
- Filtering by price, time, district, format can be client-side over the fetched list in v1.
- Old events without `district` / `format` still appear and are simply not matched by those two filters.
- **Anonymous browsing.** New public route `/events` (in the router's allowed list next to `/welcome`, `/login`, `/registration`) shows the public feed without auth: `getAllPublicSessions` / `getPublicSessionsNearLocation` only, no group data, no matchmaking by gender/age. Event detail for signed-out users is read-only with a "Regístrate para unirte" button to `/registration`. Landing links to it.
- **Public projection.** A Cloud Function trigger (`onDocumentWritten` on `liveSessions/{id}`) mirrors every non-private event into `publicEvents/{id}` with only public fields: title, sport, district, format, eventDate, eventEndDate, costPerPlayer, maxPlayers, playerCount, groupId, group name, location, `g`, `l`, `desiredGender`, `minAge`, `maxAge`. No `players[]`. It deletes the mirror when the event becomes private or is deleted. Anonymous users read only `publicEvents`. A one-off backfill script copies existing public events. Signed-in users keep reading `liveSessions` as today.
- **Districts across Peru.** `district` is filled from reverse geocoding of the picked point, normalised (trimmed, case-folded, accents kept for display) at write time. The filter's options are built from the districts present in the fetched events, not from a fixed list. A `city`/`region` field is not added in v1.

### 2. Cancel and refund

Callable function `cancelParticipation({ sessionId })` in `functions/` (Node/TypeScript, Firebase Functions v2, region `southamerica-east1`). Caller uid comes from the auth context; it is never taken from the payload.

In one Firestore transaction (admin SDK):

1. Load `liveSessions/{sessionId}` and `tickets/{sessionId}_{uid}`. Fail if the user is not in `players[]` or the ticket is not `valid` (a `used` ticket cannot be cancelled).
2. Remove the player; recompute `playerCount`.
3. Set ticket `status = 'cancelled'`, `cancelledAt`, `refunded` boolean. A cancelled ticket cannot be validated: the existing rule only lets `valid` flip to `used`.
4. If `eventDate - now >= 24h` (server time): increase `users/{uid}.credits` by `costPerPlayer` (2-decimal string), write a `creditHistory` row (`entryType: refund`, `direction: credit`, `sourceType: session`, `sourceId: sessionId`, `balanceBefore/After`). Use a deterministic document id `refund_{sessionId}_{uid}_{validationToken}`. The token is new on every join, so a retry of one cancel cannot double-refund and a later cancel after rejoining gets its own refund.
5. If under 24 h: same steps 2–3 with no refund; response says so.

Returns `{ refunded: bool, amount }`. The client shows "Reembolso completo" or "Sin reembolso" **before** confirming (UI computes this for display only; the server decides) and dispatches `AuthRefreshUserRequested` afterwards.

- `SessionDetailScreen` leave button becomes "Cancelar mi cupo" and calls a new event on `SessionDetailBloc` → a new service method that calls the callable. The client `leaveSession` is no longer used by players.
- `TicketModel` gains status `cancelled`; `validateTicket` rejects it; My Tickets shows it as cancelled.
- Fixed policy: 24 h, full refund, no partial. A constant in the function.

### 3. Groups as organizers

- Group info page and event cards show the group name as organizer. No data-model change.
- Creating an event still starts from a group the user owns/administers.

## Production rules (received 2026-11-13) and what they mean

The owner pasted the live Firestore rules. Findings that shape this design:

- `users/{uid}`: the owner of a profile can update **any** field, including `credits`. Any signed-in user can read every profile.
- `liveSessions`: any signed-in user can update or delete **any** session, including `players[]`. Reads need sign-in.
- `tickets`: client create/update goes through `isValidTicketData`, which allows only a fixed key list and `status == 'valid'`. A holder can overwrite their own ticket, including a `used` one.
- `creditHistory`: a user can create rows for themself; only superUser can update.

So the real hole is wider than "credits": the client can write its own balance and any session. B protects the refund logic, not this. Closing it means moving join and credit approval server-side and locking those rules (follow-up, not v1; recommended as the first next step).

**Rule changes in v1 (minimal, additive):**

1. New collection `publicEvents/{sessionId}`: `allow read: if true; allow write: if false;`. Do not open `liveSessions` to anonymous reads, because it embeds `players[]` (names, photos) and rules cannot hide single fields.
2. `tickets.isValidTicketData`: add `pricePaid` (number, required for new tickets, `> 0` or `>= 0`) to `hasOnly` and to the checks. Without this the client join breaks.
3. Nothing else changes. Existing rules stay as pasted. Commit them as `firestore.rules`, with the two edits above, plus `firestore.indexes.json` for any new composite index.

The owner deploys rules by hand; the plan must order it: rules first (additive, safe for the old app), then the function, then the app.

## Decided by the owner

- Keep groups; they act as organizers.
- Resemble Fuchigol on discovery and refund.
- Drop goalkeeper rate (multi-sport).
- Refund via Cloud Function (option B).
- v1 scope: feed + cancel/refund.
- Signed-out visitors can browse the feed, **public events only** (`isPrivate == false`). Joining, tickets and groups still need an account; the join button sends them to `/registration`.
- Blaze plan is already active on `proplay-eac23`. The owner deploys the function manually.
- ProPlay covers all of Peru, not only Lima.

## My calls (not yet confirmed by the owner)

- 24 h threshold and "late cancel frees the seat, no refund" (Fuchigol's rule on late cancel was not stated).
- Region `southamerica-east1`.
- `format` is an optional free string; `district` is a string.
- Time-of-day buckets and client-side filtering in v1.
- Admin removal and organizer deletion stay without refund in v1.
- Refund amount: `joinSession` also stores `pricePaid` on the ticket; cancel refunds that amount. Old tickets without it fall back to the matching `spend` row in `creditHistory` (`sourceId == sessionId`), then to no refund.
- Player in `players[]` with no ticket: cancel still frees the seat, refunds only if a `spend` row is found.
- Rejoin after cancel is allowed. Join overwrites the ticket with a fresh `valid` one (new `validationToken`), which is what the existing ticket rule already allows. The refund doc id uses that token, so no counter is needed.
- Time zone `America/Lima` for time-of-day buckets (morning 05–12, afternoon 12–18, night 18–05). `eventDate` stays a UTC Timestamp.
- Feed query gets a default window of the next 30 days, so client-side filters never hide events past a page.

## Left to the builder

- Exact filter UI, copy, and layout of Home and of the public `/events` page.
- Functions project layout, emulator tests, and the deploy steps the owner will run by hand (function and rules ordering relative to the app release).
- Trigger and backfill details for `publicEvents`, and the composite indexes the feed queries need.
- Test coverage for the transaction paths (double refund, boundary at exactly 24 h, used ticket, user not in session).
