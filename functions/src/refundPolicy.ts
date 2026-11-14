export const REFUND_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Full refund when the event starts 24 h or more from `now`. */
export const isRefundable = (eventDate: Date, now: Date): boolean =>
  eventDate.getTime() - now.getTime() >= REFUND_WINDOW_MS;

/** Mirrors Dart `UserModel.formatCredits`. */
export const formatCredits = (v: number): string => v.toFixed(2);

/** One refund per ledger `spend` row: the id is derived from the spend doc id. */
export const refundDocId = (spendId: string) => `refund_${spendId}`;

export type SpendRow = {id: string; creditAmount: number; createdAtMs: number; refunded: boolean};

/** Latest `spend` row that has not been refunded yet, or undefined. */
export const pickUnrefundedSpend = (rows: SpendRow[]): SpendRow | undefined =>
  rows
    .filter((r) => !r.refunded)
    .sort((a, b) => b.createdAtMs - a.createdAtMs)[0];

/** Refund never exceeds the event price; invalid inputs refund nothing. */
export const refundAmount = (pricePaid: number, costPerPlayer: unknown): number => {
  const cost = Number(costPerPlayer);
  if (!Number.isFinite(pricePaid) || !Number.isFinite(cost)) return 0;
  return Math.max(0, Math.min(pricePaid, cost));
};
