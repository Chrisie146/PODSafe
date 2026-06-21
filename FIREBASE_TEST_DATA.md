# Firebase Initial Setup Script

This guide helps you create initial test data in Firebase for the PODSafe application.

## Step 1: Create Test Users in Firebase Authentication

Go to Firebase Console → Authentication → Users → Add User

### Admin User (recommended)
- **Email**: `admin@podsafe.com`
- **Password**: `Admin123!` (change in production!)
- **User ID**: Will be auto-generated (note it down)

### Driver User (recommended)
- **Email**: `driver@podsafe.com`
- **Password**: `Driver123!` (change in production!)
- **User ID**: Will be auto-generated (note it down)

## Step 2: Create User Documents in Firestore

After creating the Firebase Auth users, go to Firestore Database → Start Collection

### Create "users" Collection

#### Admin User Document:
- **Document ID**: `<Admin User UID from Step 1>`
- **Fields**:
  ```
  companyId: "company-001" (string)
  createdAt: <timestamp> (timestamp)
  email: "admin@podsafe.com" (string)
  fullName: "Admin User" (string)
  isActive: true (boolean)
  lastLoginAt: <timestamp> (timestamp)
  phoneNumber: "+1234567890" (string, optional)
  role: "admin" (string)
  ```

#### Driver User Document:
- **Document ID**: `<Driver User UID from Step 1>`
- **Fields**:
  ```
  companyId: "company-001" (string)
  createdAt: <timestamp> (timestamp)
  email: "driver@podsafe.com" (string)
  fullName: "Test Driver" (string)
  isActive: true (boolean)
  lastLoginAt: <timestamp> (timestamp)
  phoneNumber: "+1234567891" (string, optional)
  role: "driver" (string)
  ```

## Step 3: Create a Test Company

### Create "companies" Collection

#### Company Document:
- **Document ID**: `company-001`
- **Fields**:
  ```
  name: "Test Company" (string)
  address: "123 Main St, City, State 12345" (string)
  contactEmail: "contact@testcompany.com" (string)
  contactPhone: "+1234567890" (string)
  createdAt: <timestamp> (timestamp)
  isActive: true (boolean)
  subscriptionPlan: "premium" (string)
  subscriptionExpiresAt: <future timestamp> (timestamp)
  ```

## Step 4: Create Test Delivery (Optional)

### Create "deliveries" Collection

#### Test Delivery Document:
- **Document ID**: Auto-generated
- **Fields**:
  ```
  companyId: "company-001" (string)
  assignedDriverId: <Driver User UID> (string)
  customerName: "John Doe" (string)
  customerPhone: "+1234567892" (string)
  deliveryAddress: "456 Oak Ave, City, State 12345" (string)
  pickupAddress: "789 Pine Rd, City, State 12345" (string)
  status: "assigned" (string)
  priority: "normal" (string)
  scheduledPickupTime: <timestamp> (timestamp)
  scheduledDeliveryTime: <timestamp> (timestamp)
  items: [
    {
      name: "Package 1" (string)
      quantity: 1 (number)
      weight: 5.5 (number)
      description: "Test package" (string)
    }
  ] (array)
  specialInstructions: "Handle with care" (string)
  createdAt: <timestamp> (timestamp)
  updatedAt: <timestamp> (timestamp)
  ```

## Quick Test User Creation (Alternative)

If you prefer to let the app create user documents automatically:

1. **Create only Firebase Auth users** (Step 1 above)
2. **Sign in to the app** - it will automatically create a basic user document
3. **Manually update the user document** in Firestore to set correct role and companyId

## Testing Login

After setup, you can test with:

**Admin Login:**
- Email: `admin@podsafe.com`
- Password: `Admin123!`

**Driver Login:**
- Email: `driver@podsafe.com`
- Password: `Driver123!`

## Security Notes

⚠️ **Important for Production:**
- Change all default passwords
- Use strong, unique passwords
- Enable 2FA for admin accounts
- Regularly rotate credentials
- Monitor authentication logs

## Troubleshooting

### "No document to update" Error
- The Firebase Auth user exists but Firestore document doesn't
- The app now auto-creates basic user documents on first login
- Manually update the role and companyId fields in Firestore after first login

### "Permission Denied" Errors
- Ensure security rules are deployed (see FIREBASE_SETUP.md)
- Check that user has correct role in Firestore
- Verify companyId matches between user and data

### Can't Create Deliveries
- Ensure you're logged in as admin
- Check that company document exists
- Verify driver user has correct role

## Next Steps

After creating test data:

1. ✅ Test login with both admin and driver accounts
2. ✅ Create a test delivery as admin
3. ✅ View deliveries as driver
4. ✅ Test POD capture with photo and signature
5. ✅ Verify offline functionality
6. ✅ Check data appears correctly in Firestore and Storage

---

For automated user creation via API or bulk import, consider using Firebase Admin SDK or Cloud Functions.
