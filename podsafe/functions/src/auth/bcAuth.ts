/**
 * Business Central OAuth Authentication Handlers
 * Multi-tenant redirect and callback
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import axios from 'axios';
import { config, getTokenEndpoint, getBcApiUrl } from '../config';
import { saveBcIntegration, TokenVault } from '../store/firestore';
import { OAuthState, TokenResponse, IdTokenClaims, BCCompany } from '../types';

const tokenVault = new TokenVault();

/**
 * Decode JWT without verification (id_token is already verified by Microsoft)
 */
function decodeJwt<T = any>(token: string): T {
  const parts = token.split('.');
  if (parts.length !== 3) {
    throw new Error('Invalid JWT');
  }
  
  const payload = Buffer.from(parts[1], 'base64').toString('utf-8');
  return JSON.parse(payload);
}

/**
 * Encode OAuth state parameter
 */
function encodeState(state: OAuthState): string {
  return Buffer.from(JSON.stringify(state)).toString('base64url');
}

/**
 * Decode OAuth state parameter
 */
function decodeState(stateParam: string): OAuthState {
  const json = Buffer.from(stateParam, 'base64url').toString('utf-8');
  return JSON.parse(json);
}

/**
 * Generate cryptographically secure nonce
 */
function generateNonce(): string {
  return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

/**
 * GET /auth/bc/redirect
 * Initiate OAuth flow - redirect user to Microsoft login
 * 
 * @param companyId PODSafe company ID (from query string)
 */
export const redirect = functions.https.onRequest(async (req, res) => {
  try {
    console.log('=== bcOAuthRedirect called (v3) ===');
    console.log('Config values:', {
      clientId: config.bcClientId,
      hasClientId: !!config.bcClientId,
      authority: config.bcOAuthAuthority,
      redirectUri: config.bcRedirectUri,
    });
    
    const { companyId, redirectTo } = req.query;

    if (!companyId || typeof companyId !== 'string') {
      res.status(400).send('Missing companyId parameter');
      return;
    }

    // Verify company exists (or create for testing)
    const companyDoc = await admin.firestore().collection('companies').doc(companyId).get();
    if (!companyDoc.exists) {
      // Auto-create company for testing
      await admin.firestore().collection('companies').doc(companyId).set({
        name: companyId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
        createdBy: 'bc-oauth-system',
      });
      console.log('Auto-created company for BC OAuth testing:', companyId);
    }

    // Build state parameter
    const state: OAuthState = {
      companyId,
      nonce: generateNonce(),
      ts: Date.now(),
      redirectTo: typeof redirectTo === 'string' ? redirectTo : undefined,
    };

    const stateParam = encodeState(state);

    // Log config for debugging
    console.log('OAuth Config loaded:', {
      clientId: config.bcClientId.substring(0, 8) + '...',
      authority: config.bcOAuthAuthority,
      redirectUri: config.bcRedirectUri,
    });

    // Build authorization URL
    const authUrl = new URL(`${config.bcOAuthAuthority}/oauth2/v2.0/authorize`);
    authUrl.searchParams.append('client_id', config.bcClientId);
    authUrl.searchParams.append('response_type', 'code');
    authUrl.searchParams.append('redirect_uri', config.bcRedirectUri);
    authUrl.searchParams.append('scope', config.bcScope);
    authUrl.searchParams.append('state', stateParam);
    authUrl.searchParams.append('response_mode', 'form_post'); // Use form_post for POST redirect back
    authUrl.searchParams.append('prompt', 'select_account'); // Allow user to choose account

    console.log('Redirecting to BC OAuth:', { 
      companyId, 
      redirectUri: config.bcRedirectUri,
      clientId: config.bcClientId,
      authority: config.bcOAuthAuthority,
    });

    // Redirect to Microsoft
    res.redirect(authUrl.toString());
  } catch (error) {
    console.error('OAuth redirect error:', error);
    res.status(500).send('Internal server error');
  }
});

/**
 * GET /auth/bc/callback
 * Handle OAuth callback from Microsoft
 * Exchange authorization code for tokens and discover BC companies
 */
export const callback = functions.https.onRequest(async (req, res) => {
  try {
    // Handle both GET (query) and POST (form body) for callback
    const query = req.method === 'POST' ? req.body : req.query;
    const { code, state: stateParam, error, error_description } = query;

    // Check for OAuth errors
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

    // Decode and validate state
    const state = decodeState(stateParam);
    
    // Check state timestamp (prevent replay attacks)
    const maxAge = 10 * 60 * 1000; // 10 minutes
    if (Date.now() - state.ts > maxAge) {
      res.status(400).send('State parameter expired');
      return;
    }

    console.log('OAuth callback received:', { companyId: state.companyId });

    // Exchange code for tokens
    const tokenEndpoint = getTokenEndpoint(); // Use 'common' for multi-tenant
    const tokenResponse = await axios.post<TokenResponse>(
      tokenEndpoint,
      new URLSearchParams({
        grant_type: 'authorization_code',
        client_id: config.bcClientId,
        client_secret: config.bcClientSecret,
        code,
        redirect_uri: config.bcRedirectUri,
        scope: config.bcScope,
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const { access_token, refresh_token, id_token } = tokenResponse.data;

    if (!refresh_token) {
      throw new Error('No refresh token received. Ensure offline_access scope is requested.');
    }

    // Decode ID token to get tenant ID
    const idTokenClaims = decodeJwt<IdTokenClaims>(id_token!);
    const tenantId = idTokenClaims.tid;
    const userId = idTokenClaims.oid;

    console.log('Tokens received:', { tenantId, userId });

    // Discover BC companies
    const companiesUrl = `${getBcApiUrl(tenantId, 'Sandbox')}/companies`;
    const companiesResponse = await axios.get<{ value: BCCompany[] }>(
      companiesUrl,
      {
        headers: {
          'Authorization': `Bearer ${access_token}`,
        },
      }
    );

    const companies = companiesResponse.data.value;
    
    if (companies.length === 0) {
      res.status(400).send('No Business Central companies found in your tenant.');
      return;
    }

    // Use first company (or implement company selection UI)
    const bcCompany = companies[0];
    
    console.log('BC companies discovered:', companies.length, 'Selected:', bcCompany.displayName);

    // Save refresh token securely
    const tokenSecretId = await tokenVault.saveRefreshToken(state.companyId, refresh_token);

    // Save integration configuration
    await saveBcIntegration(state.companyId, {
      tenantId,
      environment: 'Sandbox', // TODO: Allow user to select Production/Sandbox
      companyId: bcCompany.id,
      companyName: bcCompany.displayName,
      connectedAt: admin.firestore.Timestamp.now(),
      connectedBy: userId,
      status: 'connected',
      tokenSecretId,
    });

    console.log('BC integration saved successfully');

    // Success response
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
            : '<p>You can close this window now.</p>'
          }
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
  } catch (error) {
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
          <div class="error-message">${(error as Error).message}</div>
          <p style="margin-top: 20px;">Please try again or contact support if the problem persists.</p>
        </div>
      </body>
      </html>
    `;

    res.status(500).send(errorHtml);
  }
});
