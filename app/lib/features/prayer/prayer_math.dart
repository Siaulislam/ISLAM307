/// Offline prayer-time calculation (no network).
///
/// Astronomical algorithm adapted from PrayTimes.org (Hamid Zarrabi-Zadeh).
/// Inputs: latitude, longitude, local date, timezone offset — all on-device.
library;

import 'dart:math' as math;

enum PrayerCalculationMethod {
  /// University of Islamic Sciences, Karachi — common in South Asia / Pakistan.
  karachi,

  /// Muslim World League.
  muslimWorldLeague,

  /// Egyptian General Authority of Survey.
  egyptian,

  /// Islamic Society of North America.
  isna,

  /// Umm Al-Qura University, Makkah (Isha = Maghrib + 90 min).
  ummAlQura,
}

enum AsrMadhab {
  /// Shafi / Maliki / Hanbali (shadow factor 1).
  standard,

  /// Hanafi (shadow factor 2).
  hanafi,
}

class PrayerTimesResult {
  const PrayerTimesResult({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.method,
    required this.madhab,
    required this.latitude,
    required this.longitude,
    required this.timezoneOffsetHours,
  });

  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final PrayerCalculationMethod method;
  final AsrMadhab madhab;
  final double latitude;
  final double longitude;
  final double timezoneOffsetHours;

  List<({String name, DateTime time})> get schedule => [
        (name: 'Fajr', time: fajr),
        (name: 'Sunrise', time: sunrise),
        (name: 'Dhuhr', time: dhuhr),
        (name: 'Asr', time: asr),
        (name: 'Maghrib', time: maghrib),
        (name: 'Isha', time: isha),
      ];

  ({String name, DateTime time}) nextPrayer(DateTime now) {
    for (final row in schedule) {
      if (row.name == 'Sunrise') continue;
      if (row.time.isAfter(now)) return row;
    }
    return (name: 'Fajr', time: fajr.add(const Duration(days: 1)));
  }

  ({String name, DateTime time})? currentPrayer(DateTime now) {
    final prayers = schedule.where((e) => e.name != 'Sunrise').toList();
    for (var i = 0; i < prayers.length; i++) {
      final start = prayers[i].time;
      final end = i + 1 < prayers.length
          ? prayers[i + 1].time
          : fajr.add(const Duration(days: 1));
      if (!now.isBefore(start) && now.isBefore(end)) return prayers[i];
    }
    return null;
  }
}

class _MethodAngles {
  const _MethodAngles(this.fajr, this.isha, {this.ishaMinutesAfterMaghrib});
  final double fajr;
  final double isha;
  final double? ishaMinutesAfterMaghrib;
}

_MethodAngles _anglesFor(PrayerCalculationMethod m) {
  switch (m) {
    case PrayerCalculationMethod.karachi:
      return const _MethodAngles(18, 18);
    case PrayerCalculationMethod.muslimWorldLeague:
      return const _MethodAngles(18, 17);
    case PrayerCalculationMethod.egyptian:
      return const _MethodAngles(19.5, 17.5);
    case PrayerCalculationMethod.isna:
      return const _MethodAngles(15, 15);
    case PrayerCalculationMethod.ummAlQura:
      return const _MethodAngles(18.5, 0, ishaMinutesAfterMaghrib: 90);
  }
}

double _dtr(double d) => d * math.pi / 180.0;
double _rtd(double r) => r * 180.0 / math.pi;

double _fix(double a, double b) {
  final x = a - b * (a / b).floorToDouble();
  return x < 0 ? x + b : x;
}

double _julian(DateTime date, double timezoneHours) {
  var y = date.year;
  var m = date.month;
  final d = date.day + 0.5 - timezoneHours / 24.0;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100).floor();
  final b = 2 - a + (a / 4).floor();
  return (365.25 * (y + 4716)).floorToDouble() +
      (30.6001 * (m + 1)).floorToDouble() +
      d +
      b -
      1524.5;
}

double _sunDeclination(double jd) {
  final d = jd - 2451545.0;
  final g = _fix(357.529 + 0.98560028 * d, 360) * _dtr(1);
  final q = _fix(280.459 + 0.98564736 * d, 360);
  final l = _fix(q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g), 360) * _dtr(1);
  final e = (23.439 - 0.00000036 * d) * _dtr(1);
  return _rtd(math.asin(math.sin(e) * math.sin(l)));
}

double _equationOfTime(double jd) {
  final d = jd - 2451545.0;
  final g = _fix(357.529 + 0.98560028 * d, 360) * _dtr(1);
  final q = _fix(280.459 + 0.98564736 * d, 360);
  final l = _fix(q + 1.915 * math.sin(g) + 0.020 * math.sin(2 * g), 360);
  final e = (23.439 - 0.00000036 * d) * _dtr(1);
  final ra = _rtd(math.atan2(math.cos(e) * math.sin(l * _dtr(1)), math.cos(l * _dtr(1)))) / 15.0;
  return q / 15.0 - _fix(ra, 24);
}

double _midDay(double jd, double timezoneHours, double lng) {
  final eqt = _equationOfTime(jd);
  return _fix(12 - eqt - lng / 15.0 + timezoneHours, 24);
}

double _hourAngle(double lat, double angle, double decl) {
  final term = (-math.sin(_dtr(angle)) - math.sin(_dtr(lat)) * math.sin(_dtr(decl))) /
      (math.cos(_dtr(lat)) * math.cos(_dtr(decl)));
  return _rtd(math.acos(term.clamp(-1.0, 1.0))) / 15.0;
}

DateTime _timeFromHours(DateTime date, double hours) {
  final h = _fix(hours, 24);
  final hour = h.floor();
  final minutesFloat = (h - hour) * 60;
  final minute = minutesFloat.floor();
  final second = ((minutesFloat - minute) * 60).round().clamp(0, 59);
  return DateTime(date.year, date.month, date.day, hour, minute, second);
}

double _asrTime(double mid, double lat, double decl, AsrMadhab madhab) {
  final shadow = madhab == AsrMadhab.hanafi ? 2.0 : 1.0;
  final asrFactor = shadow + math.tan(_dtr((lat - decl).abs()));
  final asrAngle = _rtd(math.atan(1 / asrFactor));
  return mid + _hourAngle(lat, 90 - asrAngle, decl);
}

/// Compute prayer times offline for [date] at [latitude]/[longitude].
PrayerTimesResult calculatePrayerTimes({
  required DateTime date,
  required double latitude,
  required double longitude,
  required double timezoneOffsetHours,
  PrayerCalculationMethod method = PrayerCalculationMethod.karachi,
  AsrMadhab madhab = AsrMadhab.hanafi,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final angles = _anglesFor(method);
  final jd0 = _julian(day, timezoneOffsetHours);
  const sunriseAngle = 0.833;

  double at(double hours) {
    final j = jd0 + (hours - timezoneOffsetHours - 12) / 24.0;
    final decl = _sunDeclination(j);
    final mid = _midDay(j, timezoneOffsetHours, longitude);
    return mid;
  }

  // First rough pass at midday
  var decl = _sunDeclination(jd0);
  var mid = _midDay(jd0, timezoneOffsetHours, longitude);
  var fajr = mid - _hourAngle(latitude, angles.fajr, decl);
  var sunrise = mid - _hourAngle(latitude, sunriseAngle, decl);
  var sunset = mid + _hourAngle(latitude, sunriseAngle, decl);
  var asr = _asrTime(mid, latitude, decl, madhab);
  var isha = angles.ishaMinutesAfterMaghrib != null
      ? sunset + angles.ishaMinutesAfterMaghrib! / 60.0
      : mid + _hourAngle(latitude, angles.isha, decl);
  var dhuhr = mid;

  // Second pass with time-specific solar position
  double rising(double approx, double angle) {
    final j = jd0 + (approx - timezoneOffsetHours - 12) / 24.0;
    decl = _sunDeclination(j);
    mid = _midDay(j, timezoneOffsetHours, longitude);
    return mid - _hourAngle(latitude, angle, decl);
  }

  double setting(double approx, double angle) {
    final j = jd0 + (approx - timezoneOffsetHours - 12) / 24.0;
    decl = _sunDeclination(j);
    mid = _midDay(j, timezoneOffsetHours, longitude);
    return mid + _hourAngle(latitude, angle, decl);
  }

  fajr = rising(fajr, angles.fajr);
  sunrise = rising(sunrise, sunriseAngle);
  sunset = setting(sunset, sunriseAngle);
  {
    final j = jd0 + (asr - timezoneOffsetHours - 12) / 24.0;
    decl = _sunDeclination(j);
    mid = _midDay(j, timezoneOffsetHours, longitude);
    asr = _asrTime(mid, latitude, decl, madhab);
  }
  if (angles.ishaMinutesAfterMaghrib != null) {
    isha = sunset + angles.ishaMinutesAfterMaghrib! / 60.0;
  } else {
    isha = setting(isha, angles.isha);
  }
  dhuhr = at(dhuhr);

  return PrayerTimesResult(
    date: day,
    fajr: _timeFromHours(day, fajr),
    sunrise: _timeFromHours(day, sunrise),
    dhuhr: _timeFromHours(day, dhuhr),
    asr: _timeFromHours(day, asr),
    maghrib: _timeFromHours(day, sunset),
    isha: _timeFromHours(day, isha),
    method: method,
    madhab: madhab,
    latitude: latitude,
    longitude: longitude,
    timezoneOffsetHours: timezoneOffsetHours,
  );
}

String methodLabel(PrayerCalculationMethod m) {
  switch (m) {
    case PrayerCalculationMethod.karachi:
      return 'Karachi (UofIS)';
    case PrayerCalculationMethod.muslimWorldLeague:
      return 'Muslim World League';
    case PrayerCalculationMethod.egyptian:
      return 'Egyptian';
    case PrayerCalculationMethod.isna:
      return 'ISNA';
    case PrayerCalculationMethod.ummAlQura:
      return 'Umm Al-Qura';
  }
}

String madhabLabel(AsrMadhab m) => m == AsrMadhab.hanafi ? 'Hanafi' : 'Standard';
