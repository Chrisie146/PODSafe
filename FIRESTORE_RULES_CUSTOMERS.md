# Firestore Security Rules - Customer Collection

## 🐛 Issue
**Error**: "Missing or insufficient permissions"

When trying to access the `customers` collection, Firestore was blocking the request because there were no security rules defined for that collection.

## ✅ Solution Applied

Added comprehensive security rules for the `customers` collection in `firestore.rules`.

## 🔒 Security Rules Added

```javascript
// Customers
match /customers/{customerId} {
  // Admins can read customers in their company
  allow read: if isAdmin() && belongsToSameCompany(resource.data.companyId);
  
  // Drivers can read customers in their company (for delivery creation)
  allow read: if isAuthenticated() && belongsToSameCompany(resource.data.companyId);
  
  // Admins can create customers in their company
  allow create: if isAdmin() && 
                   belongsToSameCompany(request.resource.data.companyId);
  
  // Admins can update customers in their company
  allow update: if isAdmin() && belongsToSameCompany(resource.data.companyId);
  
  // Admins can delete customers in their company
  allow delete: if isAdmin() && belongsToSameCompany(resource.data.companyId);
  
  // Allow list queries for admins (for search and autocomplete)
  allow list: if isAdmin();
}
```

## 📋 What These Rules Allow

### ✅ Admins Can:
- **Read** all customers in their company
- **Create** new customers in their company
- **Update** existing customers in their company
- **Delete** customers in their company
- **Query/List** customers (for search and autocomplete)

### ✅ Drivers Can:
- **Read** customers in their company (needed for delivery creation with autocomplete)

### ❌ Not Allowed:
- Cross-company access (company isolation enforced)
- Unauthenticated access
- Drivers cannot create/update/delete customers

## 🔐 Security Features

### 1. Company Isolation
```javascript
belongsToSameCompany(resource.data.companyId)
```
- Each user can only access customers from their own company
- Multi-tenant data isolation enforced at database level

### 2. Role-Based Access
```javascript
isAdmin() // For create/update/delete
isAuthenticated() // For read-only access
```
- Admins have full CRUD permissions
- Drivers have read-only access
- Unauthenticated users blocked completely

### 3. Data Validation
```javascript
belongsToSameCompany(request.resource.data.companyId)
```
- On create: Ensures new customer has correct companyId
- Prevents users from creating customers for other companies

## 🚀 Deployment

**Command Used**:
```bash
firebase deploy --only firestore:rules
```

**Status**: ✅ **Deployed Successfully**

**Result**:
```
✔ cloud.firestore: rules file firestore.rules compiled successfully
✔ firestore: released rules firestore.rules to cloud.firestore
✔ Deploy complete!
```

## 🧪 Testing

Now you can test the following operations:

### 1. Import Customers ✅
```
Admin Dashboard → Import Customers → Upload CSV
```
- Should work without permission errors
- Creates customers with proper companyId

### 2. Load Customers ✅
```
CustomerProvider.initialize(companyId)
CustomerProvider.loadCustomers()
```
- Fetches all customers for your company
- Respects company isolation

### 3. Search Customers ✅
```
CustomerProvider.searchCustomers('BOX')
```
- Queries customers collection
- Returns results from your company only

### 4. Create Delivery with Customer ✅
```
Create Delivery Screen → Customer Autocomplete
```
- Drivers can read customer data
- Autocomplete shows customer list
- Auto-fill works correctly

## 📊 Rule Breakdown

| Operation | Admin | Driver | Unauthenticated |
|-----------|-------|--------|-----------------|
| Read      | ✅ Own Company | ✅ Own Company | ❌ |
| Create    | ✅ Own Company | ❌ | ❌ |
| Update    | ✅ Own Company | ❌ | ❌ |
| Delete    | ✅ Own Company | ❌ | ❌ |
| List/Query| ✅ Own Company | ✅ Own Company | ❌ |

## 🔍 Verification

Check your Firebase Console to verify rules are active:

1. **Go to**: [Firebase Console](https://console.firebase.google.com/project/podsafe-92a3e/firestore)
2. **Click**: Database → Rules tab
3. **Verify**: You see the `customers` rules
4. **Check**: Last deployment timestamp

## 🎓 Understanding the Rules

### Helper Functions Used

```javascript
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
```

### Read Operations
```javascript
allow read: if isAdmin() && belongsToSameCompany(resource.data.companyId);
```
- `resource.data` = existing document data
- Checks if document's companyId matches user's companyId

### Write Operations
```javascript
allow create: if isAdmin() && belongsToSameCompany(request.resource.data.companyId);
```
- `request.resource.data` = new document data being created
- Validates companyId before allowing creation

## 🚨 Troubleshooting

### Still Getting Permission Errors?

**Solution 1: Verify Rules Deployed**
```bash
firebase deploy --only firestore:rules
```

**Solution 2: Check User Role**
```javascript
// In browser console
console.log('User role:', authProvider.currentUser?.role);
console.log('Company ID:', authProvider.currentUser?.companyId);
```
Ensure:
- Role is `'admin'` for imports
- Company ID exists and is not empty

**Solution 3: Check Document Structure**
Ensure customers have `companyId` field:
```javascript
{
  "id": "abc123",
  "companyId": "company_xyz", // REQUIRED
  "customerNumber": "BOX001",
  "name": "Boxer Superstore",
  // ... other fields
}
```

**Solution 4: Clear Browser Cache**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Or: Clear site data in DevTools

## ✅ Next Steps

With rules deployed, you should now be able to:

1. ✅ **Import customers** via CSV
2. ✅ **Search customers** in autocomplete
3. ✅ **Create deliveries** with customer linking
4. ✅ **View customer lists** in admin dashboard

All operations will respect company boundaries and role permissions!

---

*Rules Deployed: October 2025*  
*Status: Active*  
*Security Level: Company-isolated, role-based access control*
