# 📦 Item Catalog Feature - Design Document

## Overview
Enable users to create, manage, and reuse delivery items through a company-wide item catalog with autocomplete functionality in the delivery creation flow.

---

## 🎯 Goals

1. **Speed up delivery creation** - Reduce time spent typing item descriptions
2. **Ensure consistency** - Standardize item naming across the organization
3. **Improve data quality** - Reduce typos and variations in item descriptions
4. **Maintain flexibility** - Still allow custom one-off items when needed

---

## 📊 Data Model

### Firestore Structure

```
companies/{companyId}/itemCatalog/{itemId}
  - description: string (required)
  - unit: string (optional) - e.g., "boxes", "pallets", "cases"
  - defaultQuantity: number (optional) - suggested quantity
  - unitPrice: number (optional) - default unit price
  - category: string (optional) - for future filtering
  - isActive: boolean (default: true)
  - usageCount: number (default: 0) - track popularity
  - lastUsed: timestamp (optional)
  - createdAt: timestamp
  - createdBy: string (userId)
  - updatedAt: timestamp
  - updatedBy: string (userId)
```

### Dart Model

```dart
class CatalogItem {
  final String id;
  final String companyId;
  final String description;
  final String? unit;
  final double? defaultQuantity;
  final double? unitPrice;
  final String? category;
  final bool isActive;
  final int usageCount;
  final DateTime? lastUsed;
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String updatedBy;
  
  // Convert to DeliveryItem with optional quantity override
  DeliveryItem toDeliveryItem({double? quantity});
}
```

---

## 🎨 User Interface Design

### 1. Enhanced Item Dialog (with Autocomplete)

**Current Flow:**
```
[Add Item] → Dialog with 3 text fields → Manual typing
```

**New Flow:**
```
[Add Item] → Dialog with autocomplete → Select from catalog OR type custom
```

#### Mockup - Item Dialog with Autocomplete

```
╔══════════════════════════════════════════════════════════╗
║  Add Item                                        [X]      ║
╠══════════════════════════════════════════════════════════╣
║                                                           ║
║  Description *                                            ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ 📦 Start typing or select from catalog...      [v] │ ║
║  └─────────────────────────────────────────────────────┘ ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ 📦 Office Desk - Standard (42 pallets)     ⭐ 156   │ ║
║  │ 📦 Office Chair - Executive (12 boxes)     ⭐ 89    │ ║
║  │ 📦 Filing Cabinet - 4 Drawer (6 units)     ⭐ 67    │ ║
║  │ ─────────────────────────────────────────────────── │ ║
║  │ ✏️  Create custom item: "Office..."                 │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║  Quantity *                                               ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ 42                              [- 1  □  + 1]       │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║  Unit (Optional)                                          ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ pallets                                         [v] │ ║
║  └─────────────────────────────────────────────────────┘ ║
║  Common: boxes | pallets | cases | units | pieces        ║
║                                                           ║
║  Unit Price (Optional)                                    ║
║  ┌─────────────────────────────────────────────────────┐ ║
║  │ R 1,250.00                                          │ ║
║  └─────────────────────────────────────────────────────┘ ║
║                                                           ║
║  ☑ Save to catalog for future use                        ║
║                                                           ║
║  [Cancel]                           [Save Item]           ║
╚══════════════════════════════════════════════════════════╝
```

**Key Features:**
- **Autocomplete dropdown** shows catalog items as user types
- **Usage count** (⭐) shows popularity of items
- **Pre-filled values** when selecting from catalog
- **Quantity stepper** for quick adjustment
- **Unit suggestions** for common units
- **"Save to catalog"** checkbox for new custom items

---

### 2. Item Catalog Management Screen

New admin screen to manage catalog items.

#### Mockup - Catalog Management Screen

```
╔════════════════════════════════════════════════════════════════════════╗
║  PODSafe Admin - Item Catalog                              [@] [=]     ║
╠════════════════════════════════════════════════════════════════════════╣
║                                                                         ║
║  ┌──────────────────────────────────────────────────────────────────┐  ║
║  │  Manage Item Catalog                                             │  ║
║  │  Create and manage reusable delivery items for your company      │  ║
║  └──────────────────────────────────────────────────────────────────┘  ║
║                                                                         ║
║  ┌────────────────────────────────────────────────────────────────────┐║
║  │ 🔍 Search items...                           [+ Add New Item]     │║
║  └────────────────────────────────────────────────────────────────────┘║
║                                                                         ║
║  Filters:  [All Items ▼]  [All Categories ▼]  [Sort by: Most Used ▼] ║
║                                                                         ║
║  ╔════════════════════════════════════════════════════════════════════╗║
║  ║ Description          Unit      Qty    Price    Used   Actions     ║║
║  ╠════════════════════════════════════════════════════════════════════╣║
║  ║ 📦 Office Desk -     pallets    42    R 1,250   156   [✏️] [🗑️]  ║║
║  ║    Standard                                                        ║║
║  ║ ────────────────────────────────────────────────────────────────── ║║
║  ║ 📦 Office Chair -    boxes      12    R 850     89    [✏️] [🗑️]  ║║
║  ║    Executive                                                       ║║
║  ║ ────────────────────────────────────────────────────────────────── ║║
║  ║ 📦 Filing Cabinet    units       6    R 450     67    [✏️] [🗑️]  ║║
║  ║    4 Drawer                                                        ║║
║  ║ ────────────────────────────────────────────────────────────────── ║║
║  ║ 📦 Printer Paper -   cases      20    R 125     54    [✏️] [🗑️]  ║║
║  ║    A4 Boxes                                                        ║║
║  ║ ────────────────────────────────────────────────────────────────── ║║
║  ║ 📦 Laptop Computer   units       1    R 12,500  41    [✏️] [🗑️]  ║║
║  ╚════════════════════════════════════════════════════════════════════╝║
║                                                                         ║
║  Showing 5 of 23 items                            [< 1 2 3 4 5 >]     ║
║                                                                         ║
╚════════════════════════════════════════════════════════════════════════╝
```

**Key Features:**
- **Search** and **filter** capabilities
- **Sort by usage** to see most popular items
- **Edit** and **delete** actions
- **Usage statistics** to understand which items are most common

---

### 3. Quick Actions in Item List

Enhanced item display in delivery creation with quick actions.

```
╔═══════════════════════════════════════════════════════════════╗
║  Delivery Items                        [📋 Copy from Previous] ║
║                                        [+ Add Item]            ║
╠═══════════════════════════════════════════════════════════════╣
║  ┌───────────────────────────────────────────────────────────┐ ║
║  │ 42  📦 Office Desk - Standard               [✏️] [🗑️]    │ ║
║  │     pallets • R 52,500.00                                 │ ║
║  └───────────────────────────────────────────────────────────┘ ║
║  ┌───────────────────────────────────────────────────────────┐ ║
║  │ 12  📦 Office Chair - Executive             [✏️] [🗑️]    │ ║
║  │     boxes • R 10,200.00                                   │ ║
║  └───────────────────────────────────────────────────────────┘ ║
║  ┌───────────────────────────────────────────────────────────┐ ║
║  │  6  📦 Filing Cabinet - 4 Drawer            [✏️] [🗑️]    │ ║
║  │     units • R 2,700.00                                    │ ║
║  └───────────────────────────────────────────────────────────┘ ║
║                                                                 ║
║  Total Item Value: R 65,400.00                                 ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 4. Navigation Integration

Add to Admin Dashboard sidebar:

```
Admin Dashboard
├── 📊 Overview
├── 🚚 Delivery Management
├── 👥 Driver Management
├── 📦 Item Catalog          ← NEW
├── 🏢 Customer Management
├── ⚙️  Settings
└── 📤 Logout
```

---

## 🔄 User Flows

### Flow 1: Creating Delivery with Catalog Items

```
User Action                          System Response
─────────────────────────────────────────────────────────────
1. Click "Add Item"          →       Opens item dialog
2. Start typing "Office"     →       Shows matching catalog items
3. Select "Office Desk"      →       Pre-fills description, unit, qty
4. Adjust quantity to 50     →       Updates quantity field
5. Click "Save Item"         →       Adds item to delivery
                                      Updates catalog usageCount
```

### Flow 2: Creating Custom Item (Save to Catalog)

```
User Action                          System Response
─────────────────────────────────────────────────────────────
1. Click "Add Item"          →       Opens item dialog
2. Type "Custom Widget X"    →       No catalog matches found
3. Enter quantity: 10        →       Accepts input
4. Enter unit: "crates"      →       Accepts input
5. Check "Save to catalog"   →       Checkbox checked
6. Click "Save Item"         →       Adds to delivery AND catalog
```

### Flow 3: Managing Catalog Items

```
Admin Action                         System Response
─────────────────────────────────────────────────────────────
1. Navigate to Item Catalog  →       Shows catalog screen
2. Click "Add New Item"      →       Opens creation dialog
3. Fill in details           →       Validates input
4. Click "Save"              →       Creates catalog item
5. Later: Click edit icon    →       Opens edit dialog
6. Update description        →       Updates catalog item
7. Click delete icon         →       Confirms, then soft-deletes
```

---

## ⚙️ Technical Implementation

### Phase 1: Core Infrastructure (Day 1)

**Files to Create:**
1. `lib/models/catalog_item_model.dart` - Data model
2. `lib/services/item_catalog_service.dart` - Firestore operations
3. `lib/providers/catalog_provider.dart` - State management

**Files to Modify:**
1. `lib/screens/admin/create_delivery_screen.dart` - Add autocomplete

### Phase 2: Autocomplete Dialog (Day 2)

**Files to Create:**
1. `lib/widgets/item_autocomplete.dart` - Reusable autocomplete widget

**Files to Modify:**
1. Update `_ItemDialog` in `create_delivery_screen.dart`

### Phase 3: Management Screen (Day 3)

**Files to Create:**
1. `lib/screens/admin/item_catalog_screen.dart` - Main catalog screen
2. `lib/screens/admin/item_catalog_desktop.dart` - Desktop version

**Files to Modify:**
1. `lib/screens/admin/admin_dashboard_desktop.dart` - Add navigation
2. `lib/main.dart` - Add route

### Phase 4: Polish & Analytics (Day 4)

- Usage tracking
- Popular items sorting
- Bulk import/export
- Statistics dashboard

---

## 🔐 Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Item Catalog Rules
    match /companies/{companyId}/itemCatalog/{itemId} {
      // Allow read for authenticated company members
      allow read: if request.auth != null && 
                    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId &&
                    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isActive == true;
      
      // Allow write for admins and managers only
      allow create, update: if request.auth != null && 
                              get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId &&
                              get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isActive == true &&
                              get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'manager'];
      
      // Allow delete for admins only (soft delete recommended)
      allow delete: if request.auth != null && 
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companyId == companyId &&
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isActive == true &&
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## 📈 Success Metrics

1. **Adoption Rate**: % of deliveries using catalog items
2. **Time Savings**: Average time to add items (before/after)
3. **Data Quality**: Reduction in unique item descriptions
4. **User Satisfaction**: Feedback from delivery creators

**Target Metrics (after 30 days):**
- 70% of items selected from catalog
- 40% reduction in time to create delivery
- 60% reduction in unique descriptions for common items

---

## 🚀 Future Enhancements

1. **Categories** - Organize items by department/type
2. **Item Templates** - Pre-built sets of items (e.g., "Standard Office Setup")
3. **Customer-Specific Items** - Link frequent items to customers
4. **Price Lists** - Manage pricing tiers and updates
5. **Barcode Scanning** - Scan items to add them
6. **Analytics Dashboard** - Insights on popular items
7. **Import from Business Central** - Sync with existing product catalog
8. **Multi-language Support** - Item names in multiple languages

---

## 🎯 Implementation Priority

### Must Have (MVP)
✅ Data model and Firestore structure  
✅ Autocomplete in item dialog  
✅ Basic CRUD operations  
✅ Usage tracking  
✅ Management screen  

### Should Have (Phase 2)
- Search and filtering
- Bulk operations
- Export catalog

### Nice to Have (Phase 3)
- Categories
- Item templates
- Advanced analytics

---

## 🧪 Testing Strategy

### Unit Tests
- CatalogItem model serialization
- ItemCatalogService CRUD operations
- Search and filter logic

### Integration Tests
- Autocomplete functionality
- Item selection flow
- Usage count updates

### User Acceptance Tests
- Admin can create catalog items
- Users can search and select items
- Custom items can be saved to catalog
- Catalog items appear in autocomplete

---

## 📝 Migration Plan

### Step 1: Deploy Empty Catalog
- No impact on existing deliveries
- Catalog starts empty

### Step 2: Gradual Adoption
- Users continue creating custom items
- Option to "Save to catalog" introduces items organically

### Step 3: Seed Catalog (Optional)
- Import common items from historical deliveries
- Script to analyze most frequent descriptions

### Step 4: Promote Usage
- In-app tips and notifications
- Training for dispatch/admin staff

---

## 💡 User Experience Highlights

### For Delivery Creators
- **3 keystrokes** instead of typing full description
- **Consistent naming** reduces confusion
- **Pre-filled quantities** from past orders
- **Still flexible** for unique items

### For Admins
- **Centralized control** over item naming
- **Usage insights** to optimize inventory
- **Easy maintenance** with simple CRUD interface
- **Data quality** improvement over time

### For Drivers
- **Clearer descriptions** on delivery manifests
- **Consistent terminology** across orders
- **Better communication** with customers

---

## 🎨 Design Principles

1. **Progressive Enhancement** - Works with or without catalog
2. **Non-Disruptive** - Doesn't change existing workflows
3. **Fast by Default** - Optimizes common paths
4. **Flexible When Needed** - Always allows custom entries
5. **Learn from Usage** - Improves automatically over time

---

## 📱 Mobile Considerations

- Autocomplete dropdown adapted for smaller screens
- Touch-friendly item selection
- Quick-add buttons for top 5 items
- Swipe actions for edit/delete in catalog

---

## ♿ Accessibility

- Screen reader support for autocomplete
- Keyboard navigation throughout
- High contrast mode compatible
- Clear error messages and validation

---

## 🔄 State Management

```dart
// Catalog Provider
class CatalogProvider extends ChangeNotifier {
  List<CatalogItem> _items = [];
  bool _isLoading = false;
  
  // Cache for performance
  List<CatalogItem> get items => _items;
  List<CatalogItem> get popularItems => _items
    ..sort((a, b) => b.usageCount.compareTo(a.usageCount))
    ..take(10);
  
  // Search with fuzzy matching
  List<CatalogItem> search(String query) {
    // Implementation
  }
  
  Future<void> loadCatalog(String companyId);
  Future<void> addItem(CatalogItem item);
  Future<void> updateItem(CatalogItem item);
  Future<void> deleteItem(String itemId);
}
```

---

## 🎬 Demo Script

**Scenario:** Creating a delivery for office furniture

1. Open "Create Delivery" screen
2. Click "Add Item"
3. Start typing "Office"
4. Autocomplete shows: "Office Desk", "Office Chair"
5. Select "Office Desk" - fields auto-fill
6. Adjust quantity from 42 to 50
7. Click "Save Item" - added to delivery
8. Repeat for other items in 5 seconds each
9. Total time: **30 seconds vs 2 minutes manually**

---

## 📦 Deliverables

### Code
- [ ] `catalog_item_model.dart`
- [ ] `item_catalog_service.dart`
- [ ] `catalog_provider.dart`
- [ ] `item_autocomplete.dart` widget
- [ ] Updated `create_delivery_screen.dart`
- [ ] `item_catalog_screen.dart`
- [ ] `item_catalog_desktop.dart`

### Documentation
- [ ] API documentation
- [ ] User guide for catalog management
- [ ] Developer guide for extending features

### Tests
- [ ] Unit tests for model and service
- [ ] Widget tests for autocomplete
- [ ] Integration tests for full flow

---

## ✅ Ready to Implement?

This design provides:
- Clear data model and structure
- Detailed UI mockups
- Step-by-step user flows
- Technical implementation plan
- Security considerations
- Testing strategy
- Success metrics

**Next Steps:**
1. Review and approve this design
2. I'll implement Phase 1 (core infrastructure)
3. Then Phase 2 (autocomplete dialog)
4. Then Phase 3 (management screen)
5. Polish and test

Let me know if you'd like any adjustments to this design before I start implementation! 🚀
