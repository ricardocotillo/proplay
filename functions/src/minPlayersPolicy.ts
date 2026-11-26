import {Push} from './reminderPolicy';

const H = 3600_000;

/**
 * An event with a minimum is checked in the two hours after the 24 h mark
 * (the free-cancel deadline): the scheduler runs every 10 min, so there are
 * about 12 chances and a short outage is harmless. An event created inside
 * the last 22 h is never checked.
 */
export const CHECK_FROM_MS = 22 * H;
export const CHECK_TO_MS = 24 * H;

/** A usable minimum: a whole number of at least 2. */
export const validMin = (v: unknown): v is number =>
  typeof v === 'number' && Number.isInteger(v) && v >= 2;

/**
 * Should the event be cancelled for lack of players right now? `players`
 * counts everyone who held a seat at the 24 h mark: current players plus
 * late cancellers not yet paid back (they cannot force a cancel by leaving
 * inside the window). A minimum above the maximum is ignored.
 */
export const shouldAutoCancel = (c: {
  eventMs: number; nowMs: number; min: unknown; players: number; max?: unknown;
}): boolean => {
  if (!validMin(c.min)) return false;
  if (typeof c.max === 'number' && c.min > c.max) return false;
  const left = c.eventMs - c.nowMs;
  return left > CHECK_FROM_MS && left <= CHECK_TO_MS && c.players < c.min;
};

export const minCancelPlayerPush = (title: string, min: number, refunded: number): Push => ({
  title: 'Evento cancelado',
  body: `${title} se canceló: no se juntó el mínimo de ${min} jugadores. ` +
    (refunded > 0 ? `Te devolvimos S/ ${refunded.toFixed(2)} de saldo.` : 'No se te cobró nada.'),
  path: '/tickets',
});

export const minCancelOrganizerPush = (title: string, min: number, players: number): Push => ({
  title: 'Cancelamos tu evento',
  body: `${title}: faltaron jugadores (${players} de ${min}). Devolvimos el saldo a todos.`,
  path: '/groups',
});
