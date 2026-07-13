import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/offline_location_service.dart';
import '../../core/theme/islam307_theme.dart';
import 'prayer_math.dart';

/// Offline prayer timetable for the user's location (GPS once, then cached).
class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  final _location = const OfflineLocationService();

  bool _loading = true;
  String? _error;
  OfflineLocationError? _errorCode;
  bool _fromCache = false;

  PrayerTimesResult? _times;
  PrayerCalculationMethod _method = PrayerCalculationMethod.karachi;
  AsrMadhab _madhab = AsrMadhab.hanafi;
  DateTime _day = DateTime.now();

  static const _methodKey = 'prayer_method';
  static const _madhabKey = 'prayer_madhab';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final methodIdx = prefs.getInt(_methodKey);
    final madhabIdx = prefs.getInt(_madhabKey);
    if (methodIdx != null && methodIdx < PrayerCalculationMethod.values.length) {
      _method = PrayerCalculationMethod.values[methodIdx];
    }
    if (madhabIdx != null && madhabIdx < AsrMadhab.values.length) {
      _madhab = AsrMadhab.values[madhabIdx];
    }

    try {
      final pos = await _location.resolve(featureLabel: 'prayer times');
      final tz = DateTime.now().timeZoneOffset.inMinutes / 60.0;
      final times = calculatePrayerTimes(
        date: _day,
        latitude: pos.latitude,
        longitude: pos.longitude,
        timezoneOffsetHours: tz,
        method: _method,
        madhab: _madhab,
      );
      if (!mounted) return;
      setState(() {
        _times = times;
        _fromCache = pos.fromCache;
        _loading = false;
      });
    } on OfflineLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _errorCode = e.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not prepare prayer times. Try again.';
        _errorCode = OfflineLocationError.unavailable;
      });
    }
  }

  Future<void> _persistPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_methodKey, _method.index);
    await prefs.setInt(_madhabKey, _madhab.index);
  }

  Future<void> _recomputeWithLocation() async {
    final times = _times;
    if (times == null) {
      await _bootstrap();
      return;
    }
    final tz = DateTime.now().timeZoneOffset.inMinutes / 60.0;
    setState(() {
      _times = calculatePrayerTimes(
        date: _day,
        latitude: times.latitude,
        longitude: times.longitude,
        timezoneOffsetHours: tz,
        method: _method,
        madhab: _madhab,
      );
    });
    await _persistPrefs();
  }

  String _fmt(DateTime t) => DateFormat('h:mm a').format(t);

  String _countdown(DateTime target) {
    final now = DateTime.now();
    var d = target.difference(now);
    if (d.isNegative) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return 'in ${h}h ${m}m';
    return 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Qibla',
            onPressed: () => context.push('/qibla'),
            icon: const Icon(Icons.explore_rounded),
          ),
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loading ? null : _bootstrap,
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Islam307Theme.emerald),
                    SizedBox(height: 16),
                    Text(
                      'Preparing offline prayer times…',
                      style: TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : _error != null
                ? _errorView()
                : _timetable(),
      ),
    );
  }

  Widget _errorView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Islam307Theme.emeraldSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.mosque_rounded, size: 48, color: Islam307Theme.emerald),
          ),
          const SizedBox(height: 20),
          const Text(
            'Location needed once',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Islam307Theme.textMuted, height: 1.45),
          ),
          const SizedBox(height: 8),
          const Text(
            'Prayer times are calculated fully offline after your location is saved on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Islam307Theme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _bootstrap, child: const Text('Use my location')),
          const SizedBox(height: 10),
          if (_errorCode == OfflineLocationError.deniedForever ||
              _errorCode == OfflineLocationError.serviceDisabled)
            OutlinedButton(
              onPressed: () async {
                if (_errorCode == OfflineLocationError.serviceDisabled) {
                  await _location.openLocationSettings();
                } else {
                  await _location.openAppSettings();
                }
              },
              child: Text(
                _errorCode == OfflineLocationError.serviceDisabled
                    ? 'Open location settings'
                    : 'Open app settings',
              ),
            ),
        ],
      ),
    );
  }

  Widget _timetable() {
    final times = _times!;
    final now = DateTime.now();
    final next = times.nextPrayer(now);
    final current = times.currentPrayer(now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Islam307Theme.emeraldSoft, Colors.white.withValues(alpha: 0.4)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Text(
                DateFormat('EEEE · d MMMM y').format(times.date),
                style: const TextStyle(fontSize: 13, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text('Next prayer', style: TextStyle(color: Islam307Theme.textMuted, fontSize: 13)),
              Text(
                '${next.name} · ${_fmt(next.time)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Islam307Theme.emeraldDeep,
                ),
              ),
              Text(
                _countdown(next.time),
                style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emerald),
              ),
              const SizedBox(height: 8),
              Text(
                _fromCache
                    ? 'Using saved location · offline'
                    : 'Location updated · times calculated offline',
                style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _chipSelectMethod()),
            const SizedBox(width: 8),
            Expanded(child: _chipSelectMadhab()),
          ],
        ),
        const SizedBox(height: 14),
        ...times.schedule.map((row) {
          final isSunrise = row.name == 'Sunrise';
          final isNext = !isSunrise && row.name == next.name && row.time == next.time;
          final isCurrent = current != null && row.name == current.name;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isNext || isCurrent
                  ? Islam307Theme.emerald.withValues(alpha: 0.12)
                  : Islam307Theme.fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNext ? Islam307Theme.emerald.withValues(alpha: 0.45) : Islam307Theme.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    style: TextStyle(
                      fontWeight: isNext || isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: isSunrise ? Islam307Theme.textMuted : null,
                    ),
                  ),
                ),
                if (isNext)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Islam307Theme.emerald,
                      ),
                    ),
                  ),
                Text(
                  _fmt(row.time),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isNext ? Islam307Theme.emeraldDeep : null,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        _metaRow(Icons.place_rounded, 'Coordinates',
            '${times.latitude.toStringAsFixed(4)}°, ${times.longitude.toStringAsFixed(4)}°'),
        _metaRow(Icons.calculate_rounded, 'Calculation',
            '${methodLabel(times.method)} · ${madhabLabel(times.madhab)} Asr'),
        _metaRow(Icons.cloud_off_rounded, 'Mode', 'Fully offline after location is saved'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/qibla'),
          icon: const Icon(Icons.explore_rounded),
          label: const Text('Open Qibla direction'),
        ),
      ],
    );
  }

  Widget _chipSelectMethod() {
    return PopupMenuButton<PrayerCalculationMethod>(
      onSelected: (m) async {
        setState(() => _method = m);
        await _recomputeWithLocation();
      },
      itemBuilder: (_) => PrayerCalculationMethod.values
          .map((m) => PopupMenuItem(value: m, child: Text(methodLabel(m))))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Islam307Theme.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Islam307Theme.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: Islam307Theme.emerald),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                methodLabel(_method),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSelectMadhab() {
    return PopupMenuButton<AsrMadhab>(
      onSelected: (m) async {
        setState(() => _madhab = m);
        await _recomputeWithLocation();
      },
      itemBuilder: (_) => AsrMadhab.values
          .map((m) => PopupMenuItem(value: m, child: Text('${madhabLabel(m)} Asr')))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Islam307Theme.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Islam307Theme.cardBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.mosque_rounded, size: 16, color: Islam307Theme.emerald),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${madhabLabel(_madhab)} Asr',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Islam307Theme.emerald),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
