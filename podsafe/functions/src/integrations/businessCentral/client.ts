/**
 * Business Central HTTP Client
 * Handles OAuth token management, HTTP requests with retry/backoff
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosError } from 'axios';
import * as admin from 'firebase-admin';
import { config, getTokenEndpoint, getBcApiUrl } from '../../config';
import { getBcIntegration, TokenVault } from '../../store/firestore';
import { TokenResponse, RetryableError } from '../../types';

const tokenVault = new TokenVault();

/**
 * In-memory access token cache
 * Key: companyId, Value: { token, expiresAt }
 */
const tokenCache = new Map<string, { token: string; expiresAt: number }>();

/**
 * Get valid access token for a company
 * Uses cached token if available and not expired
 * Otherwise refreshes using refresh token
 */
export async function getAccessToken(companyId: string): Promise<string> {
  // Check cache
  const cached = tokenCache.get(companyId);
  if (cached && cached.expiresAt > Date.now() + 60000) {
    // Token valid for at least 1 more minute
    return cached.token;
  }

  // Load integration config
  const integration = await getBcIntegration(companyId);
  if (!integration || !integration.tokenSecretId) {
    throw new Error(`BC integration not configured for company: ${companyId}`);
  }

  // Load refresh token
  const refreshToken = await tokenVault.loadRefreshToken(integration.tokenSecretId);
  if (!refreshToken) {
    throw new Error(`Refresh token not found for company: ${companyId}`);
  }

  // Refresh access token
  const tokenEndpoint = getTokenEndpoint(integration.tenantId);
  
  try {
    const response = await axios.post<TokenResponse>(
      tokenEndpoint,
      new URLSearchParams({
        grant_type: 'refresh_token',
        client_id: config.bcClientId,
        client_secret: config.bcClientSecret,
        refresh_token: refreshToken,
        redirect_uri: config.bcRedirectUri,
        scope: config.bcScope,
      }),
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      }
    );

    const { access_token, expires_in, refresh_token: newRefreshToken } = response.data;

    // Cache access token
    tokenCache.set(companyId, {
      token: access_token,
      expiresAt: Date.now() + expires_in * 1000,
    });

    // Rotate refresh token if provided
    if (newRefreshToken && newRefreshToken !== refreshToken) {
      const newSecretId = await tokenVault.saveRefreshToken(companyId, newRefreshToken);
      
      // Update integration with new secret ID
      await admin.firestore()
        .collection('companies')
        .doc(companyId)
        .collection('integrations')
        .doc('businessCentral')
        .update({ tokenSecretId: newSecretId });
      
      // Delete old token
      await tokenVault.deleteRefreshToken(integration.tokenSecretId);
    }

    return access_token;
  } catch (error) {
    console.error('Token refresh failed:', error);
    throw new Error(`Failed to refresh access token: ${(error as Error).message}`);
  }
}

/**
 * Create BC API client with automatic retry and backoff
 */
export function createBcClient(companyId: string): BcHttpClient {
  return new BcHttpClient(companyId);
}

/**
 * Business Central HTTP Client with retry logic
 */
export class BcHttpClient {
  private client: AxiosInstance;
  
  constructor(private companyId: string) {
    this.client = axios.create({
      timeout: 30000,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    });

    // Add retry interceptor
    this.setupRetryInterceptor();
  }

  /**
   * Setup axios interceptor for automatic retry with exponential backoff
   */
  private setupRetryInterceptor(): void {
    this.client.interceptors.response.use(
      response => response,
      async (error: AxiosError) => {
        const requestConfig = error.config as AxiosRequestConfig & { _retryCount?: number };
        
        if (!requestConfig) {
          return Promise.reject(error);
        }

        const retryCount = requestConfig._retryCount || 0;
        const maxRetries = config.maxRetries;

        // Check if error is retryable
        const isRetryable = this.isRetryableError(error);
        
        if (!isRetryable || retryCount >= maxRetries) {
          return Promise.reject(this.enhanceError(error));
        }

        // Calculate backoff delay
        const retryAfter = this.getRetryAfter(error);
        const backoffDelay = retryAfter || config.retryDelay * Math.pow(config.backoffMultiplier, retryCount);

        console.log(`Retrying request (attempt ${retryCount + 1}/${maxRetries}) after ${backoffDelay}ms`);

        // Wait before retrying
        await this.delay(backoffDelay);

        // Increment retry count
        requestConfig._retryCount = retryCount + 1;

        // Retry request
        return this.client(requestConfig);
      }
    );
  }

  /**
   * Check if error is retryable
   */
  private isRetryableError(error: AxiosError): boolean {
    if (!error.response) {
      // Network error, connection timeout, etc.
      return true;
    }

    const status = error.response.status;
    
    // Retry on 429 (rate limit), 500, 502, 503, 504
    return status === 429 || (status >= 500 && status < 600);
  }

  /**
   * Get Retry-After header value in milliseconds
   */
  private getRetryAfter(error: AxiosError): number | null {
    const retryAfter = error.response?.headers['retry-after'];
    
    if (!retryAfter) {
      return null;
    }

    // If it's a number of seconds
    const seconds = parseInt(retryAfter, 10);
    if (!isNaN(seconds)) {
      return seconds * 1000;
    }

    // If it's a date
    const date = new Date(retryAfter);
    if (!isNaN(date.getTime())) {
      return Math.max(0, date.getTime() - Date.now());
    }

    return null;
  }

  /**
   * Enhance error with retry information
   */
  private enhanceError(error: AxiosError): RetryableError {
    const enhanced = new Error(error.message) as RetryableError;
    enhanced.name = 'BcApiError';
    enhanced.statusCode = error.response?.status;
    enhanced.retryable = this.isRetryableError(error);
    enhanced.stack = error.stack;
    
    return enhanced;
  }

  /**
   * Delay helper
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * GET request to BC API
   */
  async get<T = any>(endpoint: string, params?: Record<string, any>): Promise<T> {
    const integration = await getBcIntegration(this.companyId);
    if (!integration) {
      throw new Error(`BC integration not found for company: ${this.companyId}`);
    }

    const accessToken = await getAccessToken(this.companyId);
    const baseUrl = getBcApiUrl(integration.tenantId, integration.environment);
    const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;

    const response = await this.client.get<T>(url, {
      params,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    return response.data;
  }

  /**
   * POST request to BC API
   */
  async post<T = any>(endpoint: string, data?: any): Promise<T> {
    const integration = await getBcIntegration(this.companyId);
    if (!integration) {
      throw new Error(`BC integration not found for company: ${this.companyId}`);
    }

    const accessToken = await getAccessToken(this.companyId);
    const baseUrl = getBcApiUrl(integration.tenantId, integration.environment);
    const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;

    const response = await this.client.post<T>(url, data, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
      },
    });

    return response.data;
  }

  /**
   * PATCH request to BC API
   * Includes If-Match header for optimistic concurrency
   */
  async patch<T = any>(endpoint: string, data: any, etag?: string): Promise<T> {
    const integration = await getBcIntegration(this.companyId);
    if (!integration) {
      throw new Error(`BC integration not found for company: ${this.companyId}`);
    }

    const accessToken = await getAccessToken(this.companyId);
    const baseUrl = getBcApiUrl(integration.tenantId, integration.environment);
    const url = endpoint.startsWith('http') ? endpoint : `${baseUrl}/${endpoint}`;

    try {
      const response = await this.client.patch<T>(url, data, {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          ...(etag && { 'If-Match': etag }),
        },
      });

      return response.data;
    } catch (error) {
      // Handle 412 Precondition Failed (etag mismatch)
      if (axios.isAxiosError(error) && error.response?.status === 412) {
        throw new Error('Document has been modified. Please refetch and retry.');
      }
      throw error;
    }
  }
}
