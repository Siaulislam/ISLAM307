import 'package:flutter_test/flutter_test.dart';

import '../lib/features/prayer/prayer_math.dart';

void main() {
  group('calculatePrayerTimes', () {
    test('Karachi produces ordered times for a known day', () {
      // Karachi ≈ 24.86 N, 67.00 E, UTC+5
      final t = calculatePrayerTimes(
        date: DateTime(2026, 7, 13),
        latitude: 24.8607,
        longitude: 67.0011,
        timezoneOffsetHours: 5,
        method: PrayerCalculationMethod.karachi,
        madhab: AsrMadhab.hanafi,
      );
      expect(t.fajr.isBefore(t.sunrise), isTrue);
      expect(t.sunrise.isBefore(t.dhuhr), isTrue);
      expect(t.dhuhr.isBefore(t.asr), isTrue);
      expect(t.asr.isBefore(t.maghrib), isTrue);
      expect(t.maghrib.isBefore(t.isha), isTrue);
      // Rough daytime window sanity
      expect(t.fajr.hour, lessThan(7));
      expect(t.dhuhr.hour, inInclusiveRange(11, 14));
      expect(t.maghrib.hour, greaterThan(17));
    });

    test('next prayer skips sunrise', () {
      final t = calculatePrayerTimes(
        date: DateTime(2026, 7, 13),
        latitude: 24.8607,
        longitude: 67.0011,
        timezoneOffsetHours: 5,
      );
      final afterFajr = t.fajr.add(const Duration(minutes: 1));
      final next = t.nextPrayer(afterFajr);
      expect(next.name, isNot('Sunrise'));
      expect(next.name, 'Dhuhr');
    });

    test('different methods change Fajr', () {
      final karachi = calculatePrayerTimes(
        date: DateTime(2026, 1, 15),
        latitude: 24.86,
        longitude: 67.0,
        timezoneOffsetHours: 5,
        method: PrayerCalculationMethod.karachi,
      );
      final isna = calculatePrayerTimes(
        date: DateTime(2026, 1, 15),
        latitude: 24.86,
        longitude: 67.0,
        timezoneOffsetHours: 5,
        method: PrayerCalculationMethod.isna,
      );
      // ISNA (15°) Fajr is later than Karachi (18°)
      expect(isna.fajr.isAfter(karachi.fajr), isTrue);
    });
  });
}
