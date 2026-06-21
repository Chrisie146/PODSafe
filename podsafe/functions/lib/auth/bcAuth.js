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
exports.callback = exports.redirect = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const config_1 = require("../config");
const firestore_1 = require("../store/firestore");
const tokenVault = new firestore_1.TokenVault();
function decodeJwt(token) {
    const parts = token.split('.');
    if (parts.length !== 3) {
        throw new Error('Invalid JWT');
    }
    const payload = Buffer.from(parts[1], 'base64').toString('utf-8');
    return JSON.parse(payload);
}
function encodeState(state) {
    return Buffer.from(JSON.stringify(state)).toString('base64url');
}
function decodeState(stateParam) {
    const json = Buffer.from(stateParam, 'base64url').toString('utf-8');
    return JSON.parse(json);
}
function generateNonce() {
    return Math.random().toString(36).substring(2) + Date.now().toString(36);
}
exports.redirect = functions.https.onRequest(async (req, res) => {
    try {
        console.log('=== bcOAuthRedirect called (v3) ===');
        console.log('Config values:', {
            clientId: config_1.config.bcClientId,
            hasClientId: !!config_1.config.bcClientId,
            authority: config_1.config.bcOAuthAuthority,
            redirectUri: config_1.config.bcRedirectUri,
        });
        const { companyId, redirectTo } = req.query;
        if (!companyId || typeof companyId !== 'string') {
            res.status(400).send('Missing companyId parameter');
            return;
        }
        const companyDoc = await admin.firestore().collection('companies').doc(companyId).get();
        if (!companyDoc.exists) {
            await admin.firestore().collection('companies').doc(companyId).set({
                name: companyId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                isActive: true,
                createdBy: 'bc-oauth-system',
            });
            console.log('Auto-created company for BC OAuth testing:', companyId);
        }
        const state = {
            companyId,
            nonce: generateNonce(),
            ts: Date.now(),
            redirectTo: typeof redirectTo === 'string' ? redirectTo : undefined,
        };
        const stateParam = encodeState(state);
        console.log('OAuth Config loaded:', {
            clientId: config_1.config.bcClientId.substring(0, 8) + '...',
            authority: config_1.config.bcOAuthAuthority,
            redirectUri: config_1.config.bcRedirectUri,
        });
        const authUrl = new URL(`${config_1.config.bcOAuthAuthority}/oauth2/v2.0/authorize`);
        authUrl.searchParams.append('client_id', config_1.config.bcClientId);
        authUrl.searchParams.append('response_type', 'code');
        authUrl.searchParams.append('redirect_uri', config_1.config.bcRedirectUri);
        authUrl.searchParams.append('scope', config_1.config.bcScope);
        authUrl.searchParams.append('state', stateParam);
        authUrl.searchParams.append('response_mode', 'form_post');
        authUrl.searchParams.append('prompt', 'select_account');
        console.log('Redirecting to BC OAuth:', {
            companyId,
            redirectUri: config_1.config.bcRedirectUri,
            clientId: config_1.config.bcClientId,
            authority: config_1.config.bcOAuthAuthority,
        });
        res.redirect(authUrl.toString());
    }
    catch (error) {
        console.error('OAuth redirect error:', error);
        res.status(500).send('Internal server error');
    }
});
exports.callback = functions.https.onRequest(async (req, res) => {
    try {
        const query = req.method === 'POST' ? req.body : req.query;
        const { code, state: stateParam, error, error_description } = query;
        if (error) {
            console.error('OAuth error:', error, error_description);
            res.status(400).send(`Authentication failed: ${error_description || error}`);
            return;
        }
        if (!code || typeof code !== 'string') {
            res.status(400).send('Missing authorization code');
            return;
        }
        if (!stateParam || typeof stateParam !== 'string') {
            res.status(400).send('Missing state parameter');
            return;
        }
        const state = decodeState(stateParam);
        const maxAge = 10 * 60 * 1000;
        if (Date.now() - state.ts > maxAge) {
            res.status(400).send('State parameter expired');
            return;
        }
        console.log('OAuth callback received:', { companyId: state.companyId });
        const tokenEndpoint = (0, config_1.getTokenEndpoint)();
        const tokenResponse = await axios_1.default.post(tokenEndpoint, new URLSearchParams({
            grant_type: 'authorization_code',
            client_id: config_1.config.bcClientId,
            client_secret: config_1.config.bcClientSecret,
            code,
            redirect_uri: config_1.config.bcRedirectUri,
            scope: config_1.config.bcScope,
        }), {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
        });
        const { access_token, refresh_token, id_token } = tokenResponse.data;
        if (!refresh_token) {
            throw new Error('No refresh token received. Ensure offline_access scope is requested.');
        }
        const idTokenClaims = decodeJwt(id_token);
        const tenantId = idTokenClaims.tid;
        const userId = idTokenClaims.oid;
        console.log('Tokens received:', { tenantId, userId });
        const companiesUrl = `${(0, config_1.getBcApiUrl)(tenantId, 'Sandbox')}/companies`;
        const companiesResponse = await axios_1.default.get(companiesUrl, {
            headers: {
                'Authorization': `Bearer ${access_token}`,
            },
        });
        const companies = companiesResponse.data.value;
        if (companies.length === 0) {
            res.status(400).send('No Business Central companies found in your tenant.');
            return;
        }
        const bcCompany = companies[0];
        console.log('BC companies discovered:', companies.length, 'Selected:', bcCompany.displayName);
        const tokenSecretId = await tokenVault.saveRefreshToken(state.companyId, refresh_token);
        await (0, firestore_1.saveBcIntegration)(state.companyId, {
            tenantId,
            environment: 'Sandbox',
            companyId: bcCompany.id,
            companyName: bcCompany.displayName,
            connectedAt: admin.firestore.Timestamp.now(),
            connectedBy: userId,
            status: 'connected',
            tokenSecretId,
        });
        console.log('BC integration saved successfully');
        const successHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Connected to Business Central</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: #f5f5f5;
          }
          .container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
          }
          .success-icon {
            font-size: 64px;
            color: #4CAF50;
            margin-bottom: 20px;
          }
          h1 {
            color: #333;
            margin-bottom: 10px;
          }
          p {
            color: #666;
            line-height: 1.6;
          }
          .company-name {
            font-weight: bold;
            color: #2196F3;
          }
          .btn {
            display: inline-block;
            margin-top: 20px;
            padding: 12px 24px;
            background: #2196F3;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            font-weight: 500;
          }
          .btn:hover {
            background: #1976D2;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✓</div>
          <h1>Connected Successfully!</h1>
          <p>
            Your PODSafe account has been connected to<br>
            <span class="company-name">${bcCompany.displayName}</span>
          </p>
          <p>
            You can now sync deliveries between PODSafe and Business Central.
          </p>
          ${state.redirectTo
            ? `<a href="${state.redirectTo}" class="btn">Return to PODSafe</a>`
            : '<p>You can close this window now.</p>'}
        </div>
        ${state.redirectTo ? `
          <script>
            // Auto-close after 3 seconds if redirectTo is provided
            setTimeout(() => {
              window.location.href = '${state.redirectTo}';
            }, 3000);
          </script>
        ` : ''}
      </body>
      </html>
    `;
        res.status(200).send(successHtml);
    }
    catch (error) {
        console.error('OAuth callback error:', error);
        const errorHtml = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>Connection Failed</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: #f5f5f5;
          }
          .container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
            max-width: 500px;
          }
          .error-icon {
            font-size: 64px;
            color: #f44336;
            margin-bottom: 20px;
          }
          h1 {
            color: #333;
            margin-bottom: 10px;
          }
          p {
            color: #666;
            line-height: 1.6;
          }
          .error-message {
            background: #ffebee;
            padding: 12px;
            border-radius: 4px;
            margin-top: 16px;
            font-family: monospace;
            font-size: 12px;
            color: #c62828;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">✗</div>
          <h1>Connection Failed</h1>
          <p>We couldn't connect to Business Central.</p>
          <div class="error-message">${error.message}</div>
          <p style="margin-top: 20px;">Please try again or contact support if the problem persists.</p>
        </div>
      </body>
      </html>
    `;
        res.status(500).send(errorHtml);
    }
});
//# sourceMappingURL=bcAuth.js.map