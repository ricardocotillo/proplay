import {Push} from './reminderPolicy';

const DAY = 86_400_000;

/** No-shows older than this stop counting. */
export const WINDOW_MS = 90 * DAY;
/** The second no-show in the window gets a warning. */
export const WARN_AT = 2;
/** The third blocks new joins. */
export const BLOCK_AT = 3;
export const BLOCK_MS = 14 * DAY;

/** What a new no-show triggers, given how many count in the window (including it). */
export const noShowActions = (count: number): {warn: boolean; block: boolean} => ({
  warn: count === WARN_AT,
  block: count >= BLOCK_AT,
});

export const isBlocked = (blockedUntilMs: number | undefined, nowMs: number): boolean =>
  typeof blockedUntilMs === 'number' && blockedUntilMs > nowMs;

/** The later of the current block and now + 14 days. */
export const nextBlockMs = (current: number | undefined, nowMs: number): number =>
  Math.max(current ?? 0, nowMs + BLOCK_MS);

/** Does this ticket count as a no-show? Only when the organizer took attendance. */
export const isNoShow = (ticketStatus: unknown, anyoneCheckedIn: boolean): boolean =>
  anyoneCheckedIn && ticketStatus === 'valid';

const fmtDate = (ms: number): string =>
  new Intl.DateTimeFormat('es-PE', {
    day: 'numeric', month: 'long', timeZone: 'America/Lima',
  }).format(new Date(ms));

/** Shown when a blocked user tries to join. */
export const blockedMessage = (untilMs: number): string =>
  `No puedes unirte a nuevos eventos hasta el ${fmtDate(untilMs)} por ausencias. ` +
  'Mira la política de asistencia en la app.';

export const noShowWarnPush = (title: string): Push => ({
  title: 'No asististe a tu evento',
  body: `${title}: llevas 2 ausencias en 90 días. Con la tercera no podrás unirte a nuevos eventos por 14 días. ` +
    'Si no puedes ir, cancela antes.',
  path: '/politica-asistencia',
});

export const noShowBlockPush = (untilMs: number): Push => ({
  title: 'Pausa para unirte a eventos',
  body: `Por 3 ausencias en 90 días no podrás unirte a nuevos eventos hasta el ${fmtDate(untilMs)}.`,
  path: '/politica-asistencia',
});
