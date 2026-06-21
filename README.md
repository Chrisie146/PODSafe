# 📱 PODSafe - Proof of Delivery Solution

**PODSafe** is a comprehensive business-focused Flutter + Firebase application designed to replace missing or unsigned paper PODs (Proof of Delivery) for companies during audits. The app enables delivery drivers to capture signed, time-stamped, and GPS-verified delivery confirmations that sync instantly to a secure cloud dashboard.

![PODSafe Logo](assets/images/podsafe_logo.png)

## 🎯 Business Goal

Create a professional POD solution that provides:
- **Digital signature capture** with timestamp and GPS verification
- **Photo documentation** of delivered goods
- **Instant cloud synchronization** for real-time tracking
- **Offline capability** for areas with poor connectivity
- **Admin dashboard** for oversight and reporting
- **PDF generation** for professional documentation
- **Audit-ready records** with complete delivery chain of custody

## 🚀 Key Features

### 📱 Mobile App (Driver Interface)
- **Firebase Authentication** for secure driver login
- **Daily delivery list** with offline sync capabilities
- **POD capture screen** with signature pad and photo upload
- **GPS location verification** with accuracy tracking
- **Offline mode** with automatic sync when connection restored
- **Real-time status updates** with confirmation feedback
- **Professional UI** with business-grade design

### 💻 Web Dashboard (Admin Interface)
- **Real-time dashboard** with delivery statistics
- **POD management** with view/download capabilities
- **Driver management** and route assignment
- **Missing POD reporting** with automated follow-up
- **CSV/PDF exports** for accounting integration
- **Company branding** and settings management

## 🛠️ Technology Stack

### Frontend
- **Flutter** 3.8.1+ (Cross-platform mobile development)
- **Provider** (State management)
- **Google Fonts** (Typography)

### Backend & Services
- **Firebase Core** (Backend-as-a-Service)
- **Firebase Auth** (Authentication)
- **Cloud Firestore** (Real-time database)
- **Firebase Storage** (File storage)
- **Cloud Functions** (Server-side logic)

### Hardware Integration
- **Geolocator** (GPS tracking)
- **Image Picker** (Camera integration)
- **Signature** (Digital signature capture)
- **Permission Handler** (Device permissions)

### Utilities
- **PDF Generation** (Document creation)
- **Connectivity Plus** (Network monitoring)
- **Shared Preferences** (Local storage)
- **UUID** (Unique identifier generation)
- **Intl** (Internationalization)

## 📁 Project Structure

```
podsafe/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── user_model.dart       # User/driver data structure
│   │   ├── company_model.dart    # Company information
│   │   ├── delivery_model.dart   # Delivery details
│   │   └── pod_model.dart        # POD record structure
│   ├── services/                 # Business logic layer
│   │   ├── auth_service.dart     # Authentication handling
│   │   ├── delivery_service.dart # Delivery management
│   │   ├── pod_service.dart      # POD operations
│   │   ├── location_service.dart # GPS and location
│   │   └── offline_service.dart  # Offline sync management
│   ├── providers/                # State management
│   │   ├── auth_provider.dart    # Authentication state
│   │   ├── delivery_provider.dart# Delivery state
│   │   └── pod_provider.dart     # POD state management
│   ├── screens/                  # UI screens
│   │   ├── auth/                 # Login and authentication
│   │   ├── driver/               # Driver interface screens
│   │   └── admin/                # Admin screens
│   ├── widgets/                  # Reusable UI components
│   │   ├── custom_text_field.dart# Styled input fields
│   │   └── custom_button.dart    # Styled buttons
│   └── utils/                    # Utilities and constants
│       └── theme.dart            # App theming and colors
├── assets/                       # Static assets
│   ├── images/                   # Images and logos
│   └── icons/                    # Custom icons
├── admin_web_dashboard/          # Web admin interface
│   ├── index.html                # Admin dashboard
│   └── README.md                 # Web dashboard docs
├── android/                      # Android-specific files
├── ios/                          # iOS-specific files
└── pubspec.yaml                  # Flutter dependencies
```

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK** 3.8.1 or higher
- **Dart SDK** 3.0.0 or higher
- **Android Studio** / **VS Code** with Flutter extensions
- **Firebase account** with billing enabled (for Cloud Functions)

### 1. Clone and Setup
```bash
# Clone the repository
git clone <repository-url>
cd podsafe

# Install Flutter dependencies
flutter pub get

# Check Flutter setup
flutter doctor
```

### 2. Firebase Configuration

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: "PODSafe Production"
3. Enable Google Analytics (recommended)

#### Configure Authentication
```bash
# Enable Email/Password authentication
firebase auth:import users.json --hash-algo=scrypt
```

#### Setup Firestore Database
```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Company data access
    match /companies/{companyId} {
      allow read, write: if request.auth != null && 
        resource.data.members[request.auth.uid] != null;
    }
    
    // Deliveries - drivers can read assigned deliveries
    match /deliveries/{deliveryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (resource.data.driverId == request.auth.uid || 
         resource.data.companyId in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.companies);
    }
    
    // PODs - drivers can create, admins can read all
    match /pods/{podId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null && request.auth.uid == resource.data.driverId;
      allow update: if request.auth != null;
    }
  }
}
```

#### Configure Firebase Storage
```javascript
// Storage Security Rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /signatures/{deliveryId}/{fileName} {
      allow read, write: if request.auth != null;
    }
    match /photos/{deliveryId}/{fileName} {
      allow read, write: if request.auth != null;
    }
    match /pdfs/{deliveryId}/{fileName} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 3. Environment Setup

Create `lib/firebase_options.dart`:
```dart
// This file is auto-generated by FlutterFire CLI
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'your-web-api-key',
    appId: 'your-web-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'your-android-api-key',
    appId: 'your-android-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'your-ios-api-key',
    appId: 'your-ios-app-id',
    messagingSenderId: 'your-sender-id',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.appspot.com',
    iosClientId: 'your-ios-client-id',
    iosBundleId: 'com.yourcompany.podsafe',
  );
}
```

### 4. Run the Application
```bash
# Debug mode
flutter run

# Release mode
flutter run --release

# Specific device
flutter run -d chrome    # Web
flutter run -d android   # Android
flutter run -d ios       # iOS
```

## 🏗️ Database Schema

### Firestore Collections

#### Companies Collection
```javascript
companies/{companyId} {
  name: "ACME Logistics Ltd",
  address: "123 Business St, City, State 12345",
  contactEmail: "admin@acme.com",
  phoneNumber: "+1-555-0123",
  logoUrl: "gs://bucket/logos/acme.png",
  settings: {
    requireGPS: true,
    requirePhoto: true,
    requireSignature: true,
    emailNotifications: true
  },
  isActive: true,
  createdAt: timestamp
}
```

#### Users Collection
```javascript
users/{userId} {
  email: "driver@company.com",
  fullName: "John Driver",
  role: "driver", // "admin" | "driver"
  companyId: "company123",
  phoneNumber: "+1-555-0456",
  profileImageUrl: "gs://bucket/profiles/user.jpg",
  isActive: true,
  createdAt: timestamp,
  lastLoginAt: timestamp
}
```

#### Deliveries Collection
```javascript
deliveries/{deliveryId} {
  companyId: "company123",
  driverId: "driver456",
  customerName: "XYZ Manufacturing",
  customerAddress: "456 Industrial Ave, City, State",
  customerPhone: "+1-555-0789",
  invoiceNumber: "INV-001234",
  items: [
    {
      description: "Steel pipes - 20ft",
      quantity: 25,
      unit: "pieces"
    }
  ],
  status: "pending", // "pending" | "inTransit" | "delivered" | "failed"
  scheduledDate: timestamp,
  createdAt: timestamp,
  deliveredAt: timestamp,
  notes: "Handle with care - fragile items",
  podId: "pod789" // Link to POD record
}
```

#### PODs Collection
```javascript
pods/{podId} {
  companyId: "company123",
  driverId: "driver456",
  deliveryId: "delivery789",
  customerName: "XYZ Manufacturing",
  invoiceNumber: "INV-001234",
  status: "signed", // "pending" | "signed" | "missing"
  timestamp: timestamp,
  location: {
    latitude: 40.7128,
    longitude: -74.0060,
    address: "456 Industrial Ave, City, State",
    accuracy: 5.0 // meters
  },
  signedBy: "John Receiver",
  signatureUrl: "gs://bucket/signatures/pod789.png",
  photoUrl: "gs://bucket/photos/pod789.jpg",
  pdfUrl: "gs://bucket/pdfs/pod789.pdf",
  metadata: {
    deviceInfo: "iPhone 12 Pro",
    appVersion: "1.0.0",
    batteryLevel: 85
  },
  createdAt: timestamp,
  updatedAt: timestamp
}
```

## 📱 Mobile App Usage

### Driver Workflow
1. **Login** with company-provided credentials
2. **View daily deliveries** assigned by dispatcher
3. **Navigate to delivery location** using integrated maps
4. **Capture POD** when delivery is complete:
   - Take photo of delivered goods
   - Obtain customer signature on device
   - Verify GPS location is accurate
   - Add any delivery notes
5. **Submit POD** - automatically syncs to cloud
6. **Receive confirmation** and move to next delivery

### Admin Workflow
1. **Access web dashboard** with admin credentials
2. **Monitor real-time** delivery progress
3. **Track POD completion** rates and missing PODs
4. **Manage drivers** and delivery assignments
5. **Generate reports** for accounting and audit purposes
6. **Export data** for integration with other systems

## 🌐 Web Dashboard

The admin web dashboard provides:

- **Real-time Analytics Dashboard**
  - Total deliveries today/week/month
  - POD completion percentage
  - Missing PODs requiring follow-up
  - Driver performance metrics

- **Delivery Management**
  - View all deliveries with filtering
  - Search by customer, invoice, or driver
  - Update delivery status manually
  - Assign deliveries to drivers

- **POD Records**
  - View signed PODs with images
  - Download PDF versions
  - Follow up on missing PODs
  - Bulk export for reporting

- **Driver Management**
  - Add/edit driver accounts
  - View driver statistics
  - Manage permissions and access

See [admin_web_dashboard/README.md](admin_web_dashboard/README.md) for detailed setup instructions.

## 🔌 Integration Capabilities

### Accounting Software Integration
- **Xero**: Export delivery data and POD status
- **Sage**: Sync invoice numbers and completion status
- **QuickBooks**: Import delivery records for billing

### API Endpoints (Future)
```
GET /api/deliveries?date=2024-01-15
POST /api/deliveries
PUT /api/deliveries/{id}/status
GET /api/pods/{deliveryId}
POST /api/pods
GET /api/reports/missing-pods
```

### Webhook Support (Future)
- POD completion notifications
- Missing POD alerts
- Delivery status changes
- Driver check-in/check-out

## 🚀 Deployment

### Mobile App Distribution

#### Android (Google Play Store)
```bash
# Build release APK
flutter build apk --release

# Build App Bundle (recommended)
flutter build appbundle --release

# Upload to Google Play Console
```

#### iOS (Apple App Store)
```bash
# Build iOS release
flutter build ios --release

# Use Xcode to upload to App Store Connect
open ios/Runner.xcworkspace
```

#### Internal Distribution
```bash
# Build APK for direct distribution
flutter build apk --release --split-per-abi

# Generate QR codes for easy installation
```

### Web Dashboard Deployment

#### Firebase Hosting
```bash
cd admin_web_dashboard
firebase init hosting
firebase deploy --only hosting
```

#### Custom Server
```bash
# Copy files to web server
scp -r admin_web_dashboard/* user@server:/var/www/podsafe/
```

## 🧪 Testing

### Unit Tests
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/models/pod_model_test.dart

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Integration Tests
```bash
# Run integration tests
flutter drive --target=test_driver/app.dart
```

### Manual Testing Checklist

#### Core Functionality
- [ ] User authentication (login/logout)
- [ ] Delivery list loading and refresh
- [ ] POD capture (signature, photo, GPS)
- [ ] Offline mode and sync
- [ ] Data validation and error handling

#### Edge Cases
- [ ] Poor network connectivity
- [ ] GPS permission denied
- [ ] Camera permission denied
- [ ] Storage space full
- [ ] Battery optimization interference

## 📈 Performance Optimization

### Mobile App
- **Image compression** before upload
- **Lazy loading** for delivery lists
- **Background sync** for offline data
- **Battery optimization** handling
- **Memory management** for large images

### Web Dashboard
- **Pagination** for large datasets
- **Caching** of frequently accessed data
- **Compression** of assets
- **CDN usage** for static resources

## 🔒 Security Best Practices

### Authentication
- **Multi-factor authentication** for admin accounts
- **Session management** with timeout
- **Role-based access control**
- **Secure password requirements**

### Data Protection
- **End-to-end encryption** for sensitive data
- **HTTPS only** communication
- **Input validation** on all forms
- **SQL injection prevention**
- **XSS protection**

### Privacy Compliance
- **GDPR compliance** for EU users
- **CCPA compliance** for California users
- **Data retention policies**
- **Right to deletion**

## 🐛 Troubleshooting

### Common Issues

#### Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk
```

#### Firebase Connection Issues
```bash
# Verify configuration
flutterfire configure
```

#### Permission Problems
```bash
# Check Android permissions in android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Performance Issues
- Check Firebase quotas and billing
- Monitor Firestore read/write operations
- Optimize image sizes and compression
- Review offline data storage limits

## 🛣️ Future Roadmap

### Phase 1: Core Enhancement (Q1 2024)
- [ ] Advanced signature capture with pressure sensitivity
- [ ] Multiple photo support per delivery
- [ ] Voice notes recording
- [ ] Barcode/QR code scanning for package verification

### Phase 2: Analytics & Reporting (Q2 2024)
- [ ] Advanced analytics dashboard
- [ ] Predictive delivery time estimates
- [ ] Driver performance scoring
- [ ] Customer satisfaction tracking

### Phase 3: Integration Expansion (Q3 2024)
- [ ] API for third-party integrations
- [ ] Webhook system for real-time notifications
- [ ] Advanced export formats (JSON, XML)
- [ ] Accounting software plugins

### Phase 4: AI & Automation (Q4 2024)
- [ ] AI-powered route optimization
- [ ] Automatic POD quality verification
- [ ] Smart delivery time predictions
- [ ] Fraud detection for signatures

### Phase 5: Enterprise Features (2025)
- [ ] Multi-tenant architecture
- [ ] White-label customization
- [ ] Advanced user management
- [ ] Enterprise security features

## 👥 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Style
- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart)
- Use `flutter format` before committing
- Add documentation for public APIs
- Write unit tests for business logic

### Pull Request Process
1. Update README.md with details of changes
2. Ensure all tests pass
3. Update version numbers following [Semantic Versioning](https://semver.org/)
4. Get approval from code owners

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support & Contact

### Technical Support
- **Email**: support@podsafe.com
- **Documentation**: [docs.podsafe.com](https://docs.podsafe.com)
- **Issue Tracking**: GitHub Issues

### Business Inquiries
- **Sales**: sales@podsafe.com  
- **Partnerships**: partners@podsafe.com
- **Phone**: +1-555-PODSAFE

### Community
- **Discord**: [PODSafe Community](https://discord.gg/podsafe)
- **LinkedIn**: [@PODSafe](https://linkedin.com/company/podsafe)
- **Twitter**: [@PODSafeApp](https://twitter.com/podsafeapp)

---

**Built with ❤️ for logistics and delivery professionals**

*Making every delivery accountable, every POD verifiable, and every audit successful.*
