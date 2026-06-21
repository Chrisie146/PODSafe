# How to Access Import Customers

## 📍 Location

**Import Customers** is now available in the Admin Dashboard's Quick Actions section.

## 🚀 How to Access

### Method 1: Admin Dashboard (Recommended)

1. **Login** as an admin user
2. **Navigate** to Admin Dashboard
3. **Look for** the "Quick Actions" card (right side of dashboard)
4. **Click** on "Import Customers" button (cyan/turquoise color with upload icon 📤)

### Visual Layout

```
┌─────────────────────────────────────────────────────────────┐
│                    Admin Dashboard                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Stats Cards...                    ┌─────────────────────┐ │
│                                    │  Quick Actions      │ │
│                                    ├─────────────────────┤ │
│                                    │ 📦 New Delivery     │ │
│                                    │ 📋 View Deliveries  │ │
│                                    │ 👥 Manage Drivers   │ │
│                                    │ 📤 Import Customers │ ← HERE!
│                                    │ 📄 View PODs        │ │
│                                    │ ⚠️  Claims Mgmt     │ │
│                                    │ 📊 Analytics        │ │
│                                    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Button Details

- **Title**: Import Customers
- **Icon**: 📤 Upload file icon
- **Color**: Cyan/Turquoise (#00BCD4)
- **Position**: After "Manage Drivers", before "View PODs"

## 🔗 Direct Route

You can also navigate directly using the route:
```
/admin/customers/import
```

## ✅ What You'll See

When you click "Import Customers", you'll be taken to the import screen with:

1. **Upload Area** with:
   - "Choose CSV File" button
   - "Download CSV Template" button
   - Requirements list (Customer Number, Name, Address)

2. **After Upload**:
   - Validation results (statistics)
   - Error/warning list (if any)
   - Import progress bar
   - Success message

## 📝 Quick Test

To verify it's working:

1. Click "Import Customers" from Admin Dashboard
2. Click "Download CSV Template"
3. Upload the downloaded template
4. Click "Import Customers"
5. You should see: "✓ Imported 3 customers successfully"

## 🎯 First-Time Setup

### Step 1: Access the Screen
- Admin Dashboard → Quick Actions → Import Customers ✅

### Step 2: Download Template
- Click "Download CSV Template" button
- Opens: `customer_import_template.csv` with 3 examples

### Step 3: Prepare Your Data
Edit the CSV with your actual customers:

| Customer Number | Customer Name        | Address                          | Phone           | Customer Type |
|----------------|---------------------|----------------------------------|-----------------|---------------|
| BOX001         | Boxer Superstore    | 123 Main St, Cape Town, 8001    | +27211234567    | business      |
| PICK001        | Pick n Pay          | 456 Main Rd, Rondebosch, 7700   | +27219876543    | business      |
| HOME001        | Smith Residence     | 789 Oak Ave, Claremont, 7708    | +27821234567    | residential   |

### Step 4: Import
- Click "Choose CSV File"
- Select your prepared CSV
- Review validation results
- Click "Import Customers"
- Wait for success message

## 🔍 Troubleshooting

### Can't Find "Import Customers" Button?

**Check 1**: Are you logged in as admin?
- Only admin users can see this button
- Driver role won't have access

**Check 2**: Is the Admin Dashboard loaded?
- You should see statistics cards at the top
- Quick Actions panel on the right side

**Check 3**: Check browser console for errors
- Press F12
- Look for any red error messages
- Common issue: CustomerProvider not initialized

### Button Shows But Doesn't Work?

**Solution**: Refresh the app
```bash
# Hot reload
r

# Or full restart
R
```

### "Route not found" Error?

**Solution**: Verify main.dart has the route
```dart
'/admin/customers/import': (context) => const CustomerImportScreen(),
```

## 📱 Mobile vs Desktop

### Desktop (Recommended)
- Full feature set
- Better layout for CSV review
- Easier error viewing

### Mobile
- Same functionality
- Slightly condensed layout
- File picker uses mobile native picker

## 🎓 Quick Training Script

**For Team Training** (2 minutes):

> "To import customers, go to the Admin Dashboard. On the right side, 
> you'll see Quick Actions. Click the cyan 'Import Customers' button 
> with the upload icon. Download the template first to see the format. 
> Fill in your customer data, then upload the file. The system will 
> check for errors and show you what will be imported. If everything 
> looks good, click Import and you're done!"

## 📞 Need Help?

If the button is not showing up:

1. **Verify setup**: Check that all files were saved
2. **Restart app**: Full restart (not just hot reload)
3. **Check provider**: Ensure CustomerProvider is registered in main.dart
4. **Check route**: Verify route exists in routes map
5. **Check role**: Ensure you're logged in as admin

---

*Last Updated: October 2025*  
*Route: `/admin/customers/import`*  
*File: `lib/screens/admin/customer_import_screen.dart`*
