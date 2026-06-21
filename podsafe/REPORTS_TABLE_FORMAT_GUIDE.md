# Reports Screen - Visual Architecture & Table Format

## Screen Structure

### Mobile Layout
```
┌─────────────────────────────────────┐
│ AppBar: Reports                  🔄 📅 │
├─────────────────────────────────────┤
│ [Deliveries] [Drivers] [Claims]... │ ← Report Type Selector
├─────────────────────────────────────┤
│                                     │
│  Summary Statistics (Grid)          │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Total    │ │ Completed │ │
│  │    45    │ │    32     │ │
│  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Pending   │ │ In Transit  │ │
│  │    10     │ │     3       │ │
│  └──────────────┘  └──────────────┘ │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  Data Table (Horizontal Scroll)     │
│  ┌──────────────────────────────────┐│
│  │Tracking │Customer │Driver │Status││
│  ├──────────────────────────────────┤│
│  │TRK-00001│John Doe │Mark S │🟢    ││
│  │TRK-00002│Jane Doe │Sarah J│🟡    ││
│  │TRK-00003│Bob Smith│Tom W  │🔴    ││
│  └──────────────────────────────────┘│
│                                     │
└─────────────────────────────────────┘
```

### Desktop Layout
```
┌────────────────────────────────────────────────────────────┐
│ AppBar: Reports                                    🔄 📅 │
├──────────────┬──────────────────────────────────────────────┤
│ Deliveries   │                                              │
│ Drivers      │     Delivery Report                          │
│ Claims       │     Showing data from Oct 16 - Oct 23       │
│ Customers    │                                              │
│ PODs         │     Summary Statistics (4-Column Grid)      │
│              │     ┌────────┐ ┌────────┐ ┌────────┐ ┌─────┐
│              │     │ Total  │ │Complete│ │Pending │ │ Tra │
│              │     │  45    │ │  32    │ │  10    │ │  3  │
│              │     └────────┘ └────────┘ └────────┘ └─────┘
│              │
│              │     Data Table (Full Width)
│              │     ┌───────────────────────────────────────┐
│              │     │Tracking #│Customer │Driver│Status│Date│Amount
│              │     ├───────────────────────────────────────┤
│              │     │TRK-0001  │John Doe │Mark S│Deliv│10/20│R450.00
│              │     │TRK-0002  │Jane Doe │Sarah │Pend │10/21│R320.00
│              │     │TRK-0003  │Bob Smith│Tom W │Trans│10/22│R580.50
│              │     └───────────────────────────────────────┘
│              │
└──────────────┴──────────────────────────────────────────────┘
```

## Report Type Tables

### 1. DELIVERY REPORT
```
┌─────────────┬──────────────┬────────────┬──────────┬────────────┬────────┐
│ Tracking #  │ Customer     │ Driver     │ Status   │ Date       │ Amount │
├─────────────┼──────────────┼────────────┼──────────┼────────────┼────────┤
│ TRK-001     │ John Doe     │ Mark Smith │ Delivered│ Oct 20, 24 │ R450.00│
│ TRK-002     │ Jane Smith   │ Sarah Jones│ Pending  │ Oct 21, 24 │ R320.00│
│ TRK-003     │ Bob Johnson  │ Tom Wilson │ InTransit│ Oct 22, 24 │ R580.50│
│ TRK-004     │ Alice Brown  │ Unassigned │ Pending  │ Oct 23, 24 │ R215.75│
└─────────────┴──────────────┴────────────┴──────────┴────────────┴────────┘

Summary Stats:
├── Total: 45
├── Completed: 32 (71.1%)
├── Pending: 10
├── In Transit: 3
└── Total Amount: R15,680.50
```

### 2. DRIVER REPORT
```
┌──────────────┬─────────────────┬──────────┬──────────┬────────────┬────────┐
│ Name         │ Email           │ Phone    │ Status   │ Deliveries │Complete│
├──────────────┼─────────────────┼──────────┼──────────┼────────────┼────────┤
│ Mark Smith   │ mark@email.com  │ 555-1234 │ Approved │ 12         │ 11     │
│ Sarah Jones  │ sarah@email.com │ 555-5678 │ Approved │ 10         │ 9      │
│ Tom Wilson   │ tom@email.com   │ 555-9012 │ Pending  │ 8          │ 7      │
│ Lisa Brown   │ lisa@email.com  │ 555-3456 │ Approved │ 15         │ 15     │
└──────────────┴─────────────────┴──────────┴──────────┴────────────┴────────┘

Summary Stats:
├── Total Drivers: 25
├── Active: 20
├── Approved: 23
└── Pending Approvals: 2
```

### 3. CLAIMS REPORT
```
┌──────────┬──────────────┬────────┬──────────┬──────────┬────────────┐
│ Claim #  │ Customer     │ Type   │ Status   │ Amount   │ Date       │
├──────────┼──────────────┼────────┼──────────┼──────────┼────────────┤
│ CLM-0001 │ John Doe     │ Damage │ Approved │ R500.00  │ Oct 18, 24 │
│ CLM-0002 │ Jane Smith   │ Lost   │ Pending  │ R250.00  │ Oct 20, 24 │
│ CLM-0003 │ Bob Johnson  │ Delay  │ Rejected │ R100.00  │ Oct 21, 24 │
│ CLM-0004 │ Alice Brown  │ Other  │ Approved │ R325.50  │ Oct 22, 24 │
└──────────┴──────────────┴────────┴──────────┴──────────┴────────────┘

Summary Stats:
├── Total Claims: 18
├── Pending: 5
├── Approved: 10 (R2,450.00)
├── Rejected: 3
├── Total Amount: R2,850.00
└── Approval Rate: 55.6%
```

### 4. CUSTOMER REPORT
```
┌───────────┬─────────────────┬──────────┬────────────┬──────────┬────────────┐
│ Name      │ Email           │ City     │ Deliveries │ Complete │ Total Amt  │
├───────────┼─────────────────┼──────────┼────────────┼──────────┼────────────┤
│ John Doe  │ john@email.com  │ Cape Town│ 15         │ 15       │ R3,250.00  │
│ Jane Smith│ jane@email.com  │ Johanneb│ 12         │ 11       │ R2,480.00  │
│ Bob Johnson│bob@email.com   │ Durban  │ 8          │ 7        │ R1,540.00  │
│ Alice Brwn│ alice@email.com │ Pretoria│ 10         │ 9        │ R2,150.00  │
└───────────┴─────────────────┴──────────┴────────────┴──────────┴────────────┘

Summary Stats:
├── Total Customers: 42
└── Active Customers: 38
```

### 5. POD REPORT
```
┌──────────────┬────────────────┬──────────────┬────────┬────────┬────────┐
│ Delivery ID  │ Driver         │ Customer     │ Signed │ Photos │ Notes  │
├──────────────┼────────────────┼──────────────┼────────┼────────┼────────┤
│ DEL-00001    │ Mark Smith     │ John Doe     │ ✓      │ ✓      │ ✓      │
│ DEL-00002    │ Sarah Jones    │ Jane Smith   │ ✓      │ ✓      │ ✗      │
│ DEL-00003    │ Tom Wilson     │ Bob Johnson  │ ✗      │ ✓      │ ✓      │
│ DEL-00004    │ Lisa Brown     │ Alice Brown  │ ✓      │ ✗      │ ✗      │
└──────────────┴────────────────┴──────────────┴────────┴────────┴────────┘

Summary Stats:
├── Total PODs: 156
├── Signed: 145 (92.9%)
├── With Photos: 139 (89.1%)
├── With Notes: 128 (82.1%)
└── Signature Rate: 92.9%
```

## Color Coding System

### Status Indicators (Chips)
- 🟢 **Green**: Delivered, Completed, Approved, Active
- 🟡 **Orange**: Pending, In Progress
- 🔵 **Blue**: In Transit, Processing
- 🔴 **Red**: Rejected, Failed, Cancelled
- ⚪ **Gray**: Unknown, Inactive

### Summary Statistics Cards
- 🔵 **Blue**: Total counts
- 🟢 **Green**: Completed, Active, Approved
- 🟡 **Orange**: Pending, Awaiting
- 🔴 **Red**: Rejected, Failed
- 🟣 **Purple**: Performance metrics
- 🔷 **Cyan**: Additional metrics

## Filter & Search Features

### Date Range Picker
```
┌────────────────────────────────┐
│ From: Oct 16, 2024             │
│ To:   Oct 23, 2024             │
│                                │
│ [Cancel]           [Apply]     │
└────────────────────────────────┘
```

### Quick Navigation
- **Mobile**: Horizontal scrolling chips for report type selection
- **Desktop**: Sidebar with icon + text labels

## Interactive Elements

1. **Filter Chips**: Click to change report type
2. **Date Picker**: Tap calendar icon to adjust date range
3. **Refresh Button**: Manual data reload
4. **Scroll**: Horizontal scrolling for tables on mobile
5. **Status Indicators**: Visual status at a glance

## Responsive Breakpoints

- **Mobile**: ≤ 1200px width
  - Single-column layout
  - Horizontal table scrolling
  - Stacked statistics (2-column grid)
  - Compact chip buttons

- **Desktop**: > 1200px width
  - Sidebar + main content layout
  - Full-width tables
  - 4-column statistics grid
  - Icon-based navigation

## Currency & Date Formatting

- **Currency**: South African Rand (R) - e.g., R450.00
- **Short Date**: MMM dd (e.g., Oct 20)
- **Long Date**: MMM dd, yyyy (e.g., Oct 20, 2024)

## Performance Optimizations

1. **Lazy Loading**: Data loads on report type selection
2. **Pagination**: Ready for future implementation
3. **Firestore Indexing**: Queries indexed by companyId
4. **State Management**: Provider-based state for efficiency

---

**Table Format Benefits:**
✅ Clear data presentation  
✅ Easy scanning and comparison  
✅ Professional appearance  
✅ Sortable columns (ready for enhancement)  
✅ Export-ready structure  
✅ Mobile-responsive design  
✅ Accessible color coding  
