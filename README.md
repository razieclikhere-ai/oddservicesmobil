# Smart OBD Service Assistant

## Overview

A professional-grade multi-platform vehicle diagnostic application featuring an AI-powered health monitoring system with real-time OBD-II data analysis, predictive maintenance, and comprehensive vehicle management capabilities.

## Features

### Core Functionality
- **Multi-Platform**: Android, iOS, Windows, Linux, Web
- **OBD-II Connectivity**: Bluetooth Low Energy (BLE), Bluetooth Classic, Wi-Fi ELM327, USB OTG
- **AI Analysis**: Real-time vehicle health scoring and predictive maintenance alerts
- **Multi-Vehicle Management**: Unlimited vehicles per user account
- **Driver/Diagnostic History**: Complete scan records and health tracking
- **Service Scheduling**: Automatic reminders and maintenance planning
- **Report Generation**: PDF reports with analytics and recommendations
- **AI Chatbot**: Natural language assistant for diagnostics and maintenance

### Key Screens
- **Dashboard**: Vehicle health score, component status, live graphs, scan history
- **Vehicles**: Vehicle management, profile editing, vehicle-specific settings
- **OBD Scanner**: Live data monitoring, PID scanning, scan controls
- **AI Analyzer**: Detailed AI results, risk assessments, recommendations
- **Service Schedule**: Maintenance history, future services, deadlines
- **Reports**: View, generate, and export diagnostic reports
- **Chatbot**: AI assistant for vehicle questions and diagnostics

## Technology Stack

### Frontend Framework
- **Flutter**: Multi-platform UI with fast development cycles
- **Riverpod**: State management and dependency injection
- **GoRouter**: Modern navigation system

### Database
- **Drift (SQLite)**: Local offline-first database with change tracking
- **Supabase**: Cloud backend for data sync and real-time updates

### Connectivity
- **flutter_blue_plus**: Bluetooth LE integration
- **permission_handler**: Runtime permission management
- **usb_serial**: USB OTG support for ELM327 adapters
- **dio**: Network communications for cloud services

### Analytics & AI
- **fl_chart**: Interactive data visualizations and live graphs
- **pdf_report**: PDF generation for reports and records
- **printing**: System print integration
- **Image Processing**: QR code generation and visual symbology

### Notifications
- **flutter_local_notifications**: Local notification system with timezone support
- **timezone**: Time zone handling for global service scheduling

### Material Design
- **Material3**: Latest Material Design system with dark mode support
- **Custom Automotive Widgets**: Specialized UI components for automotive applications

### Localization
- **Multilingual Support**: English, Spanish, French, and many other languages
- **RTL Support**: Bidirectional text support for right-to-left languages

## Key Features

### Vehicle Health Scoring
- 0-100% comprehensive health assessment
- Based on mileage, scan history, and current OBD data
- Weighting of various components and systems

### Component Monitoring
- **Critical Systems**: Engine, Battery, Brakes, Transmission, Coolant, Oil, Sensors
- **Visual Indicators**: 🟢 Normal, 🟡 Attention Required, 🔴 Immediate Service
- **Real-time Gauges**: Live scrolling graphs and current readings

### Predictive Maintenance
- **AI-Powered Analysis**: Risk assessment based on hundreds of parameters
- **Pattern Recognition**: Detection of emerging issues before symptoms appear
- **Dynamic Scheduling**: Personalized service intervals based on actual usage

### OBD-II Scanning
- **Standard PIDs**: Standard Mode (00-0F, 10-1F, 20-2F, etc.)
- **Enhanced PIDs**: Manufacturer-specific Mode 22, 31, etc.
- **Freeze Frame Capture**: Diagnostic snapshots for troubleshooting
- **Custom PID Library**: User-defined parameters and formulas

### Multi-Vehicle Management
- **Unified Dashboard**: All vehicles at a glance
- **Vehicle Switching**: Quick switch between multiple vehicles
- **Separate Profiles**: Unique settings, scans, and schedules per vehicle

### Advanced Analytics
- **Trend Analysis**: Historical patterns and predictions
- **Correlation Analysis**: Links between parameters and system health
- **Predictive Modeling**: Machine learning for early problem detection
- **Comparative Analysis**: Track changes over time

### Cloud Integration
- **Real-time Sync**: Instant updates across devices
- **Multi-Device Support**: Use with multiple OBD adapters
- **Backup & Recovery**: Secure cloud backup of all vehicle data
- **Shared Access**: Family and fleet management support

## Architecture

### Models
- **Core Data Models**: Vehicles, Scans, Trouble Codes, Live Data, Freeze Frames
- **Service Models**: Service Records, Schedules, Profiles, Analysis Results
- **User Models**: User Preferences, Scan Templates

### Services
- **OBD Service**: Device connection, data parsing, and communication protocols
- **AI Analysis Service**: Machine learning models and heuristic algorithms
- **Database Service**: Local persistence with SQLite/Diff
- **Sync Service**: Supabase integration and real-time data sync
- **Notification Service**: Intelligent scheduling and local notifications

### Widgets
- **Specialized Widgets**: Car health score meter, component status indicators, live charts
- **Data Visualization**: Advanced graph components and live scrolling displays
- **Responsive UI**: Adaptive layouts for all screen sizes

### Screens
- **Dashboard**: Primary interface with all essential information
- **Diagnostic Screens**: Comprehensive OBD scanning and analysis
- **Management Screens**: Vehicle, service, and user profile management
- **Analytics Screens**: Data visualization and insights

## Getting Started

### Prerequisites
- Flutter 3.2+ (Dart SDK included)
- Android Studio, VS Code, or any IDE with Flutter support
- Windows 10+, macOS 12+, Linux (iOS requires macOS)

### Installation
```bash
# Clone the repository
git clone https://github.com/username/smart-obd-assistant.git
cd smart-obd-assistant

# Install dependencies
flutter pub get

# Run on Android
flutter run --device

# Run on iOS (requires macOS)
flutter run --platform ios

# Run on Windows
flutter run --platform windows

# Run on Linux
flutter run --platform linux

# Run on Web
flutter run --platform web
```

### Running Tests
```bash
# Unit tests
flutter test

# Integration tests (requires emulator/device)
flutter drive --test-cases test_driver/main_test.dart

# Widget tests
flutter test --platform linux
```

## Design Patterns

### State Management
- **Riverpod**: Provider-based state management with auto-dispose
- **Provider Scope**: Scoped providers for screen-specific state
- **Async State**: First-class support for async operations

### Database
- **Drift**: Type-safe SQL with code generation
- **Table Objects**: Data classes with validation and computed properties
- **Migrations**: Version-controlled database schema changes

### Networking
- **Repository Pattern**: Data layer abstraction and caching
- **Interceptors**: Request/response logging and error handling
- **Real-time Updates**: WebSocket connections for instant data

### UI
- **Widget Composition**: Composable, reusable UI components
- **State Delegation**: Widget state managed by providers
- **Responsive Design**: Adaptive layouts across devices

## Testing

### Unit Tests
- **Core Logic**: AI analysis algorithms and OBD parsing
- **UI Widgets**: Custom animations and visual components
- **Service Layer**: Database operations and network communication

### Integration Tests
- **Local Database**: End-to-end testing with SQLite
- **Authentication**: User authentication and permissions
- **Real Device Testing**: Bluetooth and OBD connectivity

### Performance
- **Lazy Loading**: Efficient data loading and pagination
- **Caching**: Strategic caching of frequently accessed data
- **Memory Management**: Proper disposal of providers and resources

## Firebase Configuration

If using Firebase services (Analytics, Crashlytics, etc.), add `android/app/src/main/res/xml/file_paths.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<matrix>
    <package name="com.smart.obd" />
</matrix>
```

```yaml
# android/app/build.gradle
plugins {
    id "com.google.gms.google-services" version "4.4.0" apply false
}

dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.8.0')
    implementation 'com.google.firebase:firebase-analytics'
    implementation 'com.google.firebase:firebase-crashlytics'
    implementation 'com.google.firebase:firebase-firestore'
}
```

## Environment Variables

Create `.env` file in the project root:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Authentication
SUPABASE_AUTH_EMAIL=email@example.com

# Logging
LOG_LEVEL=debug

# Notifications
FCM_SERVER_KEY=your-fcm-server-key

# Analytics
GOOGLE_ANALYTICS_ID=UA-XXXXXXXXX-X
```

## GitHub Actions

View `.github/workflows/build-android.yml` for continuous integration setup.

## Future Enhancements

### Phase 2
- **Enterprise Features**: Fleet management, team collaboration
- **Advanced AI**: Deep learning models for predictive maintenance
- **Integration**: Third-party APIs (weather, traffic, parts pricing)
- **Plugins**: Extensible plugin system for OBD adapters

### Phase 3
- **Cross-Platform Native**: Better integration with platform-specific APIs
- **Advanced ML**: Custom-trained models for specific vehicle makes/models
- **AR Integration**: Augmented reality diagnostics guidance
- **IoT Integration**: Smart vehicle monitoring and IoT device integration

## References

1. **Flutter Documentation**: https://flutter.dev/docs
2. **Riverpod**: https://riverpod.dev
3. **Go Router**: https://github.com/go_router/go_router
4. **Drift**: https://github.com/simolus3/drift
5. **Supabase**: https://supabase.io
6. **Material Design**: https://m3.material.io

## Credits

- **Development Team**: Smart OBD Team
- **Libraries**: Flutter, FlutterFire, open-source community
- **Design**: Material Design 3, automotive industry standards
- **Data**: Custom OBD-II protocol support, multiplatform vehicles

This project is licensed under the MIT License - see the LICENSE file for details.