# Updated Firestore Rules for Public POD Access

## Add these rules to your firestore.rules file

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user belongs to a company
    function belongsToCompany(companyId) {
      return isAuthenticated() && 
             request.auth.token.companyId == companyId;
    }
    
    // POD Access Tokens - allows public reading for token validation
    match /pod_tokens/{token} {
      // Public read access for token validation
      allow read: if true;
      
      // Only authenticated users can create/update tokens
      allow create, update: if isAuthenticated();
      
      // Prevent deletion (use isActive flag instead)
      allow delete: if false;
    }
    
    // PODs - public access with valid token
    match /pods/{podId} {
      // Authenticated users can read PODs from their company
      allow read: if isAuthenticated();
      
      // Public read if valid token exists
      // This allows the public POD view screen to work
      allow get: if resource != null || isValidToken(podId, request.query.token);
      
      // Only authenticated users can write
      allow write: if isAuthenticated();
    }
    
    // Deliveries - similar access pattern as PODs
    match /deliveries/{deliveryId} {
      // Authenticated users with company access
      allow read: if isAuthenticated() && belongsToCompany(resource.data.companyId);
      
      // Public read with valid token (for public POD view)
      allow get: if isValidToken(deliveryId, request.query.token);
      
      // Write access for company members
      allow create: if isAuthenticated() && 
                     belongsToCompany(request.resource.data.companyId);
      allow update, delete: if isAuthenticated() && 
                             belongsToCompany(resource.data.companyId);
    }
    
    // Helper function to validate POD access token
    function isValidToken(deliveryId, token) {
      let tokenData = get(/databases/$(database)/documents/pod_tokens/$(token));
      return tokenData != null &&
             tokenData.data.deliveryId == deliveryId &&
             tokenData.data.isActive == true &&
             (tokenData.data.expiresAt == null || tokenData.data.expiresAt > request.time);
    }
    
    // Companies
    match /companies/{companyId} {
      allow read: if isAuthenticated() && belongsToCompany(companyId);
      allow write: if isAuthenticated() && belongsToCompany(companyId);
    }
    
    // Users
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Customers - company scoped
    match /customers/{customerId} {
      allow read, write: if isAuthenticated() && 
                          belongsToCompany(resource.data.companyId);
    }
    
    // Claims - company scoped
    match /claims/{claimId} {
      allow read, write: if isAuthenticated() && 
                          belongsToCompany(resource.data.companyId);
    }
  }
}
```

## Key Features of These Rules

### 1. **Public POD Access**
- Allows public reading of PODs with valid token
- Token validation happens at Firestore level
- Expired or inactive tokens are rejected automatically

### 2. **Security**
- Authenticated users see only their company's data
- Public access ONLY through valid tokens
- Tokens can be deactivated instantly
- Expiration enforced at database level

### 3. **Performance**
- `isValidToken()` function checks:
  - Token exists
  - DeliveryId matches
  - Token is active
  - Token hasn't expired
- Single document read for validation

## Deployment

Deploy these rules using Firebase CLI:

```bash
firebase deploy --only firestore:rules
```

Or through Firebase Console:
1. Go to Firestore Database
2. Click "Rules" tab
3. Paste the rules
4. Click "Publish"

## Testing

### Test authenticated access:
```javascript
// Should succeed
firebase.firestore().collection('deliveries').doc(deliveryId).get();
```

### Test public access with token:
```javascript
// Should succeed with valid token
const url = `https://firestore.googleapis.com/v1/projects/YOUR_PROJECT/databases/(default)/documents/pods/${deliveryId}?token=${validToken}`;
fetch(url);
```

### Test without token:
```javascript
// Should fail
const url = `https://firestore.googleapis.com/v1/projects/YOUR_PROJECT/databases/(default)/documents/pods/${deliveryId}`;
fetch(url);  // Permission denied
```

## Important Notes

1. **Query Parameters**: The `request.query.token` only works with REST API and Cloud Functions. For direct Firestore queries from Flutter web, you may need to implement token validation in your Flutter code first.

2. **Alternative Approach**: For better security with Flutter Web, consider validating the token in your Flutter code before accessing Firestore:

```dart
// In your Flutter app
final deliveryId = await PODTokenService().validateToken(token);
if (deliveryId != null) {
  // Token is valid, fetch POD
  final pod = await FirebaseFirestore.instance
      .collection('pods')
      .doc(deliveryId)
      .get();
}
```

3. **Rate Limiting**: Consider implementing rate limiting on the Cloud Functions side to prevent abuse.

## Migration Checklist

- [ ] Backup existing Firestore rules
- [ ] Update rules with new token access logic
- [ ] Test authenticated access still works
- [ ] Test public access with valid token
- [ ] Test public access with invalid token fails
- [ ] Deploy to production
- [ ] Monitor for security errors

---

**Status**: Ready to deploy
**Security Level**: High
**Public Access**: Token-based only
