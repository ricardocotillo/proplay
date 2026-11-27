# Identity document required to join events

## Problem
Organizers and door staff cannot reliably identify who attends an event. New accounts already register with a mandatory, unique DNI or carnet de extranjería (CE), but many legacy accounts have no document and can still join events and waitlists. Organizers have complained. No incident yet, but an unidentifiable attendee is a safety risk for every event and for ProPlay's reputation.

## Evidence
- Complaints from organizers / door staff about attendees without identification. Count and wording: TBD — needs validation via support log review.
- "Many" legacy accounts have no document (`documentType == ''`). Exact count: TBD — needs validation via a Firestore count of users without a document, and how many of them joined an event in the last 90 days.
- Registration already requires DNI/CE, so the gap is only legacy accounts.

## Users
- **Primary**: event organizers (group owner/admin, event creator) and door staff who scan the QR ticket and need to match the person to a document.
- **Affected**: legacy players without a document, asked once when they try to join an event or a waitlist.
- **Not for**: guests (they cannot join), players who already have a document (no extra step).

## Hypothesis
We believe **asking for a DNI or CE at join time when the account has none (and reusing it when it exists)** will **give organizers and door staff the identity of every attendee** for **organizers and door staff**.
We'll know we're right when **100% of new tickets carry a document and organizer complaints about unidentified attendees go down**.

## Success Metrics
| Metric | Target | How measured |
|---|---|---|
| New tickets with a document snapshot | 100% | Count of tickets created after launch with empty document fields (must be 0) |
| Organizer complaints about unidentified attendees | Down vs. pre-launch baseline | Support log; baseline TBD |
| Legacy players who drop out at the document step | TBD — monitor, no target yet | Join attempts blocked at the document step vs. completed |

## Scope
**MVP**
- Joining any event (paid or free) and joining a waitlist require the account to have a DNI or CE.
- If the account has one, reuse it; no extra step.
- If not, ask for it in the join flow (DNI or CE, same rules as registration: format and uniqueness), save it to the profile once, then continue the join.
- The requirement is enforced server-side, not only in the UI.
- The organizer / door staff sees the document when scanning the QR ticket (already true for tickets with a document).
- The player can correct their document, at most once every 30 days since the last change, enforced server-side (not only in the UI). A legacy player's first correction right after adding the document is allowed. Existing tickets keep the old document.
- If the entered number belongs to another account, the player sees why the join stopped and the support contact (ricardo@cotillo.dev).
- Registration keeps offering both DNI and CE.

**Out of scope**
- External validation (RENIEC, Migraciones, third-party DNI APIs) — costly or legally unclear; revisit later.
- Document photo upload or check-digit verification — not requested for now.
- Showing documents in the organizer's player list — organizers see it only on QR scan.
- Asking for the document at login or as a blocking prompt outside the join flow.
- Backfilling documents for tickets legacy players already hold — accepted gap.

## Delivery Milestones
| # | Milestone | Outcome | Status | Plan |
|---|---|---|---|---|
| 1 | Document gate at join | A legacy player must enter a DNI/CE before joining an event or waitlist; players with a document join as today; server refuses joins without one | complete | `.claude/PRPs/plans/completed/event-join-document-gate.plan.md`; report `.claude/PRPs/reports/event-join-document-gate-report.md` |
| 2 | Document correction | A player can change their document from the profile, at most once every 30 days, keeping uniqueness | complete | `.claude/PRPs/plans/completed/event-document-correction.plan.md`; report `.claude/PRPs/reports/event-document-correction-report.md` |

## Open Questions
All resolved (2026-11-27):
- [x] Correction window: 30 days since the **last change**. A legacy player who just added their document can correct it right away; that correction counts as the first change and starts the 30-day clock.
- [x] On correction, existing tickets **keep the old document snapshot**. Only tickets created after the change carry the new one.
- [x] Number already claimed by another account: show an error that explains the number is registered to another account and that the join cannot continue, and tells the player to contact support at ricardo@cotillo.dev.
- [x] Legacy players already holding tickets for upcoming events without a document: **accept the gap**. No prompt before the event.
- [x] Waitlist offer confirmation: no separate prompt. Joining the waitlist already requires a document.

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Legacy players abandon joining at the new step | Medium | Fewer joins, lower revenue | Short inline step, clear Spanish copy explaining why; monitor drop-off |
| Fake or someone else's number entered (no external validation) | Medium | Identity on ticket is wrong | Door staff checks the physical document against the ticket; uniqueness blocks reuse |
| Correction abused to dodge no-show blocks or bans | Low | Weakens safety controls | 30-day limit; blocks are tied to the account, not the document |
| Legitimate owner finds their number already claimed | Low | Cannot join | Error explains the situation and points to support (ricardo@cotillo.dev) |
| Rules today forbid changing the document after account creation | High (known) | Legacy players cannot add or correct one | Decided: first-time add (empty to DNI/CE) is allowed by the rules under the same format + uniqueness guarantees as registration; correction (release old lock, claim new, 30-day limit) goes through the server in one transaction; the join gate is enforced by the join and waitlist server calls. Diff rules against the console before deploying |

---
*Status: DRAFT — requirements only. Implementation planning pending via /plan.*
