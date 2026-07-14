import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/islam307_theme.dart';

class OfflineUtilityScreen extends StatelessWidget {
  const OfflineUtilityScreen({super.key, required this.utility});

  final String utility;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (utility) {
      'qibla' => ('Qibla Bearing', const _QiblaCalculator()),
      'zakat' => ('Zakat Calculator', const _ZakatCalculator()),
      'calendar' => ('Islamic Calendar', const _IslamicCalendar()),
      _ => ('Offline Utility', const SizedBox.shrink()),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: body,
    );
  }
}

class _QiblaCalculator extends StatefulWidget {
  const _QiblaCalculator();

  @override
  State<_QiblaCalculator> createState() => _QiblaCalculatorState();
}

class _QiblaCalculatorState extends State<_QiblaCalculator> {
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  double? _bearing;

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  void _calculate() {
    final lat = double.tryParse(_latitude.text);
    final lon = double.tryParse(_longitude.text);
    if (lat == null || lon == null || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      setState(() => _bearing = null);
      return;
    }
    const kaabaLat = 21.4225;
    const kaabaLon = 39.8262;
    final phi1 = lat * math.pi / 180;
    final phi2 = kaabaLat * math.pi / 180;
    final delta = (kaabaLon - lon) * math.pi / 180;
    final y = math.sin(delta);
    final x = math.cos(phi1) * math.tan(phi2) -
        math.sin(phi1) * math.cos(delta);
    setState(() => _bearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Enter your device coordinates. Calculation is performed locally; no location or map dataset is uploaded.',
          style: TextStyle(color: Islam307Theme.textMuted, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _latitude,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Latitude'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _longitude,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(labelText: 'Longitude'),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _calculate, child: const Text('Calculate Qibla')),
        if (_bearing != null) ...[
          const SizedBox(height: 24),
          const Icon(Icons.explore_rounded, size: 72, color: Islam307Theme.emerald),
          Text(
            '${_bearing!.toStringAsFixed(1)}° clockwise from true north',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ],
    );
  }
}

class _ZakatCalculator extends StatefulWidget {
  const _ZakatCalculator();

  @override
  State<_ZakatCalculator> createState() => _ZakatCalculatorState();
}

class _ZakatCalculatorState extends State<_ZakatCalculator> {
  final _wealth = TextEditingController();
  final _liabilities = TextEditingController(text: '0');
  final _nisab = TextEditingController();
  double? _result;
  double? _net;

  @override
  void dispose() {
    _wealth.dispose();
    _liabilities.dispose();
    _nisab.dispose();
    super.dispose();
  }

  void _calculate() {
    final wealth = double.tryParse(_wealth.text);
    final liabilities = double.tryParse(_liabilities.text);
    final nisab = double.tryParse(_nisab.text);
    if (wealth == null || liabilities == null || nisab == null) {
      setState(() {
        _result = null;
        _net = null;
      });
      return;
    }
    final net = math.max(0, wealth - liabilities);
    setState(() {
      _net = net.toDouble();
      _result = net >= nisab ? net * 0.025 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Enter your own currency values and current nisab. This private, offline estimate uses 2.5%; confirm eligibility, lunar-year requirements, asset treatment and liabilities with a qualified scholar.',
          style: TextStyle(color: Islam307Theme.textMuted, height: 1.5),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _wealth,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Eligible wealth'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _liabilities,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Deductible liabilities'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nisab,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Current nisab value'),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _calculate, child: const Text('Calculate estimate')),
        if (_result != null) ...[
          const SizedBox(height: 24),
          Text('Net eligible wealth: ${_net!.toStringAsFixed(2)}'),
          Text(
            'Estimated Zakat: ${_result!.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep),
          ),
        ],
      ],
    );
  }
}

class _IslamicCalendar extends StatelessWidget {
  const _IslamicCalendar();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hijri = _civilHijri(now.year, now.month, now.day);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.calendar_month_rounded, size: 72, color: Islam307Theme.emerald),
        const SizedBox(height: 16),
        Text(
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '${hijri.$3} ${_months[hijri.$2 - 1]} ${hijri.$1} AH',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep),
        ),
        const SizedBox(height: 18),
        const Text(
          'Calculated civil Hijri estimate. Local moon-sighting authorities may differ by one or more days. No religious-event dataset is bundled.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Islam307Theme.textMuted, height: 1.5),
        ),
      ],
    );
  }

  static const _months = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha’ban',
    'Ramadan',
    'Shawwal',
    'Dhul Qi’dah',
    'Dhul Hijjah',
  ];

  static (int, int, int) _civilHijri(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    final julianDay = day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
    final hijriYear =
        ((30 * (julianDay - 1948439) + 10646) / 10631).floor();
    final hijriMonth = math.min(
      12,
      ((julianDay - (29 + _islamicJulianDay(hijriYear, 1, 1))) / 29.5)
              .ceil() +
          1,
    );
    final hijriDay =
        julianDay - _islamicJulianDay(hijriYear, hijriMonth, 1) + 1;
    return (hijriYear, hijriMonth, hijriDay);
  }

  static int _islamicJulianDay(int year, int month, int day) {
    return day +
        (29.5 * (month - 1)).ceil() +
        (year - 1) * 354 +
        (3 + 11 * year) ~/ 30 +
        1948439 -
        1;
  }
}
