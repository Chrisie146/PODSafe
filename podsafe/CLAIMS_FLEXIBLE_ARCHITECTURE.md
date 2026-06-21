# Flexible Claims System - Hybrid Architecture

## 🎯 Design Philosophy

**Build a configurable claims system that adapts to different business needs without custom code.**

### Core Principles:
1. **80/20 Rule**: Handle 80% of use cases out-of-the-box
2. **Configuration over Code**: Customize via settings, not code changes
3. **Extension Points**: Allow companies to add custom fields/workflows
4. **Backward Compatible**: Simple by default, complex when needed

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    FLEXIBLE CLAIMS SYSTEM                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐      ┌──────────────────────────┐    │
│  │ Core Claim Model│──────│ Company Claim Settings   │    │
│  │  (Universal)    │      │  (Per-company config)    │    │
│  └─────────────────┘      └──────────────────────────┘    │
│         │                            │                     │
│         │                            │                     │
│  ┌──────▼───────────────────────────▼─────────────┐       │
│  │         Configurable Components                 │       │
│  ├─────────────────────────────────────────────────┤       │
│  │  • Claim Types      (enable/disable)            │       │
│  │  • Approval Workflows (simple/standard/custom)  │       │
│  │  • Evidence Requirements (photos/signatures)    │       │
│  │  • Custom Fields   (per claim type)             │       │
│  │  • SLAs & Rules    (per company)                │       │
│  │  • Notifications   (push/email/SMS)             │       │
│  │  • Integrations    (ERP/Accounting)             │       │
│  └─────────────────────────────────────────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 Claim Types - Comprehensive Coverage

### Out-of-the-Box Claim Types:

```dart
enum ClaimType {
  // Quantity Issues
  damaged,          // Damaged goods
  shortage,         // Short delivered (quantity)
  shortWeight,      // Weight discrepancy
  missing,          // Missing items
  
  // Product Issues
  wrongItems,       // Wrong products delivered
  qualityIssue,     // Product quality problem
  expiryIssue,      // Expiry date problem
  packagingIssue,   // Packaging damaged/incorrect
  temperatureIssue, // Cold chain breach
  
  // Service Issues
  returns,          // Customer returns stock
  lateDelivery,     // Delivery was late
  didNotDeliver,    // Driver couldn't complete delivery
  serviceIssue,     // Service quality issue
  
  // Financial
  priceError,       // Pricing discrepancies
  
  // Catch-all
  other,            // Custom/other
}
```

**Companies enable only what they need:**
- Basic butchery: `damaged`, `shortage`, `returns`, `other`
- Cold chain logistics: + `temperatureIssue`, `expiryIssue`
- Wholesale food: + `shortWeight`, `qualityIssue`
- Retail delivery: + `lateDelivery`, `wrongItems`

---

## 🔄 Workflow Presets

### 1. Simple Workflow (Small Businesses)
```
Driver → Admin → Done
└─ Perfect for: Small teams, trust-based operations
```

**Use Case**: 5-10 deliveries/day, owner-operated
- Driver files claim
- Owner/Admin reviews and approves
- Done

### 2. Standard Workflow (Medium Businesses)
```
Driver → Manager → Admin → Done
└─ Perfect for: Growing companies, basic oversight
```

**Use Case**: 20-50 deliveries/day, multiple drivers
- Driver files claim
- Manager investigates and recommends
- Admin makes final decision
- Done

### 3. Enterprise Workflow (Large Operations)
```
Driver → Manager → Approver → Processor → Reviewer → Done
└─ Perfect for: Your wholesale client example
```

**Use Case**: 100+ deliveries/day, strict controls
- Driver files claim
- Manager investigates (Andrea/Conrad)
- Approver signs off (Warrick/Dillion)
- Processor creates credit note (Zizi)
- Reviewer audits (Jack)
- Done

### 4. Custom Workflow
```
Build your own workflow with any combination of roles
```

**Example Custom Workflows:**
- High-value claims (>R10,000): Extra approval level
- Temperature issues: Quality assurance must review
- Price claims: Finance department involved
- Returns: Warehouse manager must verify

---

## ⚙️ Company Configuration

### Each Company Can Configure:

#### 1. **Enabled Claim Types**
```dart
enabledClaimTypes: [
  ClaimType.damaged,
  ClaimType.shortage,
  ClaimType.shortWeight,
  ClaimType.returns,
]
// Only these 4 types show in driver's app
```

#### 2. **Photo Requirements**
```dart
minPhotosRequired: 2,          // Minimum 2 photos
maxPhotosAllowed: 10,          // Maximum 10 photos
photosMandatory: true,         // Photos required
requirePhotoForImmediate: true,  // At delivery site
requirePhotoForDelayed: false,   // Filed later
```

#### 3. **Signature Requirements**
```dart
requireCustomerSignature: true,  // Customer must sign
requireDriverSignature: false,   // Driver signature optional
```

#### 4. **Time Limits**
```dart
claimFilingDeadlineDays: 7,  // Must file within 7 days
// OR null for unlimited
```

#### 5. **SLA Settings**
```dart
defaultSlaHours: 24,  // Default: 24 hours per approval level
// Can override per role:
// Manager: 24 hours
// Approver: 12 hours
// Processor: 48 hours
```

#### 6. **Auto-Approval Rules**
```dart
enableAutoApproval: true,
autoApproveUnderAmount: 500.00,  // Auto-approve claims < R500
autoApproveTypes: [
  ClaimType.lateDelivery,  // Always auto-approve late delivery
]
```

#### 7. **Notification Channels**
```dart
enablePushNotifications: true,   // In-app notifications
enableEmailNotifications: true,  // Email alerts
enableSMSNotifications: false,   // SMS (premium feature)
```

#### 8. **Fraud Detection**
```dart
enableFraudDetection: true,
fraudThresholdAmount: 5000.00,      // Flag claims > R5000
fraudThresholdFrequency: 10,        // Flag if >10 claims/month
```

#### 9. **Pattern Detection**
```dart
enablePatternDetection: true,
recurringClaimThreshold: 3,  // Same issue 3x = pattern
// Auto-flags recurring issues for investigation
```

---

## 📝 Custom Fields Per Claim Type

### Example: Short Weight Claims (Your Client)

```dart
customFieldsByType: {
  ClaimType.shortWeight: [
    CustomFieldDefinition(
      id: 'scaleTestPassed',
      label: 'Scale Test (20kg blocks)',
      type: CustomFieldType.checkbox,
      required: true,
      helpText: 'Did the scale pass the 20kg test?',
    ),
    CustomFieldDefinition(
      id: 'scaleTestPhoto',
      label: 'Scale Test Photo',
      type: CustomFieldType.photo,
      required: true,
    ),
    CustomFieldDefinition(
      id: 'expectedWeight',
      label: 'Expected Weight (kg)',
      type: CustomFieldType.number,
      required: true,
      minValue: 0,
      maxValue: 10000,
    ),
    CustomFieldDefinition(
      id: 'actualWeight',
      label: 'Actual Weight (kg)',
      type: CustomFieldType.number,
      required: true,
    ),
    CustomFieldDefinition(
      id: 'slaughterType',
      label: 'Slaughter Type',
      type: CustomFieldType.dropdown,
      dropdownOptions: ['Fresh (same day)', 'Chilled (1-3 days)', 'Frozen'],
      required: true,
    ),
    CustomFieldDefinition(
      id: 'returnSongNumber',
      label: 'Return Song Number',
      type: CustomFieldType.text,
      placeholder: 'RS-2025-XXXX',
      validationRegex: r'^RS-\d{4}-\d{4}$',
      errorMessage: 'Format: RS-YYYY-NNNN',
    ),
  ],
}
```

### Example: Temperature Issues (Cold Chain)

```dart
customFieldsByType: {
  ClaimType.temperatureIssue: [
    CustomFieldDefinition(
      id: 'tempAtDelivery',
      label: 'Temperature at Delivery (°C)',
      type: CustomFieldType.number,
      required: true,
      minValue: -30,
      maxValue: 50,
    ),
    CustomFieldDefinition(
      id: 'acceptableRange',
      label: 'Acceptable Range',
      type: CustomFieldType.text,
      placeholder: '-18°C to -15°C',
    ),
    CustomFieldDefinition(
      id: 'tempLogPhoto',
      label: 'Temperature Log Photo',
      type: CustomFieldType.photo,
      required: true,
    ),
  ],
}
```

---

## 🔐 Role-Based Workflows

### Approval Roles (Flexible Assignment)

```dart
class ApprovalRole {
  String role;          // 'manager', 'approver', 'processor', etc.
  String displayName;   // 'Wholesale Manager'
  int slaHours;         // 24
  bool canApprove;      // true
  bool canReject;       // true
  bool canRequestInfo;  // true
  bool requiresSignature; // true
  List<String>? specificUserIds; // Optional: Assign specific people
}
```

### Example: Your Client's Enterprise Workflow

```dart
customWorkflows: {
  ClaimType.shortWeight: [
    ApprovalRole(
      role: 'manager',
      displayName: 'Wholesale Manager',
      slaHours: 24,
      requiresSignature: true,
      specificUserIds: ['andrea_user_id'], // Andrea only
    ),
    ApprovalRole(
      role: 'approver',
      displayName: 'Senior Approver',
      slaHours: 12,
      requiresSignature: true,
      specificUserIds: ['warrick_user_id', 'dillion_user_id'], // Either
    ),
    ApprovalRole(
      role: 'processor',
      displayName: 'Credit Note Processor',
      slaHours: 48,
      specificUserIds: ['zizi_user_id'], // Zizi only
    ),
    ApprovalRole(
      role: 'reviewer',
      displayName: 'Final Reviewer',
      slaHours: 24,
      specificUserIds: ['jack_user_id'], // Jack only
    ),
  ],
  
  // Price claims might have different workflow
  ClaimType.priceError: [
    ApprovalRole(
      role: 'seniorManager',
      displayName: 'Senior Manager',
      specificUserIds: ['karen_user_id'], // Karen handles all price claims
    ),
    ApprovalRole(
      role: 'processor',
      displayName: 'Credit Note Processor',
      specificUserIds: ['zizi_user_id'],
    ),
  ],
}
```

---

## 🧩 Flexible Claim Model

### Universal Fields (All Claims)
```dart
class Claim {
  // Core identification
  String id, companyId, deliveryId;
  ClaimType type;
  ClaimStatus status;
  
  // Parties involved
  String customerId, customerName;
  String driverId, driverName;
  
  // Financial
  String? invoiceNumber;
  double? claimAmount;
  
  // Dates
  DateTime createdAt, deliveryDate;
  
  // Evidence
  List<String> photoUrls;
  Map<String, dynamic> gpsLocation;
  
  // Workflow
  List<ApprovalLevel> approvalChain;
  int currentApprovalLevel;
  
  // Audit trail
  List<StatusHistoryEntry> statusHistory;
  
  // ... PLUS flexible fields below
}
```

### Context-Specific Fields (Conditional)
```dart
class Claim {
  // Immediate claims (at delivery site)
  bool? customerAcknowledged;
  DateTime? filedAtDelivery;
  String? customerSignatureUrl;
  
  // Delayed claims (after delivery)
  bool? driverNotified;
  bool? driverResponded;
  String? driverResponse;
  int? daysAfterDelivery;
  
  // Investigation
  String? investigatedBy;
  String? investigationNotes;
  DateTime? investigationDate;
  
  // Resolution
  ClaimResolution? resolution;
  String? resolutionNotes;
  
  // Extensibility
  Map<String, dynamic> metadata;  // Flexible key-value storage
  List<CustomField> customFields; // Company-specific fields
}
```

---

## 🎨 UI Adaptation

### Driver's "Report Issue" Screen Adapts:

```dart
// Company A (Simple): Shows 4 claim types, 1 photo min
┌─────────────────────────────────┐
│  Report Issue                   │
├─────────────────────────────────┤
│  Type: [Damaged ▼]              │
│        • Damaged                │
│        • Shortage               │
│        • Returns                │
│        • Other                  │
│                                 │
│  📸 Photos (1 required)         │
│  [+] Add Photo                  │
│                                 │
│  Description:                   │
│  ┌───────────────────────────┐ │
│  │                           │ │
│  └───────────────────────────┘ │
│                                 │
│  [Submit]                       │
└─────────────────────────────────┘

// Company B (Your Client): Shows 10 claim types, custom fields
┌─────────────────────────────────┐
│  Report Issue                   │
├─────────────────────────────────┤
│  Type: [Short Weight ▼]         │
│        • Damaged                │
│        • Shortage               │
│        • Short Weight ✓         │
│        • Returns                │
│        • ... (10 total)         │
│                                 │
│  ☑ Scale Test Passed (20kg)    │
│                                 │
│  📸 Scale Test Photo *          │
│  [Photo] ✓                      │
│                                 │
│  Expected Weight (kg) *         │
│  [250___]                       │
│                                 │
│  Actual Weight (kg) *           │
│  [245___]                       │
│                                 │
│  Slaughter Type *               │
│  [Fresh (same day) ▼]          │
│                                 │
│  📸 Photos (2 required)         │
│  [Photo 1] ✓ [Photo 2] ✓       │
│                                 │
│  ✍️ Customer Signature *        │
│  [Signature Pad]                │
│                                 │
│  [Submit]                       │
└─────────────────────────────────┘
```

---

## 📊 Configuration Examples

### Example 1: Small Bakery (Simple)
```dart
CompanyClaimSettings(
  workflowPreset: ClaimWorkflowPreset.simple,
  enabledClaimTypes: [
    ClaimType.damaged,
    ClaimType.shortage,
    ClaimType.other,
  ],
  minPhotosRequired: 1,
  photosMandatory: false,  // Optional
  requireCustomerSignature: false,
  claimFilingDeadlineDays: null,  // Unlimited
  enableAutoApproval: true,
  autoApproveUnderAmount: 200.00,  // Auto-approve < R200
)
```

### Example 2: Medium Grocery Chain (Standard)
```dart
CompanyClaimSettings(
  workflowPreset: ClaimWorkflowPreset.standard,
  enabledClaimTypes: [
    ClaimType.damaged,
    ClaimType.shortage,
    ClaimType.wrongItems,
    ClaimType.expiryIssue,
    ClaimType.returns,
  ],
  minPhotosRequired: 2,
  photosMandatory: true,
  requireCustomerSignature: true,
  claimFilingDeadlineDays: 3,  // 3 days
  defaultSlaHours: 24,
  enableFraudDetection: true,
  fraudThresholdAmount: 2000.00,
)
```

### Example 3: Wholesale Meat (Enterprise - Your Client)
```dart
CompanyClaimSettings(
  workflowPreset: ClaimWorkflowPreset.enterprise,
  enabledClaimTypes: [
    ClaimType.damaged,
    ClaimType.shortage,
    ClaimType.shortWeight,
    ClaimType.wrongItems,
    ClaimType.returns,
    ClaimType.priceError,
    ClaimType.didNotDeliver,
    ClaimType.qualityIssue,
  ],
  minPhotosRequired: 2,
  maxPhotosAllowed: 10,
  photosMandatory: true,
  requireCustomerSignature: true,
  claimFilingDeadlineDays: 7,
  
  customWorkflows: {
    ClaimType.shortWeight: [
      ApprovalRole(role: 'manager', displayName: 'Wholesale Manager', slaHours: 24),
      ApprovalRole(role: 'approver', displayName: 'Senior Approver', slaHours: 12),
      ApprovalRole(role: 'processor', displayName: 'Processor', slaHours: 48),
      ApprovalRole(role: 'reviewer', displayName: 'Reviewer', slaHours: 24),
    ],
  },
  
  customFieldsByType: {
    ClaimType.shortWeight: [
      // Scale test, weights, slaughter type, return song (as shown above)
    ],
  },
  
  requiresERPSync: true,
  erpSystem: 'Abaserve',
  
  enableFraudDetection: true,
  fraudThresholdAmount: 5000.00,
  enablePatternDetection: true,
  
  enablePushNotifications: true,
  enableEmailNotifications: true,
)
```

---

## 🔧 Implementation Benefits

### ✅ For Different Company Sizes:

**Startup/Small (1-5 employees)**
- Simple workflow: 2 clicks to approve
- Minimal photos
- No signatures required
- Auto-approve small claims
- **Setup time: 5 minutes**

**Medium Business (10-50 employees)**
- Standard workflow: Manager oversight
- Required photos and evidence
- Optional signatures
- SLA tracking
- **Setup time: 15 minutes**

**Enterprise (50+ employees)**
- Full enterprise workflow
- Custom fields per claim type
- Digital signatures required
- ERP integration
- Fraud detection
- Pattern analysis
- **Setup time: 30 minutes + custom config**

### ✅ For Different Industries:

**Food/Perishables**
- Enable: `temperatureIssue`, `expiryIssue`, `qualityIssue`
- Custom fields: Temperature logs, expiry dates
- Photo requirements: Product + temperature gauge

**Retail/E-commerce**
- Enable: `wrongItems`, `damaged`, `missing`, `lateDelivery`
- Custom fields: Order number, tracking number
- Customer signature required

**Wholesale/Distribution**
- Enable: All claim types
- Custom fields: Invoice number, return song, weights
- Multi-level approval workflow

**Construction/Heavy Equipment**
- Enable: `damaged`, `shortage`, `wrongItems`
- Custom fields: Equipment ID, condition report
- Photo requirements: 5+ photos from different angles

---

## 📈 Scalability

### Database Structure (Scalable)
```
/companies/{companyId}/
  /claimSettings (1 document)
    - Configuration for this company
  
  /claims/{claimId}
    - Individual claims
    - Indexed by: status, type, driverId, customerId, createdAt
  
  /claimCounters/{year}
    - Auto-incrementing claim numbers
    - Per company, per year
```

### Caching Strategy
- Claim settings cached on app start
- Custom fields cached per claim type
- Workflows cached per company
- **Result**: Fast UI, no config lookups per claim

---

## 🎯 Next Steps

### Phase 1: Core Implementation (Week 1-2)
- ✅ Claim model (DONE)
- ✅ Company settings model (DONE)
- ⏳ Claim service (Firestore CRUD)
- ⏳ Claim provider (State management)
- ⏳ Driver report issue screen
- ⏳ Admin claims dashboard
- ⏳ Claim details/review screen

### Phase 2: Configuration UI (Week 3)
- Admin settings screen to configure:
  - Enabled claim types
  - Workflow preset selection
  - Photo/signature requirements
  - Custom fields builder
  - SLA settings

### Phase 3: Advanced Features (Week 4+)
- Auto-approval logic
- Fraud detection algorithms
- Pattern detection
- ERP integration framework
- Analytics dashboard

---

## 💡 Key Innovations

### 1. **Metadata Field**
```dart
Map<String, dynamic> metadata;
```
Stores any company-specific data without schema changes. Examples:
- `metadata['returnSongNumber']`
- `metadata['temperatureLog']`
- `metadata['labTestResult']`
- `metadata['externalSystemId']`

### 2. **Custom Fields System**
Dynamic form generation based on company config:
```dart
List<CustomField> customFields;
```
UI automatically renders appropriate input widgets.

### 3. **Approval Chain**
```dart
List<ApprovalLevel> approvalChain;
int currentApprovalLevel;
```
Tracks progress through multi-step workflow. Each company defines their own chain.

### 4. **Status History**
```dart
List<StatusHistoryEntry> statusHistory;
```
Complete audit trail:
- Who changed status
- When
- Why (optional notes)
- Legally defensible

---

## 🎉 Summary

**We've built a claims system that:**
✅ Works out-of-the-box for simple companies
✅ Scales to enterprise complexity
✅ Adapts to different industries
✅ Requires NO CODE CHANGES for new requirements
✅ Provides complete audit trail
✅ Supports any approval workflow
✅ Handles custom data collection
✅ Integrates with external systems

**Companies configure, not code!** 🚀
