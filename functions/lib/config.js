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
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = void 0;
exports.validateConfig = validateConfig;
exports.getTokenEndpoint = getTokenEndpoint;
exports.getBcApiUrl = getBcApiUrl;
const functions = __importStar(require("firebase-functions"));
exports.config = {
    get bcOAuthAuthority() {
        return process.env.BC_OAUTH_AUTHORITY || functions.config().bc?.oauth_authority || 'https://login.microsoftonline.com/common';
    },
    get bcClientId() {
        return process.env.BC_CLIENT_ID || functions.config().bc?.client_id || '';
    },
    get bcClientSecret() {
        return process.env.BC_CLIENT_SECRET || functions.config().bc?.client_secret || '';
    },
    get bcRedirectUri() {
        return process.env.BC_REDIRECT_URI || functions.config().bc?.redirect_uri || 'https://us-central1-podsafe-92a3e.cloudfunctions.net/bcOAuthCallback';
    },
    get bcScope() {
        return process.env.BC_SCOPE || functions.config().bc?.scope || 'https://api.businesscentral.dynamics.com/.default offline_access';
    },
    bcApiBaseUrl: 'https://api.businesscentral.dynamics.com/v2.0',
    gcpProjectId: process.env.GCP_PROJECT_ID || process.env.GCLOUD_PROJECT || '',
    sessionSecret: process.env.SESSION_SECRET || 'change-me-in-production',
    maxRetries: 3,
    retryDelay: 1000,
    backoffMultiplier: 2,
};
function validateConfig() {
    const required = [
        'bcClientId',
        'bcClientSecret',
        'bcRedirectUri',
    ];
    const missing = required.filter(key => !exports.config[key]);
    if (missing.length > 0) {
        throw new Error(`Missing required configuration: ${missing.join(', ')}`);
    }
}
function getTokenEndpoint(tenantId = 'common') {
    return `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;
}
function getBcApiUrl(tenantId, environment = 'Production') {
    return `${exports.config.bcApiBaseUrl}/${tenantId}/${environment}/api/v2.0`;
}
//# sourceMappingURL=config.js.map