/**
 * Why a creditHistory row looks client-forged, or [] when it looks fine.
 * Function-written spends have id `spend_*` plus balanceBefore/After; refunds
 * have id `refund_spend_*`. Older client joins wrote spends too, so a flag
 * means "check by hand", not "delete".
 */
export const ledgerSuspicion = (
  id: string, d: Record<string, unknown>, nowMs: number,
): string[] => {
  const reasons: string[] = [];
  const createdMs = (d.createdAt as {toMillis?: () => number} | undefined)?.toMillis?.();
  if (createdMs !== undefined && createdMs > nowMs) reasons.push('createdAt in the future');
  if (d.entryType === 'spend') {
    if (!id.startsWith('spend_')) reasons.push('spend without a spend_ id');
    if (typeof d.balanceBefore !== 'number' || typeof d.balanceAfter !== 'number') {
      reasons.push('spend without balanceBefore/After');
    }
  }
  if (d.entryType === 'refund' && !id.startsWith('refund_spend_')) {
    reasons.push('refund without a refund_spend_ id');
  }
  if (id.startsWith('refund_') && d.entryType !== 'refund') {
    reasons.push('non-refund row at a refund_ id (blocks that refund)');
  }
  if (id.startsWith('spend_') && d.entryType !== 'spend') {
    reasons.push('non-spend row at a spend_ id');
  }
  if (d.entryType === 'purchase' && typeof d.creditAmount === 'number' &&
      !(typeof d.amountPaid === 'number' && d.amountPaid >= d.creditAmount)) {
    reasons.push('purchase worth more saldo than paid');
  }
  return reasons;
};
