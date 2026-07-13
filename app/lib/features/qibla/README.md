# Qibla feature

Tap **Qibla** on the home Quick Access grid → `/qibla`.

## Behaviour

1. Requests the user’s current GPS location (`geolocator`)
2. Computes the great-circle bearing toward the Kaaba (Mecca)
3. Listens to the device compass (`flutter_compass`) and rotates the needle so the tip points to the Qibla when the phone is held flat
4. Shows bearing, distance, and permission / GPS error states with retry + settings deep links

## Platform permissions

After `flutter create` (or when android/ios folders exist), add:

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ISLAM 307 needs your location to show the Qibla direction toward the Kaaba.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>ISLAM 307 needs your location to show the Qibla direction toward the Kaaba.</string>
```

Compass accuracy is best outdoors, phone flat, away from metal / magnets.
