# Prayer & Qibla (offline)

Both features use **on-device GPS once**, then **local math only** — no prayer/Qibla network APIs.

| Feature | Route | Offline calculation |
|---------|-------|---------------------|
| Prayer timetable | `/prayer` | Astronomical prayer times from lat/lng + date + timezone |
| Qibla direction | `/qibla` | Great-circle bearing to the Kaaba + device compass |

Location is cached in `SharedPreferences` so both screens keep working without network after the first successful fix.

## Platform permissions

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS (`Info.plist`)

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ISLAM 307 needs your location once to show offline prayer times and Qibla direction.</string>
```
