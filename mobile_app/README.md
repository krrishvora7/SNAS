# SNAS Mobile App

Smart NFC Attendance System - Flutter Mobile Application

## Setup

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Android Studio / Xcode for platform-specific development
- Supabase project with URL and anon key

### Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Configure environment variables:

Create a `.env` file or pass environment variables when running:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key

### Running the App

With environment variables:
```bash
flutter run --dart-define=SUPABASE_URL=your_url --dart-define=SUPABASE_ANON_KEY=your_key
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── auth_result.dart
├── services/                 # Business logic services
│   ├── auth_service.dart
│   ├── device_service.dart
│   └── device_binding_service.dart
└── screens/                  # UI screens
    ├── login_screen.dart
    └── home_screen.dart
```

## Features Implemented

### Task 5: Authentication Module ✓
- ✓ 5.1: Authentication service with Supabase Auth
- ✓ 5.2: Device binding logic
- ✓ 5.3: Login screen UI

## Authentication Flow

1. User enters email and password
2. App authenticates with Supabase Auth
3. App checks device binding:
   - First login: Binds device ID to profile
   - Subsequent logins: Verifies device ID matches
   - Device mismatch: Rejects login
4. On success: Navigate to home screen
5. On failure: Display error message

## Device Binding

The app uses platform-specific device identifiers:
- **Android**: Android ID
- **iOS**: identifierForVendor

Device binding ensures one account can only be used on one device at a time.

## Next Steps

- Task 6: Implement NFC scanner module
- Task 7: Implement GPS module
- Task 8: Implement API client module
- Task 9: Implement UI screens
