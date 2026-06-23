import * as functions from 'firebase-functions';
export interface GeocodeResult {
    results: Array<{
        formatted_address: string;
    }>;
    status: string;
}
export declare function reverseGeocodeCoords(latitude: number, longitude: number, apiKey: string): Promise<string>;
export interface ReverseGeocodeData {
    latitude: number;
    longitude: number;
}
export declare const reverseGeocode: functions.HttpsFunction & functions.Runnable<any>;
//# sourceMappingURL=reverseGeocode.d.ts.map