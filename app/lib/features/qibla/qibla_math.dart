/// Pure Qibla bearing math (Kaaba → device). No Flutter / GPS deps.
library;

import 'dart:math' as math;

/// Kaaba (Masjid al-Haram), Mecca — WGS84.
const double kaabaLatitude = 21.422487;
const double kaabaLongitude = 39.826206;

/// Great-circle initial bearing from [lat]/[lng] toward the Kaaba, in degrees
/// clockwise from true north in `[0, 360)`.
double qiblaBearingDegrees(double lat, double lng) {
  final φ1 = lat * math.pi / 180.0;
  final φ2 = kaabaLatitude * math.pi / 180.0;
  final Δλ = (kaabaLongitude - lng) * math.pi / 180.0;
  final y = math.sin(Δλ);
  final x = math.cos(φ1) * math.tan(φ2) - math.sin(φ1) * math.cos(Δλ);
  final θ = math.atan2(y, x) * 180.0 / math.pi;
  return (θ + 360.0) % 360.0;
}

/// Compass needle angle: how much to rotate a "north-up" Qibla marker so it
/// points to Mecca given device [headingDegrees] (0 = north).
double qiblaNeedleRotation(double qiblaBearing, double headingDegrees) {
  return (qiblaBearing - headingDegrees + 360.0) % 360.0;
}

/// Cardinal label for a bearing.
String bearingCardinal(double degrees) {
  const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final i = ((degrees % 360) / 45).round() % 8;
  return labels[i];
}

/// Approximate distance to Kaaba in kilometres (haversine).
double distanceToKaabaKm(double lat, double lng) {
  const r = 6371.0;
  final φ1 = lat * math.pi / 180.0;
  final φ2 = kaabaLatitude * math.pi / 180.0;
  final Δφ = (kaabaLatitude - lat) * math.pi / 180.0;
  final Δλ = (kaabaLongitude - lng) * math.pi / 180.0;
  final a = math.sin(Δφ / 2) * math.sin(Δφ / 2) +
      math.cos(φ1) * math.cos(φ2) * math.sin(Δλ / 2) * math.sin(Δλ / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
