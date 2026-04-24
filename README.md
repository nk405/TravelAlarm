# TravelAlarm

TravelAlarm is a Flutter-based Android app that triggers an alarm when you are close to your destination. It combines live location tracking, map-based destination selection, weather suggestions, and optional cloud sync.

## Highlights

- Location-based destination alarms with configurable alert radius
- OpenStreetMap destination picker
- Weather recommendations using Open-Meteo
- Optional cloud backup with Firebase Auth and Firestore

## Tech Stack

- Flutter (Dart)
- Firebase Authentication
- Cloud Firestore
- OpenStreetMap
- Open-Meteo API

## Project Structure

Key directories:

- lib/ - App source code (screens, services, models, widgets)
- assets/ - Static assets used by the app
- android/ - Android platform configuration and Gradle files
- model/ - Local ML/weather model assets
- test/ - Unit and widget tests

## Prerequisites

Before running the app, make sure you have:

- Flutter SDK installed and added to PATH
- Android Studio with Android SDK and emulator support
- A running Android emulator or a physical Android device

Verify your environment:

```bash
flutter doctor
```

## Quick Start

1. Install dependencies:

```bash
flutter pub get
```

2. Run the app:

```bash
flutter run
```

## Build Release APK

```bash
flutter build apk --release
```

The generated APK is created under:

- build/app/outputs/flutter-apk/

## Firebase Setup (Optional)

If you want cloud backup/sync for alarms and settings:

1. Create a Firebase project.
2. Add an Android app with package name: com.travelalarm.travelalarm
3. Place google-services.json in android/app/
4. Run FlutterFire configuration:

```bash
flutterfire configure
```

5. Enable Firebase Authentication and Cloud Firestore.
6. Configure Firestore security rules so each user can only access their own data.

## Required Permissions

- Location: used to monitor distance to destination
- Notifications: used to trigger arrival alerts
- Internet: used for maps, weather lookup, and cloud sync

## Running Tests

```bash
flutter test
```

## Troubleshooting

- If Android build fails, run flutter doctor and resolve all reported issues.
- If Firebase features do not work, confirm google-services.json is in android/app/ and that Firebase is initialized.
- If location alarms do not trigger, verify location permission is granted and battery optimization is not restricting the app.

