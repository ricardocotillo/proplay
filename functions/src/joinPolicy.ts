import {formatCredits} from './refundPolicy';

export type JoinCheck = {
  /** null when the session has no valid eventDate. */
  eventDateMs: number | null;
  nowMs: number;
  isPrivate: boolean;
  isMember: boolean;
  playerCount: number;
  /** `session.maxPlayers` when it is a number, else NaN. */
  maxPlayers: number;
  balance: number;
  /** `session.costPerPlayer` when it is a number (may be negative), else NaN. */
  cost: number;
};

/** Money is whole cents everywhere (mirrors `formatCredits`). */
export const roundCents = (v: number): number => Math.round(v * 100) / 100;

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
  // A broken event never lets anyone in: a missing/NaN price would be a free
  // join, a negative one would raise the balance.
  if (!Number.isFinite(c.cost) || c.cost < 0 ||
      !Number.isFinite(c.maxPlayers) || c.maxPlayers <= 0) {
    return {code: 'failed-precondition', message: 'Este evento no está disponible.'};
  }
  if (c.eventDateMs === null || c.eventDateMs <= c.nowMs) {
    return {code: 'failed-precondition', message: 'Este evento ya empezó o terminó.'};
  }
  if (c.playerCount >= c.maxPlayers) {
    return {code: 'failed-precondition', message: 'Este evento ya está lleno.'};
  }
  if (c.balance < roundCents(c.cost)) {
    return {
      code: 'failed-precondition',
      message:
        `No tienes saldo suficiente. Necesitas S/ ${formatCredits(roundCents(c.cost))} ` +
        `y tienes S/ ${formatCredits(c.balance)}.`,
    };
  }
  return null;
};

/** Join and waitlist need a DNI or CE on the account (legacy docs have ''). */
export const hasIdentityDocument = (
  u: {documentType?: unknown; documentNumber?: unknown},
): boolean =>
  (u.documentType === 'dni' || u.documentType === 'ce') &&
  typeof u.documentNumber === 'string' && u.documentNumber.length > 0;

export const DOCUMENT_REQUIRED_MESSAGE =
  'Registra tu DNI o carnet de extranjería para unirte a eventos. ' +
  'Si no ves la opción, actualiza la app.';

/** Ledger spend id: unique per join (token is new on every join). */
export const spendDocId = (sessionId: string, uid: string, token: string) =>
  `spend_${sessionId}_${uid}_${token}`;
