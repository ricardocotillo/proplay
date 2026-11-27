import {fmtDate} from './attendancePolicy';

const DAY = 86_400_000;
/** Minimum time between two document changes. Keep equal to lib/utils/document.dart. */
export const DOCUMENT_COOLDOWN_MS = 30 * DAY;

/** Same rules as lib/utils/document.dart and firestore.rules. */
export const normalizeDocument = (s: string): string => s.trim().toUpperCase();

export const isValidDocument = (type: unknown, number: unknown): boolean =>
  typeof number === 'string' &&
  ((type === 'dni' && /^[0-9]{8}$/.test(number)) ||
   (type === 'ce' && /^[A-Z0-9]{9,12}$/.test(number)));

/** Lock id in `documents/`. */
export const documentKey = (type: string, number: string): string => `${type}_${number}`;

/** When the next change is allowed, or null if now (no previous change counts as allowed). */
export const nextChangeMs = (changedAtMs: number | undefined, nowMs: number): number | null =>
  typeof changedAtMs === 'number' && changedAtMs + DOCUMENT_COOLDOWN_MS > nowMs
    ? changedAtMs + DOCUMENT_COOLDOWN_MS
    : null;

export const cooldownMessage = (untilMs: number): string =>
  `Solo puedes cambiar tu documento una vez cada 30 días. Podrás hacerlo desde el ${fmtDate(untilMs)}.`;

export const DOCUMENT_TAKEN_MESSAGE =
  'Este documento ya está registrado en otra cuenta, así que no puedes usarlo. ' +
  'Si es tuyo, escríbenos a ricardo@cotillo.dev.';
