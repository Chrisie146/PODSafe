"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.reverseGeocode = void 0;
exports.reverseGeocodeCoords = reverseGeocodeCoords;
const axios_1 = __importDefault(require("axios"));
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const config_1 = require("../config");
async function reverseGeocodeCoords(latitude, longitude, apiKey) {
    if (!apiKey) {
        console.error('reverseGeocode: missing Google Geocoding API key (functions config google.geocoding_key / GOOGLE_GEOCODING_KEY).');
        return '';
    }
    const url = 'https://maps.googleapis.com/maps/api/geocode/json';
    try {
        const response = await axios_1.default.get(url, {
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
    }
    catch (error) {
        console.error(`reverseGeocode: request failed for ${latitude},${longitude}:`, error.message);
        return '';
    }
}
exports.reverseGeocode = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to reverse geocode.');
    }
    const { latitude, longitude } = data ?? {};
    if (typeof latitude !== 'number' || typeof longitude !== 'number' ||
        !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        throw new functions.https.HttpsError('invalid-argument', 'latitude and longitude must be finite numbers in valid ranges.');
    }
    const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    const caller = callerDoc.data();
    if (!callerDoc.exists || !caller || caller.isActive !== true) {
        throw new functions.https.HttpsError('permission-denied', 'Active user account required.');
    }
    const address = await reverseGeocodeCoords(latitude, longitude, config_1.config.googleGeocodingKey);
    return { address };
});
//# sourceMappingURL=reverseGeocode.js.map