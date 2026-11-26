import {formatCredits} from './refundPolicy';

export type JoinCheck = {
  /** null when the session has no valid eventDate. */
  eventDateMs: number | null;
  nowMs: number;
  isPrivate: boolean;
  isMember: boolean;
  playerCount: number;
  maxPlayers: number;
  balance: number;
  cost: number;
};

export type JoinError = {
  code: 'permission-denied' | 'failed-precondition';
  message: string;
};

/**
 * First reason the caller may not join, or null. Same order and Spanish copy
 * as the app (`joinBlock`): private, started, full, then balance.
 * Gender/age stay a feed filter only (product decision, not enforced here).
 */
export const joinError = (c: JoinCheck): JoinError | null => {
  if (c.isPrivate && !c.isMember) {
    return {code: 'permission-denied', message: 'Este evento es privado.'};
  }
  if (c.eventDateMs === null || c.eventDateMs <= c.nowMs) {
    return {code: 'failed-precondition', message: 'Este evento ya empezó o terminó.'};
  }
  if (c.playerCount >= c.maxPlayers) {
    return {code: 'failed-precondition', message: 'Este evento ya está lleno.'};
  }
  if (c.balance < c.cost) {
    return {
      code: 'failed-precondition',
      message:
        `No tienes saldo suficiente. Necesitas S/ ${formatCredits(c.cost)} ` +
        `y tienes S/ ${formatCredits(c.balance)}.`,
    };
  }
  return null;
};

/** Ledger spend id: unique per join (token is new on every join). */
export const spendDocId = (sessionId: string, uid: string, token: string) =>
  `spend_${sessionId}_${uid}_${token}`;
