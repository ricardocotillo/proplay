# Note: move `joinSession` (and credit approval) to the server

Status: **future work**, planned for a later build after the events-marketplace PR. Not started.
Written 2026-11-13, against branch `claude/transform-events-app-84e7e8`.

## Why

Today the client does the whole join: it checks the balance, debits credits, writes the ledger row, appends itself to `players[]` and creates its own ticket (`SessionService.joinSession`, `lib/services/session_service.dart`). Because those are client writes, the Firestore rules have to allow them, and that leaves holes that the rest of the app (refunds, public feed, ticket validation) has to trust:

| Hole | Where | Effect |
| --- | --- | --- |
| A user can edit its own `users.credits` | `firestore.rules`, `users` update: `isOwner(userId) \|\| isSuperUser()`, only `documentUnchanged()` | Free credits, so free joins |
| Any signed-in user can write `players` / `playerCount` of any event | `liveSessions` update, non-owner branch | Join without paying, kick other players, inflate the seat count the public feed shows |
| A user can create arbitrary `creditHistory` rows for itself | `creditHistory` create | Forged `spend` rows (the refund is capped at the event price, but the ledger can no longer be trusted) |
| The client creates its own ticket (`pricePaid`, document snapshot, token) | `tickets` create/update | Ticket not tied to a real payment |
| `joinSession` trusts the `UserModel` the client passes in | `session_service.dart:609` | The balance check uses a possibly stale `user.credits`, not the document read inside the transaction |
| Yape approval is not one transaction | `CreditApprovalScreen._approveCredit` (direct Firestore) | Balance and ledger status can diverge; any `superUser` write is client-side |

`cancelParticipation` (Cloud Function, already shipped) is the model: server-side, one transaction, idempotent, uid taken from the auth context.

## Current flow (what to replace)

`SessionDetailBloc` `JoinSession` → `SessionService.joinSession(sessionId, currentUser)` → Firestore transaction:

1. Read `liveSessions/{id}`; fail if missing.
2. `user.creditsValue < session.costPerPlayer` → fail (uses the passed-in model).
3. Already in `players[]` → fail. Seat check `players.length < maxPlayers`, else `Session is full`.
4. `users/{uid}.credits` = balance − cost (2-decimal string).
5. `creditHistory` row: `entryType: spend`, `direction: debit`, `sourceType: session`, `sourceId: sessionId`, balances, notes.
6. Append `SessionUserModel` to `players[]`, `playerCount` = length.
7. Create `tickets/{sessionId}_{uid}` (`TicketService.buildTicketForJoin`: new `validationToken`, `pricePaid`, event and user snapshot including `userDocumentType` / `userDocumentNumber`).

Then the screen dispatches `AuthRefreshUserRequested` and opens the ticket.

Matchmaking (gender, age, sport) is only a **feed filter** today; nothing stops a user from joining an event they do not match.

## Proposed design

### Callable `joinSession` (region `southamerica-east1`, same package as `cancelParticipation`)

Input: `{ sessionId }` only. The caller is `request.auth.uid`; every other value comes from Firestore.

One transaction, all reads before writes:

1. Read `liveSessions/{id}`, `users/{uid}`, the ticket, and the caller's existing player entry.
2. Validate: session exists, `isPrivate == false` **or** caller is a member of the group, event not started, not already a player, seats left, balance from the **user document** read in the transaction, and (new, decide with the product owner) gender / age rules.
3. Debit `users/{uid}.credits` (`toFixed(2)`, same as `formatCredits`).
4. Write the ledger `spend` row with a **deterministic id** (for example `spend_{sessionId}_{uid}_{validationToken}`) so a retry cannot double-charge, and so `cancelParticipation` can refund exactly that row.
5. Append the player entry built from `users/{uid}` (name, photo), never from the payload; update `playerCount`.
6. Write the ticket (`pricePaid` = `costPerPlayer`, document snapshot copied from the user document).
7. Return `{ ticketId }` (and the new balance if useful).

Idempotent on retry: if the caller is already a player and the ticket and spend row exist, return the existing result instead of failing.

### Callable `approveCreditPurchase` (superUser only)

Replaces `CreditApprovalScreen._approveCredit`: verify `superUser` on the caller's user document, then in one transaction mark the ledger row `approved` (only from `pending`), increment `users/{uid}.credits`, and write an audit field (`approvedBy`, `approvedAt`). A reject callable is the same without the credit. This also fixes the "not a single transaction" pitfall.

### Rules to tighten once clients stop writing

Do this **last**, after the new client is released (see rollout):

- `users`: owner update may not change `credits` or `superUser` (`request.resource.data.diff(resource.data).affectedKeys().hasOnly([...profile fields...])`); `create` already requires `credits == '0.00'`.
- `liveSessions`: update allowed only to the group owner (any field except `groupId`). Drop the non-owner `players` / `playerCount` branch. Admin removal of a player (`removeUserFromSession`) and `uploadReceipt` also move behind callables, or stay on a narrower rule if kept client-side.
- `tickets`: no client `create`/`update` for holders; only the group staff validation update (`valid` → `used`). Reading stays as is. This drops the `isValidTicketData` machinery and the "holder can re-issue" case.
- `creditHistory`: no client `create` except the Yape purchase request (`status: pending`, `entryType: purchase`), and that one validated by shape; no client updates.
- Update `functions/emulator-tests/rules.test.mjs`: the `[known hole]` tests must flip to expect failures. That file is the checklist.

## Rollout (the part that is easy to get wrong)

Old app versions keep writing directly, so tightening rules breaks them.

1. Ship the callables and deploy them. Rules unchanged. Nothing breaks.
2. Ship the new client (`SessionService.joinSession` calls the callable; credit approval screen calls `approve…`). Keep the old direct paths working until the old versions are gone.
3. Decide a minimum supported app version (web redeploys instantly; mobile stores lag) and wait or force an update.
4. Then deploy the tightened rules. Rules first is the deploy order for additive changes; **tightening is the opposite**: functions and app first, rules last.
5. Remove the dead client code (`joinSession` transaction body, the direct Firestore code in `CreditApprovalScreen`).

## Client changes

- `SessionService.joinSession`: call `FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('joinSession')`, map `FirebaseFunctionsException` to the Spanish messages the screen already shows (not enough credits, full, already joined). The `cancelParticipation` method in the same file is the template.
- `SessionDetailBloc` keeps the same `JoinSession` event and `SessionDetailProcessing(action: 'joining')` state; only the service call changes.
- `TicketService.buildTicketForJoin` and the ticket-rule workarounds go away; keep the model.
- `CreditApprovalScreen` / `CreditHistoryScreen` should move behind a BLoC at the same time (they are the two known BLoC-rule exceptions).

## Tests to write

Reuse `functions/emulator-tests/` (see `cancel.test.mjs` for the harness):

- Happy path: balance debited once, one ledger row, one player entry, one ticket, `playerCount` consistent.
- Insufficient balance, full event, already joined, private event as non-member, event started, unknown session, unauthenticated.
- Two concurrent joins on the last seat: exactly one succeeds.
- Same user retrying the same join: no double charge.
- Stale client data: balance comes from the server document.
- Join then `cancelParticipation`: refund equals the debited ledger row; join again works.
- Credit approval: only `superUser`; approve twice credits once; reject does not credit.
- Rules: every `[known hole]` case now fails.

## Open questions for the product owner

- Should the server enforce gender / age / sport matching, or stay a feed filter only?
- Waitlist when full (still out of scope today), or keep "full" as an error?
- Keep `uploadReceipt` and admin removal client-side with a narrow rule, or move them too?
- Minimum supported app version and how to force an update on mobile.
- Refund on admin removal or event deletion (out of scope of the events PR; this is the natural place to decide it).

## Pointers

- Current implementation: `lib/services/session_service.dart` (`joinSession`, `cancelParticipation`, `uploadReceipt`, `removeUserFromSession`), `lib/services/ticket_service.dart`, `lib/screens/credit_approval_screen.dart`.
- Server pattern to copy: `functions/src/cancelParticipation.ts`, `functions/src/refundPolicy.ts`.
- Rules and their tests: `firestore.rules`, `functions/emulator-tests/rules.test.mjs`.
- Deploy order and emulator commands: `README.md`; pitfalls: `docs/ARCHITECTURE.md` §14.
