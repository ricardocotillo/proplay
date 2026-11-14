/// Display-only mirror of the server rule in `functions/src/refundPolicy.ts`.
/// The Cloud Function is the source of truth; this only picks dialog copy.
bool isRefundable(DateTime eventDate, DateTime now) =>
    eventDate.difference(now) >= const Duration(hours: 24);
