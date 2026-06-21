# PODSafe Splash Screen and App Icon Setup Guide

This guide will help you set up a custom splash screen and app icon for the PODSafe mobile app.

## Prerequisites

1. **App Icon Image**: A 1024x1024px PNG image with your logo
2. **Splash Screen Image**: A 1080x1920px PNG image (or your logo on transparent background)

## Step 1: Install Required Packages

Add these packages to your `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
  flutter_native_splash: ^2.4.0
```

## Step 2: Prepare Your Images

Create the following directory structure and add your images:

```
assets/
  images/
    logo.png          # Your app logo (1024x1024px recommended)
    splash_logo.png   # Logo for splash screen (can be same as logo.png)
```

## Step 3: Configure App Icon

Add this configuration to your `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo.png"
  min_sdk_android: 21
  
  # Optional: Different icons for different platforms
  # android: "assets/images/logo_android.png"
  # ios: "assets/images/logo_ios.png"
  
  # Optional: Adaptive icon for Android
  adaptive_icon_background: "#0A7E8C"  # PODSafe teal color
  adaptive_icon_foreground: "assets/images/logo.png"
```

## Step 4: Configure Splash Screen

Add this configuration to your `pubspec.yaml`:

```yaml
flutter_native_splash:
  # Background color (PODSafe brand color)
  color: "#0A7E8C"
  
  # Splash screen image
  image: assets/images/splash_logo.png
  
  # Branding image (optional - small logo at bottom)
  # branding: assets/images/branding.png
  
  # Image fill mode
  # Options: contain, cover, fill, fitHeight, fitWidth, none, scaleDown
  image_mode: contain
  
  # Platforms
  android: true
  ios: true
  web: false
  
  # Android specific
  android_12:
    image: assets/images/splash_logo.png
    color: "#0A7E8C"
    icon_background_color: "#0A7E8C"
  
  # iOS specific
  fullscreen: true
```

## Step 5: Run the Setup Commands

### Install packages:
```bash
flutter pub get
```

### Generate app icons:
```bash
flutter pub run flutter_launcher_icons
```

### Generate splash screens:
```bash
flutter pub run flutter_native_splash:create
```

## Step 6: Design Recommendations

### App Icon Design:
- **Size**: 1024x1024px
- **Format**: PNG with transparency
- **Content**: 
  - Simple, recognizable logo
  - Avoid text (may become unreadable at small sizes)
  - Use PODSafe brand colors (#0A7E8C teal)
  - Leave padding around edges (avoid cutting off)
  
### Splash Screen Design:
- **Size**: 1080x1920px (or any 9:16 ratio)
- **Format**: PNG with transparency preferred
- **Content**:
  - Centered logo
  - Clean, professional look
  - Brand color background (#0A7E8C)
  - Optional: Company name text below logo

## Quick Setup with Default Flutter Icon

If you don't have custom images yet, you can create a simple placeholder:

1. Use a free logo generator like:
   - Canva (https://www.canva.com)
   - LogoMakr (https://logomakr.com)
   - Hatchful (https://hatchful.shopify.com)

2. Design tips:
   - Use a truck/delivery icon
   - Include "PODSafe" text
   - Use teal (#0A7E8C) and white colors
   - Export as 1024x1024px PNG

## Testing

### Test App Icon:
```bash
# Build and run on device
flutter run -d <device-id>
```

Check the home screen for your new icon.

### Test Splash Screen:
```bash
# Kill the app completely
# Cold start the app to see splash screen
flutter run -d <device-id>
```

The splash screen appears during app initialization.

## Troubleshooting

### App icon not updating:
```bash
# Clean build
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
flutter run
```

### Splash screen not showing:
```bash
# Regenerate splash
flutter pub run flutter_native_splash:create
flutter clean
flutter run
```

### Android: Icon still showing default:
- Uninstall the app completely from device
- Rebuild and reinstall

### iOS: Icon not updating:
- Clean build folder in Xcode
- Delete app from simulator/device
- Rebuild

## Color Scheme for PODSafe

Based on your app's theme:

- **Primary Color**: `#0A7E8C` (Teal)
- **Success Color**: `#10B981` (Green)
- **Warning Color**: `#F59E0B` (Orange)
- **Error Color**: `#EF4444` (Red)
- **Background**: `#FFFFFF` (White)
- **Text**: `#1F2937` (Dark Gray)

## Example Icon Concepts

1. **Truck with Shield**: Delivery truck + security shield icon
2. **Package with Checkmark**: Parcel + POD verification
3. **Location Pin + Truck**: Navigation + delivery theme
4. **Simple "PS" Monogram**: Clean text-based logo

## Maintenance

### Updating Icons:
1. Replace `assets/images/logo.png` with new design
2. Run: `flutter pub run flutter_launcher_icons`
3. Rebuild app

### Updating Splash Screen:
1. Replace `assets/images/splash_logo.png` with new design
2. Run: `flutter pub run flutter_native_splash:create`
3. Rebuild app

## Production Checklist

Before releasing:
- ✅ Test icon on both Android and iOS devices
- ✅ Verify icon looks good at all sizes
- ✅ Test splash screen on different screen sizes
- ✅ Check splash screen duration (should be quick)
- ✅ Ensure no copyrighted images are used
- ✅ Test on both light and dark mode devices

---

**Next Steps:**
1. Create or source your logo design
2. Add images to `assets/images/` folder
3. Update `pubspec.yaml` with configurations above
4. Run the generation commands
5. Test on real devices

For more information:
- Flutter Launcher Icons: https://pub.dev/packages/flutter_launcher_icons
- Flutter Native Splash: https://pub.dev/packages/flutter_native_splash
