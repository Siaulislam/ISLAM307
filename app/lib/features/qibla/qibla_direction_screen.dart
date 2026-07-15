import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/islam307_theme.dart';

class QiblaDirectionScreen extends StatefulWidget {
  const QiblaDirectionScreen({super.key});

  @override
  State<QiblaDirectionScreen> createState() => _QiblaDirectionScreenState();
}

class _QiblaDirectionScreenState extends State<QiblaDirectionScreen> {
  static const _kaabaLatitude = 21.4225;
  static const _kaabaLongitude = 39.8262;

  StreamSubscription<CompassEvent>? _compassSubscription;
  Position? _position;
  double? _heading;
  double? _qiblaBearing;
  String? _error;
  bool _loading = true;

  double? get _relativeDirection {
    if (_qiblaBearing == null || _heading == null) return null;
    return (_qiblaBearing! - _heading! + 360) % 360;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadLocation();
    _listenToCompass();
  }

  Future<void> _loadLocation() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _QiblaException(
          'Location services are off. Turn on GPS and tap Refresh.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _QiblaException(
          'Location permission is required to calculate Qibla.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _QiblaException(
          'Location permission is permanently denied. Enable it in Settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final bearing = _calculateBearing(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _qiblaBearing = bearing;
        _loading = false;
      });
    } on _QiblaException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not read the device location. Check GPS and permission.';
        _loading = false;
      });
    }
  }

  void _listenToCompass() {
    _compassSubscription?.cancel();
    final events = FlutterCompass.events;
    if (events == null) {
      if (mounted) {
        setState(() {
          _error ??=
              'This device has no compass sensor. Use the bearing from true north.';
        });
      }
      return;
    }
    _compassSubscription = events.listen((event) {
      final heading = event.heading;
      if (!mounted || heading == null) return;
      setState(() => _heading = (heading + 360) % 360);
    });
  }

  double _calculateBearing(double latitude, double longitude) {
    final phi1 = latitude * math.pi / 180;
    final phi2 = _kaabaLatitude * math.pi / 180;
    final deltaLongitude = (_kaabaLongitude - longitude) * math.pi / 180;
    final y = math.sin(deltaLongitude);
    final x = math.cos(phi1) * math.tan(phi2) -
        math.sin(phi1) * math.cos(deltaLongitude);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Qibla Direction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: _loading ? null : _loadLocation,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                _compass(),
                const SizedBox(height: 24),
                if (_qiblaBearing != null)
                  Text(
                    _relativeDirection == null
                        ? 'Qibla bearing: ${_qiblaBearing!.toStringAsFixed(1)}° from true north'
                        : 'Turn ${_relativeDirection!.toStringAsFixed(1)}° clockwise',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Islam307Theme.emeraldDeep,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  _heading == null
                      ? 'Compass heading unavailable'
                      : 'Device heading: ${_heading!.toStringAsFixed(1)}°',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Islam307Theme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_position != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Location: ${_position!.latitude.toStringAsFixed(5)}, '
                    '${_position!.longitude.toStringAsFixed(5)}\n'
                    'Accuracy: ±${_position!.accuracy.toStringAsFixed(0)} m',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Islam307Theme.textMuted,
                      height: 1.45,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  'Hold the phone flat and away from metal or magnets. Move it in a figure-eight pattern if the compass is unstable.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Islam307Theme.textMuted,
                    height: 1.5,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadLocation,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: Geolocator.openAppSettings,
                    child: const Text('Open app settings'),
                  ),
                  TextButton(
                    onPressed: Geolocator.openLocationSettings,
                    child: const Text('Open location settings'),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _compass() {
    final direction = _relativeDirection ?? _qiblaBearing ?? 0;
    return Center(
      child: SizedBox(
        width: 290,
        height: 290,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).cardColor,
                border: Border.all(
                  color: Islam307Theme.emerald.withValues(alpha: 0.35),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 12,
              child: Text(
                'N',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Islam307Theme.emeraldDeep,
                ),
              ),
            ),
            const Positioned(
              bottom: 12,
              child: Text('S', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const Positioned(
              left: 14,
              child: Text('W', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const Positioned(
              right: 14,
              child: Text('E', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            AnimatedRotation(
              turns: direction / 360,
              duration: const Duration(milliseconds: 180),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.navigation_rounded,
                    size: 100,
                    color: Islam307Theme.gold,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Islam307Theme.emerald,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'KAABA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QiblaException implements Exception {
  const _QiblaException(this.message);

  final String message;
}
