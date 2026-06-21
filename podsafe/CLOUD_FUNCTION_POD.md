# Cloud Function for Public POD Access

## Optional: Cloud Function for Enhanced Security

While the Firestore rules provide direct access, you can optionally create a Cloud Function for additional control, logging, and rate limiting.

## Setup

### 1. Initialize Cloud Functions

```bash
cd your-project-directory
firebase init functions
# Choose TypeScript or JavaScript
cd functions
npm install
```

### 2. Create the Function

Create `functions/src/index.ts` (TypeScript) or `functions/index.js` (JavaScript):

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as cors from 'cors';

admin.initializeApp();

const corsHandler = cors({ origin: true });

/**
 * Public POD Access Function
 * GET /publicPOD?deliveryId=xxx&token=yyy
 */
export const publicPOD = functions.https.onRequest((request, response) => {
  corsHandler(request, response, async () => {
    try {
      // Only allow GET requests
      if (request.method !== 'GET') {
        response.status(405).json({ error: 'Method not allowed' });
        return;
      }

      const deliveryId = request.query.deliveryId as string;
      const token = request.query.token as string;

      // Validate parameters
      if (!deliveryId || !token) {
        response.status(400).json({ 
          error: 'Missing required parameters: deliveryId and token' 
        });
        return;
      }

      // Validate token
      const tokenDoc = await admin.firestore()
        .collection('pod_tokens')
        .doc(token)
        .get();

      if (!tokenDoc.exists) {
        response.status(404).json({ error: 'Invalid token' });
        return;
      }

      const tokenData = tokenDoc.data()!;

      // Check token validity
      if (tokenData.deliveryId !== deliveryId) {
        response.status(403).json({ error: 'Token does not match delivery' });
        return;
      }

      if (!tokenData.isActive) {
        response.status(403).json({ error: 'Token has been deactivated' });
        return;
      }

      if (tokenData.expiresAt && tokenData.expiresAt.toDate() < new Date()) {
        response.status(403).json({ error: 'Token has expired' });
        return;
      }

      // Fetch POD data
      const podDoc = await admin.firestore()
        .collection('pods')
        .doc(deliveryId)
        .get();

      if (!podDoc.exists) {
        response.status(404).json({ error: 'POD not found' });
        return;
      }

      // Fetch delivery data
      const deliveryDoc = await admin.firestore()
        .collection('deliveries')
        .doc(deliveryId)
        .get();

      // Increment access count
      await admin.firestore()
        .collection('pod_tokens')
        .doc(token)
        .update({
          accessCount: admin.firestore.FieldValue.increment(1),
          lastAccessedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Log access
      console.log(`Public POD accessed: ${deliveryId} with token ${token}`);

      // Return POD data
      response.status(200).json({
        success: true,
        pod: podDoc.data(),
        delivery: deliveryDoc.exists ? deliveryDoc.data() : null,
        deliveryId: deliveryId,
      });

    } catch (error) {
      console.error('Error in publicPOD function:', error);
      response.status(500).json({ 
        error: 'Internal server error',
        message: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  });
});

/**
 * Generate POD Token Function
 * POST /generatePODToken
 * Body: { deliveryId: string, expiryDays?: number }
 * Requires authentication
 */
export const generatePODToken = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to generate tokens'
    );
  }

  const deliveryId = data.deliveryId;
  const expiryDays = data.expiryDays || 90;

  if (!deliveryId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'deliveryId is required'
    );
  }

  // Check if delivery exists and user has access
  const deliveryDoc = await admin.firestore()
    .collection('deliveries')
    .doc(deliveryId)
    .get();

  if (!deliveryDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Delivery not found'
    );
  }

  // Check if token already exists
  const existingTokens = await admin.firestore()
    .collection('pod_tokens')
    .where('deliveryId', '==', deliveryId)
    .where('isActive', '==', true)
    .limit(1)
    .get();

  if (!existingTokens.empty) {
    const existingToken = existingTokens.docs[0].data();
    return {
      token: existingTokens.docs[0].id,
      deliveryId: deliveryId,
      publicUrl: `https://podsafe.app/pod/${deliveryId}?token=${existingTokens.docs[0].id}`,
      expiresAt: existingToken.expiresAt?.toDate().toISOString(),
    };
  }

  // Generate new token
  const crypto = require('crypto');
  const token = crypto.randomBytes(16).toString('hex');

  const createdAt = new Date();
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + expiryDays);

  // Save token
  await admin.firestore()
    .collection('pod_tokens')
    .doc(token)
    .set({
      deliveryId: deliveryId,
      token: token,
      createdAt: admin.firestore.Timestamp.fromDate(createdAt),
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      isActive: true,
      accessCount: 0,
    });

  return {
    token: token,
    deliveryId: deliveryId,
    publicUrl: `https://podsafe.app/pod/${deliveryId}?token=${token}`,
    expiresAt: expiresAt.toISOString(),
  };
});

/**
 * Deactivate POD Token Function
 * POST /deactivatePODToken
 * Body: { token: string }
 * Requires authentication
 */
export const deactivatePODToken = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be authenticated to deactivate tokens'
    );
  }

  const token = data.token;

  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'token is required'
    );
  }

  await admin.firestore()
    .collection('pod_tokens')
    .doc(token)
    .update({
      isActive: false,
      deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deactivatedBy: context.auth.uid,
    });

  return { success: true };
});

/**
 * Cleanup Expired Tokens (Scheduled)
 * Runs daily to deactivate expired tokens
 */
export const cleanupExpiredTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const now = new Date();
    
    const expiredTokens = await admin.firestore()
      .collection('pod_tokens')
      .where('isActive', '==', true)
      .where('expiresAt', '<=', admin.firestore.Timestamp.fromDate(now))
      .get();

    const batch = admin.firestore().batch();
    let count = 0;

    expiredTokens.forEach((doc) => {
      batch.update(doc.ref, {
        isActive: false,
        deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      count++;
    });

    await batch.commit();

    console.log(`Deactivated ${count} expired tokens`);
    return null;
  });
```

### 3. Deploy Functions

```bash
cd functions
npm run build  # If using TypeScript
cd ..
firebase deploy --only functions
```

## Usage from Flutter

### Use Cloud Function Instead of Direct Firestore Access

```dart
import 'package:cloud_functions/cloud_functions.dart';

class CloudPODService {
  final functions = FirebaseFunctions.instance;

  /// Fetch public POD using Cloud Function
  Future<Map<String, dynamic>?> getPublicPOD(
    String deliveryId,
    String token,
  ) async {
    try {
      final response = await functions
          .httpsCallable('publicPOD')
          .call({
        'deliveryId': deliveryId,
        'token': token,
      });

      if (response.data['success'] == true) {
        return {
          'pod': response.data['pod'],
          'delivery': response.data['delivery'],
        };
      }

      return null;
    } catch (e) {
      print('Error fetching public POD: $e');
      return null;
    }
  }

  /// Generate token using Cloud Function
  Future<String?> generateToken(String deliveryId) async {
    try {
      final response = await functions
          .httpsCallable('generatePODToken')
          .call({'deliveryId': deliveryId});

      return response.data['token'];
    } catch (e) {
      print('Error generating token: $e');
      return null;
    }
  }
}
```

## Benefits of Cloud Function Approach

### Advantages
1. **Enhanced Security**: Server-side validation
2. **Rate Limiting**: Can implement rate limiting
3. **Logging**: Centralized access logging
4. **Flexibility**: Easy to add features like:
   - Email notifications on access
   - Analytics tracking
   - Custom validation logic
   - Watermarking
   - PDF generation

### Disadvantages
1. **Complexity**: More code to maintain
2. **Cost**: Function invocations cost money
3. **Latency**: Additional network hop
4. **Cold Starts**: First invocation may be slow

## Recommendation

**For MVP**: Use direct Firestore access with security rules (simpler, faster, cheaper)

**For Production**: Consider Cloud Functions if you need:
- Advanced logging
- Rate limiting
- Email notifications
- Analytics
- PDF generation
- Custom business logic

## Cost Estimate

- **Firestore Direct**: ~$0.03 per 100,000 reads
- **Cloud Functions**: ~$0.40 per 1 million invocations + Firestore reads

For most use cases, the cost difference is negligible.

---

**Status**: Optional enhancement
**Priority**: Low (MVP can use direct access)
**Complexity**: Medium
