/**
 * Ported from lib/utils/datetime_helper.dart (verified against source on 2026-06-22).
 * South Africa uses SAST (UTC+2) year-round, no daylight saving.
 *
 * JS Date has no equivalent of Dart's `isUtc`-tagged-but-field-shifted DateTime trick the
 * source relies on. Instead, `getSouthAfricanTime()`/`toSouthAfricanTime()` return a Date
 * shifted by +2h whose *UTC* getters (`getUTCFullYear()`, `getUTCHours()`, etc.) read as
 * SAST wall-clock fields, regardless of the device's own local timezone — callers must
 * read fields via the UTC getters, not the local ones. `getSouthAfricanDate()` and the
 * start/end-of-day helpers instead return a real, correct absolute instant (safe to feed
 * straight into a Firestore Timestamp range query).
 */
const SAST_OFFSET_MS = 2 * 60 * 60 * 1000;

/** Mirrors getSouthAfricanTime(). Read fields via getUTC*() — see file-level comment. */
export function getSouthAfricanTime(): Date {
  return new Date(Date.now() + SAST_OFFSET_MS);
}

/** Mirrors toSouthAfricanTime(). Read fields via getUTC*() — see file-level comment. */
export function toSouthAfricanTime(date: Date): Date {
  return new Date(date.getTime() + SAST_OFFSET_MS);
}

/** Mirrors getSouthAfricanDate(): the real instant of SAST midnight today. */
export function getSouthAfricanDate(): Date {
  const sast = getSouthAfricanTime();
  return new Date(Date.UTC(sast.getUTCFullYear(), sast.getUTCMonth(), sast.getUTCDate()) - SAST_OFFSET_MS);
}

/** Mirrors isTodaySA(): whether `date`'s instant falls within today's SAST calendar day. */
export function isTodaySA(date: Date): boolean {
  const startOfToday = getSouthAfricanDate().getTime();
  const endOfToday = startOfToday + 86400000;
  return date.getTime() >= startOfToday && date.getTime() < endOfToday;
}

/** Mirrors getStartOfTodaySA(). */
export function getStartOfTodaySA(): Date {
  return getSouthAfricanDate();
}

/** Mirrors getEndOfTodaySA(). */
export function getEndOfTodaySA(): Date {
  return new Date(getSouthAfricanDate().getTime() + 86400000 - 1);
}
