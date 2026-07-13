import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Location + permission helpers for the Qibla screen.
class QiblaLocationService {
  const QiblaLocationService();

  Future<bool> ensureServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  /// Returns a position after requesting permission when needed.
  /// Throws [QiblaLocationException] on denial / service off.
  Future<Position> getCurrentPosition() async {
    final serviceOn = await ensureServiceEnabled();
    if (!serviceOn) {
      throw const QiblaLocationException(
        QiblaLocationError.serviceDisabled,
        'Location services are turned off. Enable GPS to find the Qibla.',
      );
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const QiblaLocationException(
        QiblaLocationError.denied,
        'Location permission is required to show the Qibla direction.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const QiblaLocationException(
        QiblaLocationError.deniedForever,
        'Location permission is permanently denied. Open settings to enable it.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e, st) {
      debugPrint('Qibla getCurrentPosition failed: $e\n$st');
      // Fallback: last known if available
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw QiblaLocationException(
        QiblaLocationError.unavailable,
        'Could not read your location. Try again outdoors with a clear sky view.',
        cause: e,
      );
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

enum QiblaLocationError {
  serviceDisabled,
  denied,
  deniedForever,
  unavailable,
}

class QiblaLocationException implements Exception {
  const QiblaLocationException(this.code, this.message, {this.cause});

  final QiblaLocationError code;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
