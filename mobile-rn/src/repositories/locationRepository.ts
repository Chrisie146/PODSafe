import functions from '@react-native-firebase/functions';

/**
 * Phase 6 reverse-geocoding client. Thin wrapper over the `reverseGeocode`
 * Cloud Function (functions/src/location/reverseGeocode.ts), which calls the
 * Google Geocoding API server-side so the billable key never ships in the app.
 *
 * Returns the resolved address string, or '' on any failure (callable throws,
 * network error, Google non-OK status, missing field). NEVER throws — pod
 * capture must not break on geocoding failure; a POD is valid with coordinates
 * alone. See the design spec for the empty-string fallback decision.
 */
export async function reverseGeocode(latitude: number, longitude: number): Promise<string> {
  try {
    const callable = functions().httpsCallable('reverseGeocode');
    const response = await callable({ latitude, longitude });
    const address = (response.data as { address?: string }).address;
    return typeof address === 'string' ? address : '';
  } catch (error) {
    console.warn('reverseGeocode failed:', (error as Error).message);
    return '';
  }
}
