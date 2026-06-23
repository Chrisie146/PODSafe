/**
 * Server-side reverse geocoding (Phase 6). lat/lng -> human address via the
 * Google Geocoding REST API. The `reverseGeocode` onCall wrapper (added in the
 * next task) wraps this pure helper with an auth/active-user gate and reads the
 * API key from functions config; the helper itself takes the key as a parameter
 * so it is unit-testable with a mocked axios and no Firebase runtime.
 *
 * On any non-OK Google status, an axios error, or an exception, returns ''
 * (empty string) — never throws. A POD is legally valid with coordinates alone,
 * so capture must never fail because geocoding failed.
 */
import axios from 'axios';

export interface GeocodeResult {
  results: Array<{ formatted_address: string }>;
  status: string;
}

export async function reverseGeocodeCoords(latitude: number, longitude: number, apiKey: string): Promise<string> {
  if (!apiKey) {
    console.error('reverseGeocode: missing Google Geocoding API key (functions config google.geocoding_key / GOOGLE_GEOCODING_KEY).');
    return '';
  }

  const url = 'https://maps.googleapis.com/maps/api/geocode/json';
  try {
    const response = await axios.get<GeocodeResult>(url, {
      params: { latlng: `${latitude},${longitude}`, key: apiKey, language: 'en', region: 'za' },
      timeout: 10000,
    });
    const { status, results } = response.data;
    if (status === 'OK' && results.length > 0) {
      return results[0].formatted_address;
    }
    if (status !== 'ZERO_RESULTS') {
      console.error(`reverseGeocode: Google status ${status} for ${latitude},${longitude}`);
    }
    return '';
  } catch (error) {
    console.error(`reverseGeocode: request failed for ${latitude},${longitude}:`, (error as Error).message);
    return '';
  }
}