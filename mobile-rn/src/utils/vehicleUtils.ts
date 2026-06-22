/** Ported from lib/utils/vehicle_utils.dart's normalizeRegistration(). */
export function normalizeRegistration(registration: string): string {
  if (registration.trim().length === 0) return '';
  // Remove non-alphanumeric characters and uppercase
  return registration.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
}
