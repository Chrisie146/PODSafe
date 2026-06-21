# Multi-Company Onboarding System - Complete Design

## Overview
Professional onboarding flow where companies register, admins manage, and drivers self-register.

---

## Data Structure

### Companies Collection
```javascript
companies/{companyId} {
  id: string (auto-generated)
  name: string
  email: string (contact email)
  phone: string
  address: string
  createdAt: timestamp
  plan: string ('free', 'basic', 'premium')
  isActive: boolean
  settings: {
    autoApproveDrivers: boolean (default: false)
    requireDriverApproval: boolean (default: true)
  }
}
```

### Users Collection
```javascript
users/{userId} {
  id: string (Firebase UID)
  email: string
  displayName: string
  phoneNumber: string
  role: string ('admin', 'driver', 'dispatcher')
  companyId: string (reference to company)
  isActive: boolean
  
  // Driver-specific fields
  licenseNumber?: string
  vehicleInfo?: string
  approvalStatus?: string ('pending', 'approved', 'rejected')
  approvedBy?: string (admin UID)
  approvedAt?: timestamp
  
  // Timestamps
  createdAt: timestamp
  updatedAt: timestamp
  lastLoginAt: timestamp
}
```

### Deliveries Collection (Updated)
```javascript
deliveries/{deliveryId} {
  // ... existing fields ...
  companyId: string (isolate data by company)
  createdBy: string (admin UID)
  assignedTo: string (driver UID)
}
```

---

## User Flows

### Flow 1: Company Registration

**Screen: `company_registration_screen.dart`**

```
┌─────────────────────────────┐
│   Create Your Company       │
├─────────────────────────────┤
│ Company Name: [_________]   │
│ Email: [_________]          │
│ Phone: [_________]          │
│ Address: [_________]        │
│                             │
│ Admin Account:              │
│ Your Name: [_________]      │
│ Email: [_________]          │
│ Password: [_________]       │
│                             │
│ [Create Company & Sign Up]  │
└─────────────────────────────┘
```

**Process:**
1. User fills company info
2. Creates their admin account
3. Firebase Auth: Creates user
4. Firestore: Creates company document
5. Firestore: Creates user document with role='admin'
6. User logged in as admin
7. Redirected to admin dashboard

**Implementation:**
```dart
Future<void> registerCompany({
  required String companyName,
  required String companyEmail,
  required String companyPhone,
  required String companyAddress,
  required String adminName,
  required String adminEmail,
  required String adminPassword,
}) async {
  // 1. Create admin Firebase Auth account
  final userCredential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(
    email: adminEmail,
    password: adminPassword,
  );
  
  final adminUid = userCredential.user!.uid;
  
  // 2. Create company document
  final companyRef = await FirebaseFirestore.instance
      .collection('companies')
      .add({
    'name': companyName,
    'email': companyEmail,
    'phone': companyPhone,
    'address': companyAddress,
    'createdAt': FieldValue.serverTimestamp(),
    'plan': 'free',
    'isActive': true,
    'settings': {
      'autoApproveDrivers': false,
      'requireDriverApproval': true,
    },
  });
  
  final companyId = companyRef.id;
  
  // 3. Create admin user document
  await FirebaseFirestore.instance
      .collection('users')
      .doc(adminUid)
      .set({
    'id': adminUid,
    'email': adminEmail,
    'displayName': adminName,
    'role': 'admin',
    'companyId': companyId,
    'isActive': true,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  // User is now logged in as admin!
}
```

---

### Flow 2: Driver Self-Registration

**Screen: `driver_registration_screen.dart`**

```
┌─────────────────────────────┐
│   Driver Registration       │
├─────────────────────────────┤
│ Full Name: [_________]      │
│ Email: [_________]          │
│ Phone: [_________]          │
│ Password: [_________]       │
│                             │
│ Company Code: [_________]   │
│ (Get from your manager)     │
│                             │
│ License #: [_________]      │
│ Vehicle: [_________]        │
│                             │
│ [Register as Driver]        │
└─────────────────────────────┘
```

**How Driver Gets Company Code:**
- Admin dashboard shows company ID
- Admin shares code with drivers (email, text, etc.)
- OR: QR code that drivers can scan

**Process:**
1. Driver fills form
2. Enters company code (company ID)
3. Firebase Auth: Creates driver account
4. Firestore: Creates user document with role='driver'
5. Status: 'pending' (if approval required)
6. Admin sees new driver in "Pending Drivers" list
7. Admin approves → driver can receive deliveries

**Implementation:**
```dart
Future<void> registerDriver({
  required String fullName,
  required String email,
  required String phoneNumber,
  required String password,
  required String companyCode,
  String? licenseNumber,
  String? vehicleInfo,
}) async {
  // 1. Verify company exists
  final companyDoc = await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyCode)
      .get();
  
  if (!companyDoc.exists) {
    throw Exception('Invalid company code');
  }
  
  final companyData = companyDoc.data()!;
  if (companyData['isActive'] != true) {
    throw Exception('Company is not active');
  }
  
  // 2. Create driver Firebase Auth account
  final userCredential = await FirebaseAuth.instance
      .createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  
  final driverUid = userCredential.user!.uid;
  
  // 3. Determine approval status
  final requiresApproval = companyData['settings']?['requireDriverApproval'] ?? true;
  final approvalStatus = requiresApproval ? 'pending' : 'approved';
  
  // 4. Create driver user document
  await FirebaseFirestore.instance
      .collection('users')
      .doc(driverUid)
      .set({
    'id': driverUid,
    'email': email,
    'displayName': fullName,
    'phoneNumber': phoneNumber,
    'role': 'driver',
    'companyId': companyCode,
    'licenseNumber': licenseNumber,
    'vehicleInfo': vehicleInfo,
    'approvalStatus': approvalStatus,
    'isActive': approvalStatus == 'approved',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  // Driver now logged in!
  // If pending, show "Waiting for approval" screen
  // If approved, show driver dashboard
}
```

---

### Flow 3: Admin Sees & Approves Drivers

**Screen Updates in `driver_management_screen.dart`**

Add three tabs:
- **Approved** (existing active drivers)
- **Pending** (awaiting approval)
- **Rejected** (denied drivers)

**Query for Admin's Company Drivers:**
```dart
Stream<QuerySnapshot> getCompanyDrivers(String companyId, String status) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'driver')
      .where('companyId', isEqualTo: companyId)
      .where('approvalStatus', isEqualTo: status)
      .snapshots();
}
```

**Approve Driver:**
```dart
Future<void> approveDriver(String driverId, String adminUid) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(driverId)
      .update({
    'approvalStatus': 'approved',
    'isActive': true,
    'approvedBy': adminUid,
    'approvedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

---

## Firestore Security Rules (Updated)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isAdmin() {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
    
    function belongsToSameCompany(companyId) {
      return isAuthenticated() && 
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId;
    }
    
    // Companies
    match /companies/{companyId} {
      // Anyone can create (registration)
      allow create: if true;
      // Users can read their own company
      allow read: if belongsToSameCompany(companyId);
      // Only admins can update
      allow update: if isAdmin() && belongsToSameCompany(companyId);
    }
    
    // Users
    match /users/{userId} {
      // Users can read their own document
      allow read: if request.auth.uid == userId;
      // Anyone can create (registration)
      allow create: if true;
      // Users can update their own document
      allow update: if request.auth.uid == userId;
      // Admins can read users in their company
      allow read: if isAdmin() && 
                     belongsToSameCompany(resource.data.companyId);
      // Admins can update users in their company (approve drivers)
      allow update: if isAdmin() && 
                       belongsToSameCompany(resource.data.companyId);
    }
    
    // Deliveries
    match /deliveries/{deliveryId} {
      // Users can read deliveries in their company
      allow read: if belongsToSameCompany(resource.data.companyId);
      // Admins can create/update deliveries
      allow create, update: if isAdmin();
      // Drivers can update their assigned deliveries
      allow update: if resource.data.assignedTo == request.auth.uid;
    }
    
    // PODs
    match /pods/{podId} {
      allow read, write: if isAuthenticated();
    }
  }
}
```

---

## Admin Dashboard Updates

### Show Company Info
```dart
// In admin dashboard app bar
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('companies')
      .doc(currentUser.companyId)
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return SizedBox();
    
    final company = snapshot.data!.data() as Map<String, dynamic>;
    
    return Text(company['name']); // Show company name
  },
)
```

### Show Company Code (for sharing with drivers)
```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Company Code'),
        SelectableText(
          currentUser.companyId,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        TextButton.icon(
          icon: Icon(Icons.copy),
          label: Text('Copy Code'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: currentUser.companyId));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Company code copied!')),
            );
          },
        ),
        Text(
          'Share this code with your drivers',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
  ),
)
```

---

## Login Flow Updates

### Unified Login Screen
```dart
// login_screen.dart

// After successful login, check role
final userData = await FirebaseFirestore.instance
    .collection('users')
    .doc(userCredential.user!.uid)
    .get();

final role = userData.data()?['role'];
final approvalStatus = userData.data()?['approvalStatus'];

if (role == 'admin') {
  // Navigate to admin dashboard
  Navigator.pushReplacement(context, AdminDashboard());
  
} else if (role == 'driver') {
  if (approvalStatus == 'pending') {
    // Show pending approval screen
    Navigator.pushReplacement(context, PendingApprovalScreen());
  } else if (approvalStatus == 'approved') {
    // Navigate to driver dashboard
    Navigator.pushReplacement(context, DriverDashboard());
  } else {
    // Show rejected screen
    showDialog(...);
  }
}
```

---

## Benefits of This Approach

✅ **Scalable**: Multi-company from day 1
✅ **No Admin Logout**: Drivers register themselves
✅ **Data Isolation**: Each company sees only their data
✅ **Professional**: How real SaaS apps work
✅ **Driver Control**: Drivers own their accounts
✅ **Approval Workflow**: Admin controls who can receive deliveries
✅ **Easy Onboarding**: Drivers just need company code
✅ **Real Production**: This is the industry standard

---

## Implementation Order

### Phase 1: Core Registration (2-3 hours)
1. Create company registration screen
2. Create driver registration screen
3. Update login to route by role
4. Test: Register company → Register driver → Both login

### Phase 2: Admin Updates (1-2 hours)
1. Show company info in admin dashboard
2. Show company code for sharing
3. Add "Pending Drivers" tab
4. Add approve/reject actions
5. Filter all queries by companyId

### Phase 3: Driver Experience (1 hour)
1. Add "Pending Approval" screen for drivers
2. Update driver dashboard to check approval status
3. Test full flow

### Total Time: ~4-6 hours for complete implementation

---

## Migration for Existing Data

If you have existing test data:

```dart
// Run once to migrate
Future<void> migrateExistingData() async {
  // 1. Create default company
  final companyRef = await FirebaseFirestore.instance
      .collection('companies')
      .add({
    'name': 'Default Company',
    'email': 'admin@podsafe.com',
    'phone': '+1234567890',
    'address': 'Test Address',
    'createdAt': FieldValue.serverTimestamp(),
    'plan': 'free',
    'isActive': true,
  });
  
  final companyId = companyRef.id;
  
  // 2. Update all existing users
  final usersSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .get();
  
  for (var doc in usersSnapshot.docs) {
    await doc.reference.update({
      'companyId': companyId,
      'approvalStatus': 'approved',
    });
  }
  
  // 3. Update all existing deliveries
  final deliveriesSnapshot = await FirebaseFirestore.instance
      .collection('deliveries')
      .get();
  
  for (var doc in deliveriesSnapshot.docs) {
    await doc.reference.update({
      'companyId': companyId,
    });
  }
}
```

---

## Want me to implement this?

I can create all the screens and update the existing code. This is a much better solution than the logout workaround!

Say the word and I'll start building it. 🚀
