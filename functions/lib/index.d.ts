import * as functions from 'firebase-functions';
import { createCompanyWithAdmin } from './createCompanyWithAdmin';
export { createCompanyWithAdmin };
export declare const bcOAuthRedirect: functions.HttpsFunction;
export declare const bcOAuthCallback: functions.HttpsFunction;
export declare const bcPullShipments: functions.HttpsFunction;
export declare const bcPushPod: functions.HttpsFunction;
export declare const bcScheduledPull: functions.CloudFunction<unknown>;
export declare const bcAutoPushPod: functions.CloudFunction<functions.Change<functions.firestore.QueryDocumentSnapshot>>;
export declare const bcHealth: functions.HttpsFunction;
export * from './auth/userManagement';
//# sourceMappingURL=index.d.ts.map