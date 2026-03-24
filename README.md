# TravelAlarm

Flutter Android app scaffold.

## Run on Android (Windows)

1. Install prerequisites:
	- Android Studio (SDK + Platform Tools)
	- Enable an emulator (AVD) or a physical device with USB debugging
2. In this folder, run:
	- `flutter doctor` – verify setup
	- `flutter devices` – check an available Android device/emulator
	- `flutter run` – launch the app on the selected device

## Project notes

- App display name (Android): `TravelAlarm` (see `android/app/src/main/AndroidManifest.xml`)
- Package name: `com.travelalarm.travelalarm`
- Entry point: `lib/main.dart`
- Tests: `test/`

## Features implemented

- Foreground location monitoring using `geolocator`
- Set a destination (lat/lng) and radius; shows current distance
- Pick destination on a map (OpenStreetMap tiles via `flutter_map`)
- Sends a local notification when you enter the radius (Android 13+ will prompt for notification permission)
- Plays a looping alarm sound when you enter the radius (system alarm via `flutter_ringtone_player`)
- Fetches destination weather from Open-Meteo and shows travel suggestions (umbrella, warm layer, wind/heat caution)
- Manual cloud backup/restore of saved alarms and destination settings (no realtime sync)

## Cloud backup setup (Firebase)

The app now includes manual backup/restore using Firebase Auth + Cloud Firestore.

1. Create a Firebase project.
2. Add Android app with package name `com.travelalarm.travelalarm`.
3. Download `google-services.json` and place it in `android/app/google-services.json`.
4. Generate FlutterFire config for this project:
	 - Install CLI: `dart pub global activate flutterfire_cli`
	 - Run: `flutterfire configure`
5. Ensure Firestore is enabled in your Firebase project.
6. Run the app and use Alert settings -> Cloud backup.

If Firebase is not configured, the app will still run locally and show a message that cloud sync is not configured.

### Suggested Firestore rules

Use per-user document access only:

```txt
rules_version = '2';
service cloud.firestore {
	match /databases/{database}/documents {
		match /alarm_backups/{userId}/snapshots/{snapshotId} {
			allow read, write: if request.auth != null && request.auth.uid == userId;
		}
	}
}
```

## Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `POST_NOTIFICATIONS` (Android 13+)
- `INTERNET` (to load map tiles)

Note: Background alerts when the app is closed need additional setup (foreground service and background location permission). This scaffold alerts while the app is open. The map picker requires internet connectivity to load tiles.

## Useful links

- Lab: Write your first Flutter app – https://docs.flutter.dev/get-started/codelab
- Cookbook: Useful Flutter samples – https://docs.flutter.dev/cookbook
- Flutter docs – https://docs.flutter.dev/
