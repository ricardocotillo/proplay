/**
 * Who may cancel an event or remove a player. Keyed on the event first
 * (`creatorId`), the group role second, so a group-less event later needs
 * only `creatorId`.
 */
export const canManageEvent = (p: {
  uid: string;
  creatorId: unknown;
  memberRole: unknown;
  superUser: boolean;
}): boolean =>
  p.superUser ||
  (typeof p.creatorId === 'string' && p.creatorId !== '' && p.creatorId === p.uid) ||
  p.memberRole === 'owner' ||
  p.memberRole === 'admin';

export type ReviewError = {code: 'not-found' | 'failed-precondition'; message: string};

/** Why a creditHistory row can't be approved or rejected, or null. */
export const reviewError = (entry: Record<string, unknown> | undefined): ReviewError | null => {
  if (!entry) return {code: 'not-found', message: 'No encontramos esta solicitud.'};
  if (entry.status !== 'pending') {
    return {code: 'failed-precondition', message: 'Esta solicitud ya fue revisada.'};
  }
  const amount = entry.creditAmount;
  const paid = entry.amountPaid;
  // Packages charge a fee on top, so saldo never exceeds what was paid.
  if (entry.entryType !== 'purchase' || typeof entry.userId !== 'string' || !entry.userId ||
      typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0 ||
      typeof paid !== 'number' || !(paid >= amount)) {
    return {code: 'failed-precondition', message: 'Esta solicitud no es válida.'};
  }
  return null;
};
