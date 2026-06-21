# Map Integration - Visual Overview

## Component: LocationMapWidget

```
┌─────────────────────────────────────────────────────┐
│  Info Card (Top-Left Overlay)                      │
│  ┌─────────────────────────────────────────┐       │
│  │ 📍 40.712776, -74.005974                │       │
│  │ 🎯 Accuracy: 25.5m                      │       │
│  │ 🏢 123 Main St, New York, NY            │       │
│  └─────────────────────────────────────────┘       │
│                                                     │
│  ╔════════════════════════════════════════╗        │
│  ║                                        ║        │
│  ║   [Tile Layer: OpenStreetMap]          ║        │
│  ║                                        ║        │
│  ║      ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~       ║        │
│  ║    ~ Accuracy Circle (blue) ~          ║        │
│  ║   ~            📍 Marker     ~         ║        │
│  ║    ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~         ║        │
│  ║                                        ║        │
│  ║           [Pan the map]                ║        │
│  ╚════════════════════════════════════════╝       │
│                                        ┌─────┐    │
│                                        │ [+] │    │
│        Zoom Controls (Right)          │[-]  │    │
│                                        │[ ]  │    │
│                                        └─────┘    │
└─────────────────────────────────────────────────────┘
```

---

## Integration Points

### Mobile View (claim_details_screen.dart)
```
Location Section
├── Coordinates Row: "Lat: X, Lng: Y"
└── LocationMapWidget (height: 250px) ← NEW
```

### Desktop View (claim_details_desktop.dart)
```
GPS Location Card
├── Text: "Lat: X, Lng: Y"
└── LocationMapWidget (height: 200px) ← NEW
```

---

## Data Structure

```dart
// From Claim model
gpsLocation: {
  'latitude': 40.712776,        // Required
  'longitude': -74.005974,       // Required
  'accuracy': 25.5,              // Optional (meters)
  'address': 'Main St, NYC'      // Optional
}

↓ Passed to Widget ↓

LocationMapWidget(
  latitude: 40.712776,
  longitude: -74.005974,
  accuracy: 25.5,
  address: 'Main St, NYC',
  height: 250,
  showAccuracyCircle: true,
)
```

---

## Feature Highlights

### 🎨 Visual Elements
- **Marker**: PODSafe teal pin at exact GPS location
- **Accuracy Circle**: Blue circle showing GPS uncertainty range
- **Info Card**: Semi-transparent white box with details
- **Zoom Controls**: Three floating buttons (+ / - / center)

### ⚙️ Interactions
- **Pan**: Drag map to move
- **Zoom In**: Click [+] or scroll up
- **Zoom Out**: Click [-] or scroll down
- **Center**: Click [📍] to return to marker

### 📊 Data Display
- **Coordinates**: 6 decimal places (±0.1m precision)
- **Accuracy**: Shows GPS accuracy in meters
- **Address**: Reverse geocoded address (if available)

---

## Integration with Claims

### Current Status
```
✅ Mobile claim_details_screen.dart
   └─ LocationMapWidget integrated
   
✅ Desktop claim_details_desktop.dart
   └─ LocationMapWidget integrated
   
⏳ Mobile pod_details_screen.dart
   └─ Ready for integration (same pattern)
   
⏳ Desktop pod_viewer_desktop.dart
   └─ Ready for integration (same pattern)
```

### Testing Checklist
- [ ] Open admin dashboard
- [ ] Navigate to Claims
- [ ] Click a claim with GPS location
- [ ] Verify map displays
- [ ] Try zooming (+/- buttons)
- [ ] Try panning (dragging map)
- [ ] Check info card shows coordinates
- [ ] Check accuracy circle is visible

---

## Performance Notes

- **Map Tiles**: Loaded from OpenStreetMap (free CDN)
- **Caching**: Flutter Map caches tiles locally
- **Web Performance**: Consider installing `flutter_map_cancellable_tile_provider` for web

---

## File Structure

```
lib/
├── widgets/
│   └── location_map_widget.dart ← NEW (240 lines)
├── screens/admin/
│   ├── claim_details_screen.dart (UPDATED)
│   └── claim_details_desktop.dart (UPDATED)
└── pubspec.yaml (UPDATED)
```

---

## Next: Adding to PODs

When ready to add maps to PODs, use the same pattern:

```dart
// In pod_details_screen.dart or pod_viewer_desktop.dart
import '../../widgets/location_map_widget.dart';

// In build method:
if (pod.location != null) ...[
  LocationMapWidget(
    latitude: pod.location['latitude'],
    longitude: pod.location['longitude'],
    accuracy: pod.location['accuracy'],
    address: pod.location['address'],
    height: 250,
    showAccuracyCircle: true,
  ),
],
```

---

## Dependencies

```yaml
dependencies:
  flutter_map: ^6.1.0      # Maps library
  latlong2: ^0.9.1         # GPS coordinate handling
```

All installed ✅
