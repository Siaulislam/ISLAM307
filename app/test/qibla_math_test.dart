import 'package:flutter_test/flutter_test.dart';

import '../lib/features/qibla/qibla_math.dart';

void main() {
  group('qiblaBearingDegrees', () {
    test('from near Kaaba is roughly south/nearby small distance', () {
      final d = distanceToKaabaKm(kaabaLatitude, kaabaLongitude);
      expect(d, lessThan(0.05));
    });

    test('Karachi faces roughly west toward Mecca', () {
      // Karachi ≈ 24.86 N, 67.00 E — Qibla is typically ~268° (west)
      final b = qiblaBearingDegrees(24.8607, 67.0011);
      expect(b, greaterThan(250));
      expect(b, lessThan(290));
      expect(bearingCardinal(b), anyOf('W', 'SW', 'NW'));
    });

    test('New York faces roughly northeast toward Mecca', () {
      final b = qiblaBearingDegrees(40.7128, -74.0060);
      expect(b, greaterThan(40));
      expect(b, lessThan(80));
    });

    test('needle rotation wraps into 0..360', () {
      expect(qiblaNeedleRotation(10, 350), closeTo(20, 0.001));
      expect(qiblaNeedleRotation(0, 0), 0);
    });
  });
}
