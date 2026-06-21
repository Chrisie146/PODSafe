# Fix: setState() Called During Build

## 🐛 Issue
**Error**: "setState() or markNeedsBuild() called during build"

The CustomerProvider was calling `notifyListeners()` during the widget's build phase when initializing in `initState`.

## ✅ Solution Applied

### Fix 1: Delay Initialization (customer_import_screen.dart)

**Before**:
```dart
@override
void initState() {
  super.initState();
  _initializeProvider(); // Called immediately during build
}
```

**After**:
```dart
@override
void initState() {
  super.initState();
  // Delay until after build phase completes
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeProvider();
  });
}
```

### Fix 2: Guard notifyListeners (customer_provider.dart)

**Before**:
```dart
Future<void> loadCustomers() async {
  _isLoading = true;
  notifyListeners(); // Always called, even during build
  // ... load data
  _isLoading = false;
  notifyListeners(); // Always called
}
```

**After**:
```dart
Future<void> loadCustomers() async {
  _isLoading = true;
  if (hasListeners) notifyListeners(); // Only if safe
  // ... load data
  _isLoading = false;
  if (hasListeners) notifyListeners(); // Only if safe
}
```

## 🔧 What Changed

1. **Import Screen**: Initialization now happens **after** the first frame is rendered using `addPostFrameCallback`
2. **Customer Provider**: Only calls `notifyListeners()` when there are actual listeners attached (checked with `hasListeners`)

## 📋 Technical Details

### Why This Happened

Flutter's build process:
1. Widget enters tree → `initState()` called
2. Widget builds for first time
3. Provider becomes available

**Problem**: We were trying to notify listeners during step 1-2, before the widget tree was ready.

**Solution**: Wait for step 3 to complete, then initialize.

### WidgetsBinding.addPostFrameCallback

This callback runs **after** the current frame is rendered, ensuring:
- ✅ Widget tree is fully built
- ✅ Provider listeners are attached
- ✅ Safe to call `notifyListeners()`

### hasListeners Check

The `hasListeners` getter (from `ChangeNotifier`) returns:
- `true` - Widgets are listening, safe to notify
- `false` - No listeners yet, skip notification

## 🚀 Try Again

1. **Hot reload** your app (press `r`)
2. **Navigate** to Admin Dashboard → Import Customers
3. **No error** should appear! ✅
4. **Upload CSV** should work normally

## 🎯 Expected Behavior

**On Screen Load**:
1. Screen builds with loading indicator
2. **After first frame**: Provider initializes
3. Customers load from Firestore
4. Screen updates to show upload view
5. **No errors** in console

## 🔍 Verification

Check browser console (F12):
- ❌ **Before**: Red error about setState during build
- ✅ **After**: No errors, clean initialization

## 📝 Best Practice

When initializing providers in `initState`:

**✅ DO**:
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Initialize provider here
  });
}
```

**❌ DON'T**:
```dart
@override
void initState() {
  super.initState();
  // Initialize provider directly - causes setState during build
}
```

## 🎓 Alternative Approaches

### Option 1: FutureBuilder (not used here)
```dart
FutureBuilder(
  future: _initializeProvider(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget();
    }
    return UploadWidget();
  },
)
```

### Option 2: listen: false (partial solution)
```dart
Provider.of<CustomerProvider>(context, listen: false)
  .initialize(companyId);
```

### Our Solution: PostFrameCallback ✅
Most reliable - guarantees execution after build completes.

---

*Fix Applied: October 2025*  
*Issue: setState during build*  
*Root Cause: initState calling provider methods immediately*  
*Solution: Delayed initialization + listener guards*
