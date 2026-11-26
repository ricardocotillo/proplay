# ProPlay flow and functionality review, and improvement plan

Date: 2026-11-26. Status: draft for the owner to prioritise. Nothing is built yet.

## What we want ProPlay to be

From the events-marketplace spec (2026-11-13): a multi-sport (fútbol, baloncesto, voleibol) marketplace of pickup events across Peru. A user opens a public feed, filters it, pays for a spot, cancels with a clear refund, and shows up with a QR ticket. Groups act as organizers. The direct competitor is Fuchigol (Lima, football only). Trust mostly comes from a clear, automatic money policy.

The review below walks the real code paths a guest, a player and an organizer go through. Then it compares them with Fuchigol, Playtomic, GoodRec, OpenSports, Meetup and Spond.

## How competitors do it (short)

| Pattern | Fuchigol | Others | ProPlay today |
| --- | --- | --- | --- |
| Browse before signup, price and spots left visible | Yes | GoodRec, Playtomic | Yes (`/events`) |
| Signup friction | Phone + district | Playtomic: account + level | 8 fields + mandatory DNI/CE, then a forced sports dialog |
| Payment | Yape per match, organizer approves; refunds as Fuchicoins | Wallet/card at join | Wallet only; credits bought by manual Yape, super-user approval, no ETA |
| Free cancel cutoff | 24 h | Playtomic 24 h | 24 h, server-side (done) |
| Late cancel | Refund only if the spot is resold ("vender cupo") | GoodRec finds a replacement | No refund, no resale |
| Minimum players, auto-cancel and auto-refund | Capacity − 2, notified 1 h before | Playtomic auto-cancels unfilled | None |
| Waitlist | None | Meetup, OpenSports (2 h hold) | None ("Session is full") |
| No-shows | Suspensions + surcharge | Playtomic reports | Nothing (check-in data exists but unused) |
| Reminders and alerts | New matches nearby, cancellations | Spond reminders | None (bell icon is a TODO) |
| Share and private invite | Private match with 4-digit code, shared on WhatsApp | Playtomic share links | No share button; group code only |
| Organizer tools | Real-time roster, one-tap payment approval, add guests by name | OpenSports check-in screen | Create needs super-user; delete has no refund; no roster check-in |
| Ratings, level, MVP | Yes | Playtomic levels | None |

Openings Fuchigol leaves: football only, manual per-match payment approval, no waitlist, contradictory penalty rules. ProPlay's edge can be multi-sport, plus an automatic and transparent money policy (instant refund to pro coins, waitlist, auto-cancel).

Sources: fuchigol.com (/pichangas, /faq, /terminos, /para-organizadores), Playtomic and OpenSports help centers, Meetup and Spond help, BCRP interoperability reports, Mercado Pago Peru Yape docs. Fuchigol's signup OTP, notification channels and guest join gate were not verified.

## Blockers: where users get stuck or lose money (P0)

1. **Guest intent is lost at signup.** On `/events/:id` a guest taps "Regístrate para unirte" and goes to `/registration`. After signing up, `authRedirect` (`lib/utils/auth_redirect.dart`) always sends them to `/`, not back to the event. Then the forced sports dialog appears. The one conversion path the feed exists for drops the user on a generic Home.
2. **Not enough credits is a dead end.** `joinSession` throws `Exception: No tienes suficientes créditos...`, and the screen shows it raw in a red snackbar. There is no "Recargar" action and no route back to the event after buying. Buying then waits on a manual super-user approval with no ETA and no notification. The wallet and Home never show a pending purchase (only `CreditHistoryScreen` does). A new user needs four or more steps and an unknown wait before they can join anything.
3. **Price and currency don't line up.** The feed and detail show "S/ 10 por jugador". The join dialog says "10 créditos". The cancel dialog says "S/". Packages are fixed (15 for S/17, 28 for S/32, 50 for S/57, a 13–14 % markup that nobody explains). An event at S/12 forces a 15-credit buy and leaves change. Fuchigol shows its service fee at checkout instead.
4. **The join button ignores the event state.** `SessionDetailScreen` shows "Unirse a la Pichanga" on full and on past events. `joinSession` has no date check (you can pay for a finished event). A full event fails with the English `Session is full`.
5. **Join trusts a stale balance.** `joinSession` checks and writes `credits` from the client's cached `UserModel`, not from the user doc read inside the transaction. An approval that lands between refreshes can be overwritten. This is already written up in `docs/notes/join-session-server-side.md`, together with the open rules (any client can edit its own credits or any `players[]`).
6. **Organizer delete and admin remove take players' money.** In `GroupsSessionsScreen`, swipe-to-delete on an event deletes it with no refund, and the tickets are left behind. Every member sees the swipe, and the rules then reject it for non-admins. `removeUserFromSession` doesn't refund either. One bad delete is enough to lose a user for good.
7. **Home hides the feed behind the groups load.** In `HomeScreen`, `EventsFeedView` is only built inside the `GroupLoaded` branch. `GroupLoading` shows a full-page spinner, and `GroupError` replaces the whole page, so a failure in groups hides every event.
8. **Organizers hit a silent wall.** The "Crear +" button in `GroupsSessionsScreen` needs `superUser && (owner || admin)`. Curated publishing is intentional for now (owner decision, 2026-11-26). The problem is only that it's silent: anyone can create a group, then finds no way to publish and no explanation. Fix: show "Publicar eventos está disponible para organizadores verificados" with a contact action where the button would be.

## Flow inconsistencies (P1)

- **Two detail pages, one hop too many.** A signed-in user who opens a shared `/events/:id` link sees the read-only guest page and has to tap "Ver evento y unirme" to open `SessionDetailScreen`, which is a `Navigator.push` with no URL. The page where people join can't be shared or deep-linked. Use `/events/:id` as the single detail page, with the join, ticket and cancel states inline.
- **No share.** WhatsApp is where Peruvian pickup games get organised. No event has a share or copy-link button.
- **Navigation.** Mobile has no bottom nav: Eventos and Mis tickets live only in the end drawer. Desktop has Inicio / Eventos / Mis tickets but no Grupos. Home and `/events` are the same feed. Proposal: Explorar · Mis partidos · Grupos · Perfil, the same on both.
- **Private group events don't appear anywhere central.** The feed reads only `publicEvents`. Members find their group's private events only through Grupo → Ver Pichangas. Add a "De tus grupos" row on Home.
- **Mis tickets.** There is no split between upcoming and past, so past tickets still show a green "Válido". It should be "Mis partidos": the next game first, with a countdown and the free-cancel deadline.
- **Profile prompts with no payoff.** Home forces a sports pick, but the feed no longer filters by sport. Gender and age silently hide events (`applyFeedFilters`) with no hint, and nothing checks eligibility at join. Either drop the forced dialog or make the filtering visible ("Para ti" toggle, or a label on ineligible events).
- **Signup weight.** Name, surname, document type and number, email, password, confirm, and an optional group code. That is heavy against Fuchigol's phone + district. DNI is used at the door (ticket snapshot). *Owner question: keep DNI at signup, or ask for it at first join?*
- **Copy and language.** English and Portuguese strings reach users: `Session is full`, `You have already joined this session`, the `Login` app bar, `Please enter a valid email...`, and `Usuário registrado com sucesso...` in `AuthBloc`. Errors show their `Exception:` prefix. The same thing has several names: pichanga / sesión / evento / partido, and créditos / pro coins / S/. Pick a glossary.
- **Dead UI.** The notifications bell on Home does nothing.
- **Check-in.** Staff scan with the phone camera, which opens the web URL, and they must be logged in as owner, admin or super user. The organizer has no roster list with "presente" toggles, so attendance (and later no-shows) isn't captured.
- **Event detail is thin.** No description or rules, no organizer contact, no add-to-calendar, no "Cómo llegar" (Google Maps link).

## Missing table stakes (P2)

1. Waitlist with automatic promotion and a time-limited hold. Combine it with spot resale: a late cancel is refunded only if someone fills the spot.
2. Minimum players: auto-cancel X hours before, with an automatic refund to pro coins (scheduled Cloud Function).
3. Organizer "Cancelar evento" that refunds everyone and notifies them (callable, reusing the `cancelParticipation` logic).
4. Reminders: the free-cancel deadline (25 h before), kickoff (2 h before), "your credits were approved", "a waitlist spot opened". Start with email or FCM web push; WhatsApp later.
5. Recurring events in the UI (today it is an ops CSV script).
6. Attendance → no-show record → simple penalty policy (published, one version).
7. Later: player level per sport, post-match rating, event chat.

## Decisions (owner, 2026-11-26)

- Publishing stays curated (super user + group owner/admin) for now. It opens up in a near-future build.
- Later, an individual will be able to publish an event without a group. Not in this plan, but nothing here may make it harder (see "Keep the door open").
- This plan improves the flows that exist today and brings them in line with comparable apps. No new product lines.

## Plan, in order

One PR per step. Each step gets a short design note, then an implementation plan, then the build. The order follows dependencies, not only priority:

- Phase 1 first: cheapest work, biggest effect on guest → first join, no server or rules change.
- Phase 2 before Phase 4: the waitlist, auto-cancel and organizer cancel all move money. They must reuse server-side callables, not add more client writes.
- Phase 3 before Phase 4: reminders and waitlist alerts need one shareable event URL to link to.

### Phase 1 — Unblock the join funnel (client only)

**1a. Join funnel (PR 1)**
- Keep the destination through login, registration and Google: `?from=/events/:id`, honoured by `authRedirect` and the auth screens.
- Insufficient credits: check before the confirm dialog, show "Te faltan S/ X", and offer "Recargar" → purchase → return to the event.
- Bottom bar states: Unirse / Lleno / Finalizado / Inscrito.
- Spanish error mapping, with no `Exception:` prefix. Fix the Portuguese and English strings.
- Decouple the Home feed from the groups state.

**1b. Clarity (PR 2)**
- Share button (Web Share API, or copy link to `/events/:id`) on the event detail and the ticket.
- "Mis partidos": upcoming first with the free-cancel deadline, past games below.
- Drop the forced sports dialog. Show a pending-purchase state in the wallet.
- One price wording everywhere (S/ and credits 1:1, package price shown as "incluye comisión").
- Curated-publishing message instead of the missing "Crear +" (blocker 8).
- Remove the dead notifications bell until Phase 4.

### Phase 2 — Money safety (server, Cloud Functions)

- **PR 3:** callable `joinSession` (design in `docs/notes/join-session-server-side.md`): balance read inside the transaction, date and seat checks, ticket written server-side. Copy `creatorId` onto `liveSessions` here.
- **PR 4:** callable credit approval in one transaction; callable organizer "Cancelar evento" that refunds every player; admin remove refunds too. Replace swipe-to-delete, and hide it from non-admins.
- **PR 5:** lock the `users.credits`, `players[]` and `creditHistory` rules once PRs 3 and 4 are deployed.

### Phase 3 — One navigation model

- **PR 6:** `/events/:id` becomes the only event detail page (guest and member states inline). Ticket detail and create event move to GoRouter.
- **PR 7:** bottom nav on mobile, the same items on the desktop top bar: Explorar · Mis partidos · Grupos · Perfil. "De tus grupos" row on Home. Glossary in `DESIGN.md` (one name each for event and credits).
- **PR 8:** organizer tools on the event page: roster with "presente" check-in toggles. One permission helper replaces the three owner/admin checks.

### Phase 4 — Fill games and build trust

- **PR 9:** notifications foundation (FCM web push + email), then reminders (free-cancel deadline, 2 h before, credits approved).
- **PR 10:** waitlist with automatic promotion and a time-limited hold; a late cancel is refunded only if the waitlist fills the spot.
- **PR 11:** minimum players with auto-cancel and automatic refund (scheduled function).
- **PR 12:** recurring events in the create flow; attendance data → published no-show policy.

### Phase 5 — Remove manual payment

- Mercado Pago Checkout API with Yape: instant wallet top-up first (smallest change), pay-per-event later. Culqi and Izipay are alternatives.

## Keep the door open: individual organizers (future build)

Opening publishing, and allowing events with no group, should become a permission change plus a create-flow option. It should not turn into a data migration. Rules for every PR above:

1. **Key organizer logic on the event, not the group.** The permission helper (PR 8) answers "can this user manage this event?" from `creatorId` first, with group role as a second source. A group-less event then needs only `creatorId`.
2. **Publishing permission lives in one place, server-side.** The publish check is one function, used by the create flow and the rules. Opening it later is a one-line change, not a hunt through screens.
3. **Put organizer tools on the event page** (roster, check-in, cancel), not on the group page.
4. **Treat "organizer" as a display concept.** `publicEvents` already carries `groupName`. When group-less events arrive, add `organizerName` and fill it from the group or the user. Don't add new UI that assumes a group exists.
5. **`groupId` stays required for now, but don't add new code that depends on it** (new queries, storage paths, notifications). Notifications and the waitlist key on `sessionId` and `uid`.

When that build comes, it needs: optional `groupId` on templates and sessions, an `organizerName` in the projection, a rules update for group-less create and delete, a "Publicar como: yo / grupo" choice in create, and an organizer profile page.

## Open owner questions

1. How long does a Yape approval take today? Is wallet-only the long-term model, or do you want pay-per-event?
2. DNI/CE at signup, or at first join?
3. Which success metric matters most now: guest → first join, repeat joins, or organizer count?
