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
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { config } from '../config';

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

export interface ReverseGeocodeData {
  latitude: number;
  longitude: number;
}

/**
 * onCall reverse geocoder. Authenticated + active users only (NOT admin-only —
 * drivers capture PODs). No company gate: lat/lng carry no tenant data. Reads
 * the Google Geocoding key from functions config and delegates to the pure
 * helper, which returns '' on any failure so capture never breaks on geocoding.
 */
export const reverseGeocode = functions.https.onCall(async (data: ReverseGeocodeData, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to reverse geocode.');
  }

  const { latitude, longitude } = data ?? {};
  if (
    typeof latitude !== 'number' || typeof longitude !== 'number' ||
    !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
    latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180
  ) {
    throw new functions.https.HttpsError('invalid-argument', 'latitude and longitude must be finite numbers in valid ranges.');
  }

  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const caller = callerDoc.data();
  if (!callerDoc.exists || !caller || caller.isActive !== true) {
    throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
  }

  const address = await reverseGeocodeCoords(latitude, longitude, config.googleGeocodingKey);
  return { address };
});
