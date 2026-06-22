import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { createBcClient, getAccessToken } from '../integrations/businessCentral/client';

type BcMethod = 'GET' | 'POST' | 'PATCH';

async function requireCompanyAdmin(context: functions.https.CallableContext, companyId: unknown): Promise<string> {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated.');
  }
  if (typeof companyId !== 'string' || !companyId) {
    throw new functions.https.HttpsError('invalid-argument', 'companyId is required.');
  }

  const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  const user = userDoc.data();
  if (!userDoc.exists || !user || user.isActive !== true || user.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only active administrators can use Business Central integration.');
  }
  if (user.companyId !== companyId) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot access another company.');
  }
  return companyId;
}

function validateEndpoint(endpoint: unknown): asserts endpoint is string {
  if (typeof endpoint !== 'string' || !endpoint.startsWith('companies(') || endpoint.includes('://') || endpoint.includes('..') || endpoint.includes('\\')) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid Business Central API endpoint.');
  }
}

export const bcAuthenticate = functions.https.onCall(async (data, context) => {
  const companyId = await requireCompanyAdmin(context, data?.companyId);
  const accessToken = await getAccessToken(companyId);
  return { accessToken, expiresIn: 3000 };
});

export const bcApiCall = functions.https.onCall(async (data, context) => {
  const companyId = await requireCompanyAdmin(context, data?.companyId);
  const method = data?.method as BcMethod;
  validateEndpoint(data?.endpoint);
  if (!['GET', 'POST', 'PATCH'].includes(method)) {
    throw new functions.https.HttpsError('invalid-argument', 'method must be GET, POST, or PATCH.');
  }
  if ((method === 'POST' || method === 'PATCH') && (data.body == null || typeof data.body !== 'object' || Array.isArray(data.body))) {
    throw new functions.https.HttpsError('invalid-argument', 'body must be an object for POST and PATCH requests.');
  }

  const client = createBcClient(companyId);
  switch (method) {
    case 'GET': return client.get(data.endpoint);
    case 'POST': return client.post(data.endpoint, data.body);
    case 'PATCH': return client.patch(data.endpoint, data.body, typeof data.etag === 'string' ? data.etag : undefined);
  }
});

export const bcTestConnection = functions.https.onCall(async (data, context) => {
  const companyId = await requireCompanyAdmin(context, data?.companyId);
  try {
    const response = await createBcClient(companyId).get<{ value?: unknown[] }>('companies');
    return { success: true, message: 'Connected to Business Central.', companiesCount: response.value?.length ?? 0 };
  } catch (error) {
    console.error('BC connection test failed:', error);
    throw new functions.https.HttpsError('unavailable', 'Could not connect to Business Central.');
  }
});
