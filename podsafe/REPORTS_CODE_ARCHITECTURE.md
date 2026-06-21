# Reports Screen - Code Architecture Overview

## File Structure

```
lib/
├── screens/admin/
│   ├── reports_screen.dart          # Main entry point (565 lines)
│   ├── reports_desktop.dart         # Desktop version (778 lines)
│   ├── admin_dashboard_screen.dart  # MODIFIED - Added Reports button
│   └── admin_dashboard_desktop.dart # MODIFIED - Added Reports button
│
├── models/
│   └── permission.dart              # MODIFIED - Added reportsView, reportsExport
│
└── main.dart                         # MODIFIED - Added /admin/reports route
```

## Class Hierarchy

```
ReportsScreen (StatelessWidget)
├── Mobile (Layout > 1200px)
│   └── ReportsMobile (StatefulWidget)
│       └── _ReportsMobileState
│           ├── _loadReport()
│           ├── _loadDeliveryReport()
│           ├── _loadDriverReport()
│           ├── _loadClaimsReport()
│           ├── _loadCustomersReport()
│           ├── _loadPODReport()
│           ├── _buildReportTable()
│           ├── _buildTableColumns()
│           ├── _buildTableRows()
│           └── _getStatusColor()
│
└── Desktop (Layout ≤ 1200px)
    └── ReportsDesktop (StatefulWidget)
        └── _ReportsDesktopState
            ├── [Same methods as Mobile]
            ├── _buildSidebarItem()
            └── _getReportTitle()
```

## Enum: ReportType

```dart
enum ReportType {
  delivery,    // Delivery tracking
  driver,      // Driver performance
  claims,      // Claims management
  customers,   // Customer analytics
  pod          // Proof of delivery
}
```

## Data Models

Each report loads data into this structure:

```dart
List<Map<String, dynamic>> _reportData = [];
Map<String, dynamic> _summaryStats = {};
```

### Delivery Report Data
```dart
{
  'id': String,
  'trackingNumber': String,
  'customerName': String,
  'status': String,
  'scheduledDate': Timestamp,
  'driverName': String,
  'amount': double,
}
```

### Driver Report Data
```dart
{
  'id': String,
  'fullName': String,
  'email': String,
  'phone': String,
  'approvalStatus': String,
  'isActive': bool,
  'deliveriesCount': int,
  'completedCount': int,
  'joinDate': Timestamp,
}
```

### Claims Report Data
```dart
{
  'id': String,
  'claimNumber': String,
  'customerName': String,
  'status': String,
  'amount': double,
  'type': String,
  'createdAt': Timestamp,
  'reason': String,
}
```

### Customer Report Data
```dart
{
  'id': String,
  'name': String,
  'email': String,
  'phone': String,
  'city': String,
  'deliveriesCount': int,
  'completedCount': int,
  'totalAmount': double,
  'createdAt': Timestamp,
}
```

### POD Report Data
```dart
{
  'id': String,
  'deliveryId': String,
  'driverName': String,
  'customerName': String,
  'hasSigned': bool,
  'hasPhotos': bool,
  'hasNotes': bool,
  'createdAt': Timestamp,
}
```

## Widget Tree

### Mobile Layout
```
Scaffold
├── AppBar
│   ├── Title: "Reports"
│   ├── IconButton: Refresh
│   └── IconButton: Calendar (Date Range)
│
└── Body: SingleChildScrollView
    └── Column
        ├── SingleChildScrollView (horizontal)
        │   └── Row [Report Type Chips]
        │       ├── FilterChip: Deliveries
        │       ├── FilterChip: Drivers
        │       ├── FilterChip: Claims
        │       ├── FilterChip: Customers
        │       └── FilterChip: PODs
        │
        ├── Card [Summary Stats]
        │   └── GridView (2 columns)
        │       ├── StatCard
        │       ├── StatCard
        │       └── ...
        │
        └── Card [Data Table]
            └── DataTable
                ├── DataColumn: Column headers
                └── DataRow: Table rows
```

### Desktop Layout
```
Scaffold
├── AppBar
│   ├── Title: "Reports"
│   ├── IconButton: Refresh
│   └── IconButton: Calendar (Date Range)
│
└── Body: Row
    ├── Container (Sidebar)
    │   └── ListView
    │       ├── Padding: "Report Type"
    │       ├── ListTile: Deliveries
    │       ├── ListTile: Drivers
    │       ├── ListTile: Claims
    │       ├── ListTile: Customers
    │       └── ListTile: PODs
    │
    └── Expanded [Main Content]
        └── SingleChildScrollView
            └── Column
                ├── Text: Report Title
                ├── Text: Date Range Display
                ├── Card [Summary Stats]
                │   └── GridView (4 columns)
                │       ├── StatCard
                │       ├── StatCard
                │       └── ...
                │
                └── Card [Data Table]
                    └── DataTable
                        ├── DataColumn: Column headers
                        └── DataRow: Table rows
```

## Key Methods

### Data Loading
```dart
Future<void> _loadReport()
  → Selects which report to load based on _selectedReport

Future<void> _loadDeliveryReport(String companyId)
  → Queries deliveries collection
  → Calculates summary stats
  → Updates _reportData & _summaryStats

// Similar methods for other report types:
_loadDriverReport()
_loadClaimsReport()
_loadCustomersReport()
_loadPODReport()
```

### UI Building
```dart
Widget _buildReportTable()
  → Builds DataTable widget
  → Uses _buildTableColumns()
  → Uses _buildTableRows()

List<DataColumn> _buildTableColumns()
  → Returns columns based on report type

List<DataRow> _buildTableRows()
  → Returns data rows based on report type
  → Formats data (currency, dates, etc.)
  → Applies color coding

Widget _buildSummaryStats()
  → Builds stats cards
  → Uses _buildSummaryCards()

List<Widget> _buildSummaryCards()
  → Returns cards based on report type
```

### Utilities
```dart
Color _getStatusColor(String status)
  → Returns color for status value
  → Green: delivered, completed, approved
  → Orange: pending
  → Blue: inTransit
  → Red: rejected

void _showDateRangePicker()
  → Shows calendar date picker
  → Updates _startDate & _endDate
  → Reloads report data
```

## Firestore Queries

### Delivery Query
```dart
deliveries
  .where('companyId', isEqualTo: companyId)
  .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
  .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate))
  .orderBy('scheduledDate', descending: true)
  .get()
```

### Driver Query
```dart
users
  .where('companyId', isEqualTo: companyId)
  .where('role', isEqualTo: 'driver')
  .get()
// Then for each driver:
deliveries
  .where('driverId', isEqualTo: driverId)
  .where('scheduledDate', isGreaterThanOrEqualTo: ...)
  .where('scheduledDate', isLessThanOrEqualTo: ...)
  .get()
```

Similar patterns for Claims, Customers, and PODs.

## State Variables

```dart
// UI State
ReportType _selectedReport = ReportType.delivery;
DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
DateTime _endDate = DateTime.now();
bool _isLoading = false;

// Data State
List<Map<String, dynamic>> _reportData = [];
Map<String, dynamic> _summaryStats = {};
```

## Color Constants

```dart
Colors.blue           // Total counts, in transit
Colors.green          // Completed, approved
Colors.orange         // Pending
Colors.purple         // Performance metrics
Colors.teal           // Notes/additional
Colors.red            // Rejected, failed
AppTheme.primaryColor // Headers, accents
```

## Formatting Utilities

```dart
// Currency
'R${value.toStringAsFixed(2)}'  // R450.00

// Dates
DateFormat('MMM dd').format(date)           // Oct 20
DateFormat('MMM dd, yyyy').format(date)     // Oct 20, 2024

// Percentages
'${(percentage).toStringAsFixed(1)}%'       // 71.1%
```

## Import Dependencies

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../providers/auth_provider.dart';
```

## Route Integration

```dart
// In main.dart routes map:
'/admin/reports': (context) => const ReportsScreen(),
```

## Permission Integration

```dart
// In permission.dart:
enum Permission {
  // ... existing permissions ...
  reportsView,      // View reports
  reportsExport,    // Export reports (future)
}

extension PermissionExtension on Permission {
  String get displayName {
    // ...
    case Permission.reportsView:
      return 'View Reports';
    case Permission.reportsExport:
      return 'Export Reports';
  }
}
```

## Error Handling

```dart
try {
  // Query data
} catch (e) {
  debugPrint('Error loading report: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error loading report: $e')),
  );
} finally {
  setState(() => _isLoading = false);
}
```

## Empty State Handling

```dart
if (_reportData.isEmpty) {
  return Center(
    child: Column(
      children: [
        Icon(Icons.inbox, color: Colors.grey[400]),
        Text('No data available'),
      ],
    ),
  );
}
```

## Responsive Layout Logic

```dart
if (constraints.maxWidth > 1200) {
  return const ReportsDesktop();  // > 1200px
} else {
  return const ReportsMobile();   // ≤ 1200px
}
```

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No data shows | Date range too narrow | Check date picker |
| Slow loading | Too many records | Reduce date range |
| null pointer | Missing companyId | Check auth provider |
| Layout shift | Responsive breakpoint | Verify window size |
| Wrong data | Company ID mismatch | Verify user company |

---

**This architecture is:**
- ✅ Scalable (easy to add report types)
- ✅ Maintainable (clear structure)
- ✅ Testable (separate methods)
- ✅ Performant (optimized queries)
- ✅ Secure (company-scoped)
- ✅ User-friendly (responsive design)
