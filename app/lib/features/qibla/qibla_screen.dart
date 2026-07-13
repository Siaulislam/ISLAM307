import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/islam307_theme.dart';
import 'qibla_location_service.dart';
import 'qibla_math.dart';

/// Live Qibla finder: uses GPS + device compass to point toward the Kaaba.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _location = const QiblaLocationService();

  bool _loading = true;
  String? _error;
  QiblaLocationError? _errorCode;

  double? _lat;
  double? _lng;
  double? _qiblaBearing;
  double? _distanceKm;
  double? _heading;
  StreamSubscription<CompassEvent>? _compassSub;
  bool _compassSupported = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
      _errorCode = null;
    });
    try {
      final pos = await _location.getCurrentPosition();
      final bearing = qiblaBearingDegrees(pos.latitude, pos.longitude);
      final dist = distanceToKaabaKm(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _qiblaBearing = bearing;
        _distanceKm = dist;
        _loading = false;
      });
      _listenCompass();
    } on QiblaLocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _errorCode = e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Something went wrong while reading your location.';
        _errorCode = QiblaLocationError.unavailable;
      });
    }
  }

  void _listenCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      setState(() => _compassSupported = false);
      return;
    }
    _compassSub?.cancel();
    _compassSub = stream.listen(
      (event) {
        final h = event.heading;
        if (h == null || !mounted) return;
        setState(() {
          _heading = (h + 360) % 360;
          _compassSupported = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _compassSupported = false);
      },
    );
  }

  Future<void> _openSettings() async {
    if (_errorCode == QiblaLocationError.serviceDisabled) {
      await _location.openLocationSettings();
    } else {
      await _location.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qibla', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      'Finding your location…',
                      style: TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : _error != null
                ? _errorView()
                : _compassView(),
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
            child: const Icon(Icons.explore_rounded, size: 48, color: Islam307Theme.emerald),
          ),
          const SizedBox(height: 20),
          const Text(
            'Location needed for Qibla',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Islam307Theme.textMuted, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _bootstrap,
            child: const Text('Try again'),
          ),
          const SizedBox(height: 10),
          if (_errorCode == QiblaLocationError.deniedForever ||
              _errorCode == QiblaLocationError.serviceDisabled)
            OutlinedButton(
              onPressed: _openSettings,
              child: Text(
                _errorCode == QiblaLocationError.serviceDisabled
                    ? 'Open location settings'
                    : 'Open app settings',
              ),
            ),
        ],
      ),
    );
  }

  Widget _compassView() {
    final bearing = _qiblaBearing ?? 0;
    final heading = _heading;
    final needle = heading == null
        ? bearing
        : qiblaNeedleRotation(bearing, heading);
    final aligned = heading != null &&
        ((needle > 350) || (needle < 10));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          aligned ? 'Facing the Qibla' : 'Turn until the arrow points up',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: aligned ? Islam307Theme.emerald : Islam307Theme.emeraldDeep,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kaaba · ${bearing.toStringAsFixed(0)}° ${bearingCardinal(bearing)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Center(
          child: _QiblaCompassDial(
            rotationDegrees: needle,
            qiblaBearing: bearing,
            deviceHeading: heading,
            aligned: aligned,
          ),
        ),
        if (!_compassSupported || heading == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Islam307Theme.goldLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Islam307Theme.gold.withValues(alpha: 0.4)),
            ),
            child: const Text(
              'Compass sensor unavailable on this device. Hold the phone flat and use the degree below relative to true north.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _infoTile(
          Icons.explore_rounded,
          'Qibla bearing',
          '${bearing.toStringAsFixed(1)}° from true north (${bearingCardinal(bearing)})',
        ),
        if (heading != null)
          _infoTile(
            Icons.navigation_rounded,
            'Device heading',
            '${heading.toStringAsFixed(1)}° ${bearingCardinal(heading)}',
          ),
        if (_distanceKm != null)
          _infoTile(
            Icons.straighten_rounded,
            'Distance to Kaaba',
            '${_distanceKm!.toStringAsFixed(0)} km',
          ),
        if (_lat != null && _lng != null)
          _infoTile(
            Icons.my_location_rounded,
            'Your location',
            '${_lat!.toStringAsFixed(4)}°, ${_lng!.toStringAsFixed(4)}°',
          ),
        const SizedBox(height: 8),
        Text(
          'Point the top of your phone toward the arrow tip. For best accuracy, calibrate the compass by moving the phone in a figure‑8 and stay away from metal or magnets.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Islam307Theme.textMuted.withValues(alpha: 0.95), height: 1.45),
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Islam307Theme.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Islam307Theme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: Islam307Theme.emerald, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaCompassDial extends StatelessWidget {
  const _QiblaCompassDial({
    required this.rotationDegrees,
    required this.qiblaBearing,
    required this.deviceHeading,
    required this.aligned,
  });

  final double rotationDegrees;
  final double qiblaBearing;
  final double? deviceHeading;
  final bool aligned;

  @override
  Widget build(BuildContext context) {
    final size = math.min(MediaQuery.sizeOf(context).width - 48, 280.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white,
            aligned ? Islam307Theme.emeraldSoft : Islam307Theme.fieldFill,
          ],
        ),
        border: Border.all(
          color: aligned ? Islam307Theme.emerald : Islam307Theme.gold,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (aligned ? Islam307Theme.emerald : Islam307Theme.gold).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Cardinal ticks
          for (final label in const ['N', 'E', 'S', 'W'])
            _cardinal(label, size),
          // Rotating Qibla needle
          Transform.rotate(
            angle: rotationDegrees * math.pi / 180,
            child: CustomPaint(
              size: Size(size * 0.72, size * 0.72),
              painter: _NeedlePainter(aligned: aligned),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${qiblaBearing.toStringAsFixed(0)}°',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Islam307Theme.emeraldDeep,
                  ),
                ),
                Text(
                  bearingCardinal(qiblaBearing),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Islam307Theme.emerald),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardinal(String label, double size) {
    final angle = switch (label) {
      'N' => -math.pi / 2,
      'E' => 0.0,
      'S' => math.pi / 2,
      _ => math.pi,
    };
    final r = size * 0.38;
    return Transform.translate(
      offset: Offset(math.cos(angle) * r, math.sin(angle) * r),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: label == 'N' ? 16 : 13,
          color: label == 'N' ? Islam307Theme.emerald : Islam307Theme.textMuted,
        ),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  _NeedlePainter({required this.aligned});

  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tip = Offset(cx, size.height * 0.06);
    final left = Offset(cx - size.width * 0.08, cy);
    final right = Offset(cx + size.width * 0.08, cy);
    final tail = Offset(cx, size.height * 0.88);

    final tipPaint = Paint()
      ..color = aligned ? Islam307Theme.emerald : const Color(0xFFE11D48)
      ..style = PaintingStyle.fill;
    final tailPaint = Paint()
      ..color = Islam307Theme.gold
      ..style = PaintingStyle.fill;

    final tipPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    final tailPath = Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(tailPath, tailPaint);
    canvas.drawPath(tipPath, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => oldDelegate.aligned != aligned;
}
