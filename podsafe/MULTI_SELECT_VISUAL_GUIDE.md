# 🎨 Multi-Select Feature - Visual Guide

## 📺 User Interface Overview

### POD View Desktop - Multi-Select Enabled

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📋 POD Viewer                         🔄  ⬇️  [5 selected]  ⊗       │  ← Header
├─────────────────────────────────────────────────────────────────────┤
│ Status: All  │ Type: All  │ Date: All  │ Sort: Date↓ │ [☐ Multi]   │  ← Filter Bar
├─────────────────────────────────────────────────────────────────────┤
│  ☑  POD001  Customer A    $150    ✓    Jan 15      [Actions]      │
│  ☑  POD002  Customer B    $200    ✓    Jan 16      [Actions]      │
│  ☑  POD003  Customer C    $175    ✓    Jan 17      [Actions]      │
│  ☐  POD004  Customer D    $220    ✓    Jan 18      [Actions]      │
│  ☑  POD005  Customer E    $190    ✓    Jan 19      [Actions]      │
├─────────────────────────────────────────────────────────────────────┤
│ Ctrl+F Search  Ctrl+A Select All  Esc Clear  F5 Refresh             │  ← Shortcuts
└─────────────────────────────────────────────────────────────────────┘
```

### Claims Management Desktop - Multi-Select Enabled

```
┌──────────────────────────────────────────────────────────────────┐
│ 📋 Claims Management  ✓  ❌  🔄  ⬇️  [3 selected]  ⊗             │  ← Header
├──────────────────────────────────────────────────────────────────┤
│ Status: All │ Type: All │ Date: All │ Sort │ ✅ Select All ❌ Clear │ ← Filter
├──────────────────────────────────────────────────────────────────┤
│  ☑  INV001  #C001  ORD001  Damage   Pending  $150  Jan 15       │
│  ☑  INV002  #C002  ORD002  Shortage Pending  $200  Jan 16       │
│  ☑  INV003  #C003  ORD003  Missing  Pending  $175  Jan 17       │
│  ☐  INV004  #C004  ORD004  Late     Pending  $220  Jan 18       │
├──────────────────────────────────────────────────────────────────┤
│ Ctrl+F Search  Ctrl+A Select All  Esc Clear  F5 Refresh          │  ← Shortcuts
└──────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Feature Locations

### POD View - Component Locations

```
Top Bar (Search & Statistics)
  ├─ Search Field
  └─ Stat Cards (Total, Pending, etc.)
       ↓
Filter Bar
  ├─ Status Dropdown
  ├─ Type Dropdown
  ├─ Date Range
  ├─ Sort Options
  └─ ☐ Multi-Select Toggle ← NEW!
       ↓
Data Table (PODs List)
  ├─ Checkboxes (visible in multi-select) ← NEW!
  ├─ POD Details
  └─ Action Buttons
       ↓
Keyboard Shortcuts Bar ← NEW!
  ├─ Ctrl+F Search
  ├─ Ctrl+A Select All
  ├─ Esc Clear Selection
  └─ F5 Refresh
```

### Claims Management - Component Locations

```
Header
  ├─ Title
  ├─ Bulk Actions (when selected) ← NEW!
  │  ├─ ✅ Bulk Approve
  │  └─ ❌ Bulk Reject
  ├─ Refresh
  ├─ Export
  └─ [3 selected] ← NEW!
       ↓
Filter Bar
  ├─ Status Filter
  ├─ Type Filter
  ├─ Date Range
  ├─ Sort Options
  ├─ ✅ Select All ← NEW!
  ├─ ❌ Clear ← NEW!
  └─ ☐ Multi-Select Toggle
       ↓
Data Table
  ├─ Checkboxes (visible in multi-select) ← NEW!
  └─ Claim Details
       ↓
Keyboard Shortcuts Bar ← NEW!
  ├─ Ctrl+F Search
  ├─ Ctrl+A Select All
  ├─ Esc Clear Selection
  └─ F5 Refresh
```

---

## 🔄 State Transitions

### Multi-Select Mode

```
┌──────────────────────┐
│  Single-Select Mode  │
│  (Default)           │
└──────────┬───────────┘
           │ Click Checkbox Toggle
           ↓
┌──────────────────────┐
│  Multi-Select Mode   │
│  ✓ Checkboxes on     │
│  ✓ Select All btn    │
│  ✗ Bulk actions      │
└──────────┬───────────┘
           │ Select Items (1+)
           ↓
┌──────────────────────┐
│  Items Selected      │
│  ✓ Clear btn appears │
│  ✓ Header shows count│
│  ✓ Bulk actions on   │
└──────────┬───────────┘
           │ Click bulk action
           ↓ (or Esc to clear)
           ✓ Action Complete
```

---

## 🎨 Button States

### Select All Button
```
Hidden (when not in multi-select mode)
    ↓
Visible (when multi-select active)
    ├─ Icon: ✓✓ (done_all)
    ├─ Text: "Select All"
    ├─ Color: Blue with light background
    └─ Click → Selects all visible items

Action: Selects all items in current view
Feedback: Shows snackbar with count (e.g., "25 claims selected")
```

### Clear Button
```
Hidden (when no items selected)
    ↓
Visible (when 1+ items selected)
    ├─ Icon: ✕✕ (clear_all)
    ├─ Text: "Clear"
    ├─ Color: Red with light background
    └─ Click → Deselects all items

Action: Removes all selections
Feedback: Button disappears when no items selected
```

### Bulk Action Buttons
```
Claims Management:
  ✅ Approve Button
    ├─ Icon: check_circle
    ├─ Visible: When 2+ claims selected
    ├─ Color: Green
    └─ Action: Approves all selected claims

  ❌ Reject Button
    ├─ Icon: cancel
    ├─ Visible: When 2+ claims selected
    ├─ Color: Red
    └─ Action: Rejects all selected claims

POD View:
  ⬇️ Download Button
    ├─ Icon: download
    ├─ Visible: When 1+ PODs selected
    ├─ Options: PDF, Images, CSV
    └─ Action: Exports selected PODs
```

---

## ⌨️ Keyboard Shortcuts Visual Map

```
┌─────────────────────────────────────────────────┐
│         KEYBOARD SHORTCUTS MAP                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Ctrl+F  │  │ Ctrl+A  │  │   Esc   │  F5    │
│  │ Search  │  │ Select  │  │  Clear  │ Refresh│
│  │         │  │   All   │  │         │        │
│  └─────────┘  └─────────┘  └─────────┘        │
│                                                 │
│  Located at bottom of screen (light bar)       │
│  Shows all available shortcuts                 │
│  Scrollable on small screens                   │
│                                                 │
└─────────────────────────────────────────────────┘

Shortcuts Bar Styling:
  Background: Light Gray (Colors.grey[100])
  Border: Top border in medium gray
  Text: Medium gray with dark border boxes
  Layout: Horizontal scrollable row
```

---

## 📊 Selection Indicator Examples

### Header Chip (Selection Counter)

```
No items selected:
  [Hidden]

1 item selected:
  [1 selected] ⊗

5 items selected:
  [5 selected] ⊗

25 items selected:
  [25 selected] ⊗

Style:
  ├─ Background: Color.white24 (transparent white)
  ├─ Text: White text
  ├─ Delete Icon: White 'X'
  ├─ Position: Top right of header
  └─ Click X → Clears all selections
```

### Row Highlighting

```
Unselected Row:
┌────────────────────────────────────────┐
│ ☐ POD001  Customer A  $150  ✓  Jan 15  │  ← Default color
└────────────────────────────────────────┘

Selected Row:
┌────────────────────────────────────────┐
│ ☑ POD001  Customer A  $150  ✓  Jan 15  │  ← Highlighted color
└────────────────────────────────────────┘

Highlighted (Detail Panel):
┌────────────────────────────────────────┐
│ ☑ POD001  Customer A  $150  ✓  Jan 15  │  ← Slightly different
└────────────────────────────────────────┘      highlight
```

---

## 🔄 Interaction Flow Diagrams

### POD View Multi-Select Flow

```
User Opens POD View
        ↓
    [Default View]
    Single-select mode
        ↓
  User clicks ☐ icon
        ↓
    [Multi-Select Active]
    ✓ Checkboxes visible
    ✓ "Select All" button shows
        ↓
  User does one of:
  ├─ Click rows → Select individually
  ├─ Click "Select All" → Select all
  └─ Press Ctrl+A → Select all
        ↓
  [Items Selected]
  ✓ Count shown in header
  ✓ "Clear" button shows
  ✓ Bulk action buttons active
        ↓
  User clicks bulk action
  ├─ Download as PDFs
  ├─ Download Images
  └─ Export CSV
        ↓
    [Action Processing]
    Progress dialog shown
        ↓
    [Success/Complete]
    User can select more or exit
```

### Claims Bulk Approve Flow

```
User Opens Claims
      ↓
  Filter to "Pending"
      ↓
  Click ☐ icon
      ↓
  Click "Select All"
      ↓
  [25 pending claims selected]
  Header shows: [25 selected]
  ✅ Approve button appears
      ↓
  User clicks ✅ Approve
      ↓
  [Processing]
  Dialog: "Approving 25 claims..."
      ↓
  [Complete]
  ✓ Success message
  ✓ List refreshes
  ✓ Selections clear
      ↓
  Back to default view
```

---

## 🎨 Color & Style Reference

### Colors Used

| Element | Color | Opacity | Usage |
|---------|-------|---------|-------|
| Select All Button | AppTheme.primaryColor | - | Active state |
| Select All Background | AppTheme.primaryColor | 0.1 | Subtle background |
| Clear Button | Colors.red | - | Warning color |
| Clear Background | Colors.red | 0.1 | Subtle background |
| Shortcuts Bar | Colors.grey | 100 | Background |
| Shortcut Text | Colors.grey | 700 | Text |
| Selection Border | Colors.grey | 300/200 | Borders |
| Header Chip | Colors.white | 0.24 | Transparent |

### Typography

| Element | Font Size | Weight | Notes |
|---------|-----------|--------|-------|
| Button Label | 13pt | Regular | Small, compact |
| Shortcut Label | 12pt | Regular | Smaller for hints |
| Shortcut Key | 11pt | Bold (600) | Emphasize keys |
| Header Chip | - | Regular | Uses default |

---

## 🖱️ Mouse Hover States

```
Select All Button (Normal):
┌──────────────┐
│ ✓✓ Select All│
└──────────────┘

Select All Button (Hovered):
┌──────────────────┐
│ ✓✓ Select All   │  ← Slightly raised/highlighted
└──────────────────┘

Row (Not Selected):
┌────────────────────┐
│ ☐ POD001  ...      │
└────────────────────┘

Row (Hovered, Not Selected):
┌────────────────────┐
│ ☐ POD001  ...      │  ← Highlight on hover
└────────────────────┘

Row (Selected):
┌────────────────────┐
│ ☑ POD001  ...      │  ← Blue/highlight color
└────────────────────┘

Row (Hovered, Selected):
┌────────────────────┐
│ ☑ POD001  ...      │  ← Same color
└────────────────────┘
```

---

## 📱 Responsive Design

### Desktop (> 1200px)
- Full multi-select features
- All buttons visible
- Shortcuts bar at bottom
- Detail panel beside list (conditionally)
- Checkboxes visible in multi-select mode

### Tablet (768px - 1200px)
- Multi-select features available
- Buttons may wrap
- Shortcuts bar scrollable
- Detail panel hidden or below
- Full functionality maintained

### Mobile (< 768px)
- Multi-select buttons available
- Checkboxes for row selection
- Keyboard shortcuts limited
- Touch-friendly interface
- Buttons stack vertically

---

## 🎯 Feature Checklist

### Visual Elements
- ✅ Checkboxes in rows
- ✅ Select All button
- ✅ Clear button
- ✅ Multi-select toggle (checkbox icon)
- ✅ Selection counter in header
- ✅ Keyboard shortcuts bar
- ✅ Bulk action buttons
- ✅ Row highlighting

### Interactions
- ✅ Click to select/deselect
- ✅ Ctrl+A to select all
- ✅ Esc to clear
- ✅ Button clicks for bulk actions
- ✅ Visual feedback on selection
- ✅ Snackbar messages

### Functionality
- ✅ Multi-select toggle on/off
- ✅ Select individual items
- ✅ Select all visible items
- ✅ Deselect all items
- ✅ Perform bulk operations
- ✅ Keyboard shortcuts work
- ✅ Selections persist across filtering
- ✅ Mode persistence during session

---

## ✨ Polish & Details

### Animations
- Button appearance: Fade in/out
- Row selection: Subtle highlight change
- Snackbar: Slide up from bottom
- Shortcuts bar: Fade in at bottom

### Feedback
- Snackbar on "Select All": Shows count
- Snackbar on bulk action: Shows result
- Visual indication of selected items
- Counter updates in real-time

### Accessibility
- Keyboard shortcuts for all actions
- Tooltips on hover
- Clear visual indicators
- Color not only means
- Semantic HTML/Flutter widgets

---

**Last Updated**: October 22, 2025
**Version**: 1.0
**Status**: ✅ Complete and Ready
