import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached coordinates for offline Prayer / Qibla (no network).
class CachedGeoPosition {
  const CachedGeoPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.savedAt,
    this.fromCache = false,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime savedAt;
  final bool fromCache;

  Position toPosition() {
    return Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: savedAt,
      accuracy: accuracyMeters,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

enum OfflineLocationError {
  serviceDisabled,
  denied,
  deniedForever,
  unavailable,
}

class OfflineLocationException implements Exception {
  const OfflineLocationException(this.code, this.message, {this.cause});

  final OfflineLocationError code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// GPS helper that prefers a fresh fix, then device last-known, then disk cache.
/// Prayer times and Qibla bearing are computed locally — never via the network.
class OfflineLocationService {
  const OfflineLocationService();

  static const _latKey = 'offline_geo_lat';
  static const _lngKey = 'offline_geo_lng';
  static const _accKey = 'offline_geo_acc';
  static const _atKey = 'offline_geo_at';

  Future<CachedGeoPosition?> readCache() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble(_latKey);
    final lng = p.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    final ms = p.getInt(_atKey) ?? 0;
    return CachedGeoPosition(
      latitude: lat,
      longitude: lng,
      accuracyMeters: p.getDouble(_accKey) ?? 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(ms),
      fromCache: true,
    );
  }

  Future<void> writeCache(double lat, double lng, {double accuracy = 0}) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_latKey, lat);
    await p.setDouble(_lngKey, lng);
    await p.setDouble(_accKey, accuracy);
    await p.setInt(_atKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Resolve a position for offline Islamic calculations.
  ///
  /// [allowCachedOnly] — if GPS fails, return disk cache instead of throwing
  /// (used so Prayer/Qibla keep working offline after the first successful fix).
  Future<CachedGeoPosition> resolve({
    bool allowCachedOnly = true,
    String featureLabel = 'this feature',
  }) async {
    final cached = await readCache();

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (allowCachedOnly && cached != null) return cached;
      throw OfflineLocationException(
        OfflineLocationError.serviceDisabled,
        'Location is off. Enable GPS once so $featureLabel can work offline afterward.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (allowCachedOnly && cached != null) return cached;
      throw OfflineLocationException(
        OfflineLocationError.denied,
        'Location permission is required for $featureLabel (then it works offline).',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      if (allowCachedOnly && cached != null) return cached;
      throw OfflineLocationException(
        OfflineLocationError.deniedForever,
        'Location permission is permanently denied. Open settings, allow once, then $featureLabel works offline.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 18),
        ),
      );
      await writeCache(pos.latitude, pos.longitude, accuracy: pos.accuracy);
      return CachedGeoPosition(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
        savedAt: DateTime.now(),
        fromCache: false,
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        await writeCache(last.latitude, last.longitude, accuracy: last.accuracy);
        return CachedGeoPosition(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracyMeters: last.accuracy,
          savedAt: last.timestamp,
          fromCache: false,
        );
      }
      if (allowCachedOnly && cached != null) return cached;
      throw OfflineLocationException(
        OfflineLocationError.unavailable,
        'Could not read your location. Try outdoors once; after that $featureLabel works offline.',
      );
    }
  }
}
