/** Reminder kinds, in the order they happen before an event. */
export type ReminderKind = 'cancel_deadline' | 'two_hours';

const H = 3600_000;
/** Free cancel closes 24 h before the start (`isRefundable`). */
const FREE_CANCEL_MS = 24 * H;

/**
 * Reminders that are due for an event starting at `eventMs`, given `nowMs`.
 * The scheduler runs every few minutes, so each kind is due for a window:
 * the hour before the free-cancel deadline, and the last two hours. A claim
 * doc per (event, kind) makes sure each is sent once.
 */
export const dueReminders = (eventMs: number, nowMs: number): ReminderKind[] => {
  const left = eventMs - nowMs;
  const due: ReminderKind[] = [];
  if (left > FREE_CANCEL_MS && left <= FREE_CANCEL_MS + H) due.push('cancel_deadline');
  if (left > 0 && left <= 2 * H) due.push('two_hours');
  return due;
};

export type Push = {title: string; body: string; path: string};

const fmtTime = (ms: number): string =>
  new Intl.DateTimeFormat('es-PE', {
    hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'America/Lima',
  }).format(new Date(ms));

/** Spanish copy, one word per thing (evento, saldo). */
export const reminderPush = (
  kind: ReminderKind, title: string, eventMs: number, eventId: string,
): Push => {
  const path = `/events/${eventId}`;
  return kind === 'cancel_deadline'
    ? {
      title: 'Última hora para cancelar gratis',
      body: `${title}: si no puedes ir, cancela en la próxima hora y recuperas tu saldo.`,
      path,
    }
    : {
      title: 'Tu evento empieza pronto',
      body: `${title} empieza a las ${fmtTime(eventMs)}. Muestra tu ticket al llegar.`,
      path,
    };
};

export const creditApprovedPush = (credits: number): Push => ({
  title: 'Saldo aprobado',
  body: `Ya tienes S/ ${credits.toFixed(2)} más de saldo para unirte a eventos.`,
  path: '/profile',
});

/** Id of the doc that claims a notification so it is sent once. */
export const claimId = (kind: string, id: string): string => `${kind}_${id}`;
