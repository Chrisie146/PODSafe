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
exports.BcHttpClient = void 0;
exports.getAccessToken = getAccessToken;
exports.createBcClient = createBcClient;
const axios_1 = __importDefault(require("axios"));
const admin = __importStar(require("firebase-admin"));
const config_1 = require("../../config");
const firestore_1 = require("../../store/firestore");
const tokenVault = new firestore_1.TokenVault();
const tokenCache = new Map();
async function getAccessToken(companyId) {
    (0, config_1.validateConfig)();
    const cached = tokenCache.get(companyId);
    if (cached && cached.expiresAt > Date.now() + 60000) {
        return cached.token;
    }
    const integration = await (0, firestore_1.getBcIntegration)(companyId);
    if (!integration || !integration.tokenSecretId) {
        throw new Error(`BC integration not configured for company: ${companyId}`);
    }
    const refreshToken = await tokenVault.loadRefreshToken(integration.tokenSecretId);
    if (!refreshToken) {
        throw new Error(`Refresh token not found for company: ${companyId}`);
    }
    const tokenEndpoint = (0, config_1.getTokenEndpoint)(integration.tenantId);
    try {
        const response = await axios_1.default.post(tokenEndpoint, new URLSearchParams({
            grant_type: 'refresh_token',
            client_id: config_1.config.bcClientId,
            client_secret: config_1.config.bcClientSecret,
            refresh_token: refreshToken,
            redirect_uri: config_1.config.bcRedirectUri,
            scope: config_1.config.bcScope,
        }), {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
        });
        const { access_token, expires_in, refresh_token: newRefreshToken } = response.data;
        tokenCache.set(companyId, {
            token: access_token,
            expiresAt: Date.now() + expires_in * 1000,
        });
        if (newRefreshToken && newRefreshToken !== refreshToken) {
            const newSecretId = await tokenVault.saveRefreshToken(companyId, newRefreshToken);
            await admin.firestore()
                .collection('companies')
                .doc(companyId)
                .collection('integrations')
                .doc('businessCentral')
                .update({ tokenSecretId: newSecretId });
            await tokenVault.deleteRefreshToken(integration.tokenSecretId);
        }
        return access_token;
    }
    catch (error) {
        console.error('Token refresh failed:', error);
        throw new Error(`Failed to refresh access token: ${error.message}`);
    }
}
function createBcClient(companyId) {
    return new BcHttpClient(companyId);
}
class BcHttpClient {
    constructor(companyId) {
        this.companyId = companyId;
        this.client = axios_1.default.create({
            timeout: 30000,
            headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
            },
        });
        this.setupRetryInterceptor();
    }
    setupRetryInterceptor() {
        this.client.interceptors.response.use(response => response, async (error) => {
            const requestConfig = error.config;
            if (!requestConfig) {
                return Promise.reject(error);
            }
            const retryCount = requestConfig._retryCount || 0;
            const maxRetries = config_1.config.maxRetries;
            const isRetryable = this.isRetryableError(error);
            if (!isRetryable || retryCount >= maxRetries) {
                return Promise.reject(this.enhanceError(error));
            }
            const retryAfter = this.getRetryAfter(error);
            const backoffDelay = retryAfter || config_1.config.retryDelay * Math.pow(config_1.config.backoffMultiplier, retryCount);
            console.log(`Retrying request (attempt ${retryCount + 1}/${maxRetries}) after ${backoffDelay}ms`);
            await this.delay(backoffDelay);
            requestConfig._retryCount = retryCount + 1;
            return this.client(requestConfig);
        });
    }
    isRetryableError(error) {
        if (!error.response) {
            return true;
        }
        const status = error.response.status;
        return status === 429 || (status >= 500 && status < 600);
    }
    getRetryAfter(error) {
        const retryAfter = error.response?.headers['retry-after'];
        if (!retryAfter) {
            return null;
        }
        const seconds = parseInt(retryAfter, 10);
        if (!isNaN(seconds)) {
            return seconds * 1000;
        }
        const date = new Date(retryAfter);
        if (!isNaN(date.getTime())) {
            return Math.max(0, date.getTime() - Date.now());
        }
        return null;
    }
    enhanceError(error) {
        const enhanced = new Error(error.message);
        enhanced.name = 'BcApiError';
        enhanced.statusCode = error.response?.status;
        enhanced.retryable = this.isRetryableError(error);
        enhanced.stack = error.stack;
        return enhanced;
    }
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    async get(endpoint, params) {
        const integration = await (0, firestore_1.getBcIntegration)(this.companyId);
        if (!integration) {
            throw new Error(`BC integration not found for company: ${this.companyId}`);
        }
        const accessToken = await getAccessToken(this.companyId);
        const baseUrl = (0, config_1.getBcApiUrl)(integration.tenantId, integration.environment);
        const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;
        const response = await this.client.get(url, {
            params,
            headers: {
                'Authorization': `Bearer ${accessToken}`,
            },
        });
        return response.data;
    }
    async post(endpoint, data) {
        const integration = await (0, firestore_1.getBcIntegration)(this.companyId);
        if (!integration) {
            throw new Error(`BC integration not found for company: ${this.companyId}`);
        }
        const accessToken = await getAccessToken(this.companyId);
        const baseUrl = (0, config_1.getBcApiUrl)(integration.tenantId, integration.environment);
        const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;
        const response = await this.client.post(url, data, {
            headers: {
                'Authorization': `Bearer ${accessToken}`,
            },
        });
        return response.data;
    }
    async patch(endpoint, data, etag) {
        const integration = await (0, firestore_1.getBcIntegration)(this.companyId);
        if (!integration) {
            throw new Error(`BC integration not found for company: ${this.companyId}`);
        }
        const accessToken = await getAccessToken(this.companyId);
        const baseUrl = (0, config_1.getBcApiUrl)(integration.tenantId, integration.environment);
        const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;
        try {
            const response = await this.client.patch(url, data, {
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    ...(etag && { 'If-Match': etag }),
                },
            });
            return response.data;
        }
        catch (error) {
            if (axios_1.default.isAxiosError(error) && error.response?.status === 412) {
                throw new Error('Document has been modified. Please refetch and retry.');
            }
            throw error;
        }
    }
}
exports.BcHttpClient = BcHttpClient;
//# sourceMappingURL=client.js.map