# Smart NFC Attendance System - Complete Setup Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Supabase Backend Setup](#supabase-backend-setup)
4. [Mobile App Setup](#mobile-app-setup)
5. [Admin Dashboard Setup](#admin-dashboard-setup)
6. [NFC Tag Configuration](#nfc-tag-configuration)
7. [Testing the System](#testing-the-system)
8. [Troubleshooting](#troubleshooting)
9. [Production Deployment](#production-deployment)

## Overview

The Smart NFC Attendance System (SNAS) consists of three main components:

1. **Supabase Backend**: PostgreSQL database with PostGIS, RPC functions, and authentication
2. **Flutter Mobile App**: Cross-platform app for students to mark attendance via NFC
3. **Next.js Admin Dashboard**: Web interface for real-time attendance monitoring

**Architecture**:
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Mobile App     │────▶│  Supabase        │◀────│ Admin Dashboard │
│  (Flutter)      │     │  Backend         │     │  (Next.js)      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                        │
        │                        │
        ▼                        ▼
┌─────────────────┐     ┌──────────────────┐
│  NFC Tags       │     │  PostgreSQL +    │
│  (NTAG213)      │     │  PostGIS         │
└─────────────────┘     └──────────────────┘
```

## Prerequisites

### Required Software

1. **Supabase Account**
   - Sign up at [supabase.com](https://supabase.com)
   - Free tier is sufficient for development

2. **Flutter SDK** (for mobile app)
   - Version: 3.0.0 or higher
   - Download: [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Verify installation: `flutter doctor`

3. **Node.js** (for admin dashboard)
   - Version: 18.x or higher
   - Download: [nodejs.org](https://nodejs.org)
   - Verify installation: `node --version`

4. **Git**
   - Download: [git-scm.com](https://git-scm.com)

5. **Code Editor**
   - VS Code (recommended) or Android Studio

### Optional Tools

- **Supabase CLI**: For local development and migrations
  ```bash
  npm install -g supabase
  ```

- **PostgreSQL Client**: For direct database access
  - pgAdmin, DBeaver, or psql command-line tool

- **NFC Tools App**: For programming NFC tags
  - Android: [NFC Tools](https://play.google.com/store/apps/details?id=com.wakdev.wdnfc)
  - iOS: [NFC Tools](https://apps.apple.com/app/nfc-tools/id1252962749)

## Supabase Backend Setup

### Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click "New Project"
3. Fill in project details:
   - **Name**: `snas-production` (or your preferred name)
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: Choose closest to your users
   - **Pricing Plan**: Free (for development)
4. Click "Create new project"
5. Wait 2-3 minutes for project initialization

### Step 2: Get Project Credentials

1. In your Supabase project dashboard, go to **Settings** → **API**
2. Copy and save these values:
   - **Project URL**: `https://xxxxxxxxxxxxx.supabase.co`
   - **anon/public key**: `eyJhbGc...` (long JWT token)
   - **service_role key**: `eyJhbGc...` (keep this secret!)

### Step 3: Enable PostGIS Extension

1. In Supabase dashboard, go to **Database** → **Extensions**
2. Search for "postgis"
3. Click "Enable" next to PostGIS
4. Wait for activation (30 seconds)

### Step 4: Run Database Migrations

#### Option A: Using Supabase Dashboard (Recommended for beginners)

1. Go to **SQL Editor** in Supabase dashboard
2. Run migrations in order:

**Migration 1: Profiles Table**
```sql
-- Copy contents from: supabase/migrations/20240101000000_create_profiles_table.sql
-- Paste and click "Run"
```

**Migration 2: Classrooms Table**
```sql
-- Copy contents from: supabase/migrations/20240101000001_create_classrooms_table.sql
-- Paste and click "Run"
```

**Migration 3: Attendance Logs Table**
```sql
-- Copy contents from: supabase/migrations/20240101000002_create_attendance_logs_table.sql
-- Paste and click "Run"
```

**Migration 4: Mark Attendance Function**
```sql
-- Copy contents from: supabase/migrations/20240101000003_create_mark_attendance_function.sql
-- Paste and click "Run"
```

**Migration 5: Security Enhancements**
```sql
-- Copy contents from: supabase/migrations/20240101000004_create_token_rotation_support.sql
-- Paste and click "Run"
```

**Migration 6: Performance Optimizations**
```sql
-- Copy contents from: supabase/migrations/20240101000005_optimize_performance.sql
-- Paste and click "Run"
```

#### Option B: Using Supabase CLI (Advanced)

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref your-project-ref

# Run all migrations
supabase db push
```

### Step 5: Insert Sample Data

1. Go to **SQL Editor** in Supabase dashboard
2. Run the sample data script:

```sql
-- Insert sample classrooms
INSERT INTO classrooms (id, name, building, location, nfc_secret) VALUES
  (
    '550e8400-e29b-41d4-a716-446655440000',
    'Room 101',
    'Engineering Building',
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    'secret-token-room-101'
  ),
  (
    '550e8400-e29b-41d4-a716-446655440001',
    'Room 201',
    'Science Building',
    ST_GeogFromText('POINT(-122.4184 37.7759)'),
    'secret-token-room-201'
  ),
  (
    '550e8400-e29b-41d4-a716-446655440002',
    'Room 301',
    'Arts Building',
    ST_GeogFromText('POINT(-122.4204 37.7739)'),
    'secret-token-room-301'
  );

-- Verify insertion
SELECT id, name, building, nfc_secret FROM classrooms;
```

### Step 6: Configure Authentication

1. Go to **Authentication** → **Providers** in Supabase dashboard
2. Enable **Email** provider (should be enabled by default)
3. Configure email settings:
   - Go to **Authentication** → **Email Templates**
   - Customize confirmation email (optional)
4. Enable email confirmation:
   - Go to **Authentication** → **Settings**
   - Check "Enable email confirmations"

### Step 7: Create Test User

1. Go to **Authentication** → **Users**
2. Click "Add user" → "Create new user"
3. Fill in:
   - **Email**: `test.student@university.edu`
   - **Password**: `TestPassword123!`
   - **Auto Confirm User**: Check this box (for testing)
4. Click "Create user"
5. Copy the user ID (you'll need this for testing)

### Step 8: Verify Backend Setup

Run verification queries in SQL Editor:

```sql
-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Expected: attendance_logs, classrooms, profiles

-- Check PostGIS is working
SELECT PostGIS_Version();

-- Check indexes
SELECT indexname FROM pg_indexes 
WHERE tablename IN ('attendance_logs', 'classrooms', 'profiles')
ORDER BY tablename, indexname;

-- Check RPC function exists
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'mark_attendance';
```

## Mobile App Setup

### Step 1: Clone and Navigate to Mobile App

```bash
cd mobile_app
```

### Step 2: Install Flutter Dependencies

```bash
# Get Flutter packages
flutter pub get

# Verify no issues
flutter doctor
```

### Step 3: Configure Supabase Credentials

Create a configuration file:

**File**: `mobile_app/lib/config/supabase_config.dart`

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
}
```

Replace with your actual credentials from Step 2 of Backend Setup.

### Step 4: Update Main App File

**File**: `mobile_app/lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SNAS Mobile',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Step 5: Configure Platform-Specific Settings

#### Android Configuration

**File**: `mobile_app/android/app/src/main/AndroidManifest.xml`

Add permissions:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.NFC"/>
    
    <uses-feature android:name="android.hardware.nfc" android:required="true"/>
    <uses-feature android:name="android.hardware.location.gps"/>
    
    <application
        android:label="SNAS Mobile"
        android:icon="@mipmap/ic_launcher">
        <!-- Rest of your application config -->
    </application>
</manifest>
```

**File**: `mobile_app/android/app/build.gradle`

Update minimum SDK version:
```gradle
android {
    defaultConfig {
        minSdkVersion 26  // Android 8.0 or higher
        targetSdkVersion 33
    }
}
```

#### iOS Configuration

**File**: `mobile_app/ios/Runner/Info.plist`

Add permissions:
```xml
<dict>
    <!-- Add these entries -->
    <key>NFCReaderUsageDescription</key>
    <string>This app needs NFC access to scan attendance tags</string>
    
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>This app needs location access to verify you are in the classroom</string>
    
    <key>NSLocationAlwaysUsageDescription</key>
    <string>This app needs location access to verify you are in the classroom</string>
    
    <!-- Enable NFC capability -->
    <key>com.apple.developer.nfc.readersession.formats</key>
    <array>
        <string>NDEF</string>
    </array>
</dict>
```

### Step 6: Run the Mobile App

#### On Android Emulator/Device

```bash
# List available devices
flutter devices

# Run on connected device
flutter run

# Or run in release mode
flutter run --release
```

#### On iOS Simulator/Device

```bash
# Open iOS simulator
open -a Simulator

# Run app
flutter run

# Note: NFC only works on physical iOS devices, not simulator
```

### Step 7: Test Mobile App Login

1. Launch the app
2. Enter test credentials:
   - Email: `test.student@university.edu`
   - Password: `TestPassword123!`
3. Click "Sign In"
4. You should see the home screen with "Tap to Scan" button

## Admin Dashboard Setup

### Step 1: Navigate to Dashboard Directory

```bash
cd admin_dashboard
```

### Step 2: Install Dependencies

```bash
# Install Node packages
npm install

# Or using yarn
yarn install
```

### Step 3: Configure Environment Variables

Create environment file:

**File**: `admin_dashboard/.env.local`

```env
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=YOUR_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY

# Optional: Mapbox for map visualization
NEXT_PUBLIC_MAPBOX_TOKEN=your_mapbox_token_here
```

Replace with your actual Supabase credentials.

### Step 4: Get Mapbox Token (Optional but Recommended)

1. Sign up at [mapbox.com](https://www.mapbox.com)
2. Go to **Account** → **Access Tokens**
3. Copy your default public token
4. Add to `.env.local` file

### Step 5: Run Development Server

```bash
# Start development server
npm run dev

# Or using yarn
yarn dev
```

The dashboard will be available at `http://localhost:3000`

### Step 6: Create Admin User

1. Go to Supabase dashboard → **Authentication** → **Users**
2. Click "Add user" → "Create new user"
3. Fill in:
   - **Email**: `admin@university.edu`
   - **Password**: `AdminPassword123!`
   - **Auto Confirm User**: Check this box
4. Click "Create user"

### Step 7: Test Admin Dashboard

1. Open `http://localhost:3000` in browser
2. Click "Login"
3. Enter admin credentials:
   - Email: `admin@university.edu`
   - Password: `AdminPassword123!`
4. You should see the dashboard with map and attendance feed

## NFC Tag Configuration

### Step 1: Purchase NFC Tags

**Recommended**: NTAG213 NFC tags
- **Capacity**: 144 bytes (sufficient for our JSON payload)
- **Compatibility**: Works with all NFC-enabled smartphones
- **Where to buy**: Amazon, AliExpress, or NFC tag suppliers
- **Quantity**: One per classroom

### Step 2: Prepare Tag Data

For each classroom, create a JSON payload:

**Format**:
```json
{
  "classroom_id": "550e8400-e29b-41d4-a716-446655440000",
  "secret_token": "secret-token-room-101"
}
```

**Example for Room 101**:
```json
{
  "classroom_id": "550e8400-e29b-41d4-a716-446655440000",
  "secret_token": "secret-token-room-101"
}
```

### Step 3: Write Data to NFC Tags

#### Using NFC Tools App (Android/iOS)

1. Install "NFC Tools" app from Play Store or App Store
2. Open the app
3. Go to **Write** tab
4. Click "Add a record"
5. Select "Text"
6. Paste your JSON payload
7. Click "OK"
8. Click "Write" button
9. Hold NFC tag against phone until write completes
10. Test by reading the tag (Read tab)

#### Using Command Line (Advanced)

```bash
# Install nfc-tools
sudo apt-get install libnfc-bin

# Write to tag
echo '{"classroom_id":"550e8400-e29b-41d4-a716-446655440000","secret_token":"secret-token-room-101"}' | nfc-mfclassic w a tag.mfd
```

### Step 4: Label and Install Tags

1. Print labels for each tag:
   ```
   Room 101 - Engineering Building
   Scan here for attendance
   ```

2. Attach tags to classroom entrances:
   - Height: 1.2-1.5 meters (comfortable scanning height)
   - Location: Near door, visible and accessible
   - Surface: Flat, non-metallic surface (metal interferes with NFC)

### Step 5: Test NFC Tags

1. Open SNAS mobile app
2. Login with test account
3. Tap phone on NFC tag
4. App should read tag and show scanning screen
5. Verify classroom name appears correctly

## Testing the System

### End-to-End Test Scenario

#### Test 1: Successful Attendance Marking

1. **Setup**:
   - Ensure you're within 50 meters of a classroom location
   - Have NFC tag ready
   - Mobile app logged in

2. **Steps**:
   - Open mobile app
   - Tap "Tap to Scan" button
   - Hold phone against NFC tag
   - Wait for GPS capture
   - Wait for validation

3. **Expected Result**:
   - Success screen with green checkmark
   - "Attendance Marked!" message
   - Timestamp displayed

4. **Verify in Dashboard**:
   - Open admin dashboard
   - See new attendance record in feed
   - See student location on map (within 50m circle)

#### Test 2: Geofence Rejection

1. **Setup**:
   - Be more than 50 meters away from classroom
   - Or modify test data to simulate distance

2. **Steps**:
   - Scan NFC tag
   - Wait for validation

3. **Expected Result**:
   - Error screen with red X
   - "Outside classroom area" message
   - Record logged as REJECTED in dashboard

#### Test 3: Rate Limiting

1. **Steps**:
   - Mark attendance successfully
   - Immediately try to mark attendance again (within 60 seconds)

2. **Expected Result**:
   - Error message: "Rate limit exceeded"
   - Must wait 60 seconds before next attempt

#### Test 4: Offline Attendance History

1. **Steps**:
   - Mark attendance successfully
   - Enable airplane mode on phone
   - Open attendance history screen

2. **Expected Result**:
   - Attendance history loads from cache
   - Previous records visible
   - "Showing cached data" indicator

### Running Automated Tests

#### Backend Tests

```bash
# Connect to Supabase database
psql -h db.xxxxxxxxxxxxx.supabase.co -U postgres -d postgres

# Run performance tests
\i supabase/migrations/test_performance.sql

# Run validation tests
\i supabase/migrations/test_mark_attendance_function.sql
\i supabase/migrations/test_geofence_validation.sql
\i supabase/migrations/test_device_binding_verification.sql
```

#### Mobile App Tests

```bash
cd mobile_app

# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/
```

## Troubleshooting

### Common Issues

#### Issue 1: "PostGIS extension not found"

**Solution**:
```sql
-- Enable PostGIS in Supabase dashboard
-- Database → Extensions → Enable PostGIS
```

#### Issue 2: Mobile app can't connect to Supabase

**Symptoms**: Network errors, authentication failures

**Solutions**:
1. Verify Supabase URL and anon key are correct
2. Check internet connection
3. Verify Supabase project is active (not paused)
4. Check firewall/proxy settings

#### Issue 3: NFC not working on Android

**Solutions**:
1. Enable NFC in phone settings
2. Check app has NFC permission
3. Verify phone has NFC hardware (`flutter doctor`)
4. Try different NFC tag position

#### Issue 4: GPS location not accurate

**Solutions**:
1. Enable high accuracy mode in phone settings
2. Go outside or near window (better GPS signal)
3. Wait 10-20 seconds for GPS lock
4. Check location permissions granted

#### Issue 5: "Device mismatch" error

**Cause**: Trying to login from different device

**Solutions**:
1. Use same device as first login
2. Or reset device binding in database:
   ```sql
   UPDATE profiles SET device_id = NULL WHERE email = 'user@email.com';
   ```

#### Issue 6: Admin dashboard map not loading

**Solutions**:
1. Add Mapbox token to `.env.local`
2. Check browser console for errors
3. Verify classroom locations have valid coordinates
4. Try refreshing page

### Debug Mode

#### Enable Flutter Debug Logging

```dart
// In main.dart
void main() {
  // Enable debug logging
  debugPrint('App starting...');
  
  runApp(MyApp());
}
```

#### Enable Supabase Debug Logging

```dart
await Supabase.initialize(
  url: supabaseUrl,
  anonKey: anonKey,
  debug: true, // Enable debug mode
);
```

#### Check Database Logs

In Supabase dashboard:
1. Go to **Logs** → **Database**
2. Filter by error level
3. Check for SQL errors or constraint violations

## Production Deployment

### Backend (Supabase)

1. **Upgrade to Pro Plan** (recommended for production)
   - More connections (200 vs 60)
   - Better performance
   - Daily backups

2. **Configure Custom Domain** (optional)
   - Go to Settings → Custom Domains
   - Add your domain
   - Update DNS records

3. **Enable Point-in-Time Recovery**
   - Go to Database → Backups
   - Enable PITR for data safety

4. **Set Up Monitoring**
   - Configure alerts for:
     - Connection pool usage > 80%
     - Slow queries > 1 second
     - Error rate > 5%

### Mobile App

#### Android Deployment

```bash
# Build release APK
flutter build apk --release

# Or build App Bundle (for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Play Store Submission**:
1. Create developer account ($25 one-time fee)
2. Create app listing
3. Upload app bundle
4. Complete store listing (screenshots, description)
5. Submit for review

#### iOS Deployment

```bash
# Build release IPA
flutter build ios --release

# Open Xcode
open ios/Runner.xcworkspace
```

**App Store Submission**:
1. Enroll in Apple Developer Program ($99/year)
2. Create app in App Store Connect
3. Archive and upload via Xcode
4. Complete app information
5. Submit for review

### Admin Dashboard

#### Deploy to Vercel (Recommended)

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd admin_dashboard
vercel

# Follow prompts to deploy
```

#### Deploy to Netlify

```bash
# Build production version
npm run build

# Deploy to Netlify
# Drag and drop .next folder to netlify.com
```

#### Environment Variables for Production

Set these in your hosting platform:
```env
NEXT_PUBLIC_SUPABASE_URL=your_production_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_production_key
NEXT_PUBLIC_MAPBOX_TOKEN=your_mapbox_token
```

### Security Checklist

- [ ] Change all default passwords
- [ ] Enable email verification
- [ ] Configure rate limiting
- [ ] Set up SSL/TLS (automatic with Supabase)
- [ ] Enable Row Level Security policies
- [ ] Rotate NFC secret tokens periodically
- [ ] Set up database backups
- [ ] Configure monitoring and alerts
- [ ] Review and test all RLS policies
- [ ] Implement proper error handling
- [ ] Set up logging and analytics

## Next Steps

After setup is complete:

1. **Customize the System**
   - Update branding and colors
   - Customize email templates
   - Add your institution's logo

2. **Add More Classrooms**
   - Insert classroom data in database
   - Program NFC tags
   - Install tags in classrooms

3. **Create User Accounts**
   - Import student list
   - Send invitation emails
   - Provide user documentation

4. **Monitor Performance**
   - Check dashboard analytics
   - Review attendance patterns
   - Optimize based on usage

5. **Gather Feedback**
   - Survey students and administrators
   - Identify pain points
   - Plan improvements

## Support and Documentation

### Additional Resources

- **Requirements Document**: `.kiro/specs/smart-nfc-attendance-system/requirements.md`
- **Design Document**: `.kiro/specs/smart-nfc-attendance-system/design.md`
- **Task List**: `.kiro/specs/smart-nfc-attendance-system/tasks.md`
- **Performance Guide**: `supabase/migrations/TASK_16_PERFORMANCE_COMPLETE.md`
- **Caching Guide**: `mobile_app/CACHING_AND_OFFLINE_SUPPORT.md`
- **Connection Pooling**: `supabase/CONNECTION_POOLING_GUIDE.md`

### Getting Help

- **Supabase Docs**: [supabase.com/docs](https://supabase.com/docs)
- **Flutter Docs**: [flutter.dev/docs](https://flutter.dev/docs)
- **Next.js Docs**: [nextjs.org/docs](https://nextjs.org/docs)

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     SNAS Architecture                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │ Mobile App   │         │ Admin        │                 │
│  │ (Flutter)    │         │ Dashboard    │                 │
│  │              │         │ (Next.js)    │                 │
│  └──────┬───────┘         └──────┬───────┘                 │
│         │                        │                          │
│         │    HTTPS/REST API      │                          │
│         └────────┬───────────────┘                          │
│                  │                                           │
│         ┌────────▼────────┐                                 │
│         │  Supabase API   │                                 │
│         │  - Auth         │                                 │
│         │  - REST API     │                                 │
│         │  - Realtime     │                                 │
│         └────────┬────────┘                                 │
│                  │                                           │
│         ┌────────▼────────┐                                 │
│         │  PostgreSQL     │                                 │
│         │  + PostGIS      │                                 │
│         │  + PgBouncer    │                                 │
│         └─────────────────┘                                 │
│                                                              │
│  ┌──────────────┐                                           │
│  │ NFC Tags     │                                           │
│  │ (NTAG213)    │                                           │
│  └──────────────┘                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**Version**: 1.0.0  
**Last Updated**: February 2026  
**Status**: Production Ready ✅

