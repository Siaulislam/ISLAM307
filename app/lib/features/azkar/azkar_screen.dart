import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/islam307_theme.dart';
import 'azkar_catalog.dart';

/// Professional Azkar Tasbeeh counter — tap to count 1, 2, 3…
class AzkarScreen extends StatefulWidget {
  const AzkarScreen({super.key});

  @override
  State<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends State<AzkarScreen> with SingleTickerProviderStateMixin {
  static const _countPrefix = 'azkar_count_';
  static const _dhikrKey = 'azkar_active_dhikr';
  static const _vibrateKey = 'azkar_vibrate';
  static const _targetKey = 'azkar_target_';

  late AzkarDhikr _dhikr;
  int _count = 0;
  int _target = 33;
  bool _vibrate = true;
  bool _ready = false;

  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _dhikr = kAzkarCatalog.first;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _pulseScale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_dhikrKey);
    final found = kAzkarCatalog.where((d) => d.id == id);
    final dhikr = found.isEmpty ? kAzkarCatalog.first : found.first;
    final count = p.getInt('$_countPrefix${dhikr.id}') ?? 0;
    final target = p.getInt('$_targetKey${dhikr.id}') ?? dhikr.defaultTarget;
    final vibrate = p.getBool(_vibrateKey) ?? true;
    if (!mounted) return;
    setState(() {
      _dhikr = dhikr;
      _count = count;
      _target = target;
      _vibrate = vibrate;
      _ready = true;
    });
  }

  Future<void> _persistCount() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_countPrefix${_dhikr.id}', _count);
    await p.setString(_dhikrKey, _dhikr.id);
  }

  Future<void> _persistPrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_vibrateKey, _vibrate);
    await p.setInt('$_targetKey${_dhikr.id}', _target);
    await p.setString(_dhikrKey, _dhikr.id);
  }

  Future<void> _selectDhikr(AzkarDhikr d) async {
    final p = await SharedPreferences.getInstance();
    final count = p.getInt('$_countPrefix${d.id}') ?? 0;
    final target = p.getInt('$_targetKey${d.id}') ?? d.defaultTarget;
    setState(() {
      _dhikr = d;
      _count = count;
      _target = target;
    });
    await p.setString(_dhikrKey, d.id);
  }

  Future<void> _tap() async {
    await _pulse.forward();
    await _pulse.reverse();
    setState(() => _count += 1);
    if (_vibrate) {
      await HapticFeedback.lightImpact();
      if (_target > 0 && _count % _target == 0) {
        await HapticFeedback.mediumImpact();
      }
    }
    await _persistCount();
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset counter?'),
        content: Text('Clear the count for ${_dhikr.transliteration}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _count = 0);
    await _persistCount();
    if (_vibrate) await HapticFeedback.selectionClick();
  }

  int get _cycleProgress {
    if (_target <= 0) return 0;
    return _count % _target;
  }

  int get _completedCycles {
    if (_target <= 0) return 0;
    return _count ~/ _target;
  }

  double get _progress {
    if (_target <= 0) return 0;
    final p = _cycleProgress / _target;
    return _cycleProgress == 0 && _count > 0 ? 1.0 : p;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Islam307Theme.darkBg : const Color(0xFFF7FBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Azkar', style: TextStyle(fontWeight: FontWeight.w800)),
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
            tooltip: _vibrate ? 'Vibration on' : 'Vibration off',
            onPressed: () async {
              setState(() => _vibrate = !_vibrate);
              await _persistPrefs();
              if (_vibrate) await HapticFeedback.selectionClick();
            },
            icon: Icon(
              _vibrate ? Icons.vibration_rounded : Icons.phone_android_rounded,
              color: _vibrate ? Islam307Theme.emerald : Islam307Theme.textMuted,
            ),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      children: [
                        _dhikrHeader(isDark),
                        const SizedBox(height: 18),
                        Center(child: _counterDevice(isDark)),
                        const SizedBox(height: 18),
                        _statsRow(),
                        const SizedBox(height: 16),
                        _targetChips(),
                        const SizedBox(height: 16),
                        const Text(
                          'Choose dhikr',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep),
                        ),
                        const SizedBox(height: 10),
                        ...kAzkarCatalog.map(_dhikrTile),
                      ],
                    ),
                  ),
                  _bottomTapBar(isDark),
                ],
              ),
            ),
    );
  }

  Widget _dhikrHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [Islam307Theme.darkCard, const Color(0xFF0F2A24)]
              : [Colors.white, Islam307Theme.emeraldSoft.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Islam307Theme.gold.withValues(alpha: 0.45), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Islam307Theme.emerald.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _dhikr.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: Islam307Theme.arabic(
              size: 34,
              weight: FontWeight.w700,
              color: isDark ? Colors.white : Islam307Theme.emeraldDeep,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dhikr.transliteration,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Islam307Theme.emerald),
          ),
          const SizedBox(height: 4),
          Text(
            _dhikr.meaning,
            textAlign: TextAlign.center,
            style: TextStyle(color: Islam307Theme.textMuted.withValues(alpha: 0.95), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _counterDevice(bool isDark) {
    final display = _count.toString().padLeft(2, '0');
    return ScaleTransition(
      scale: _pulseScale,
      child: SizedBox(
        width: 260,
        height: 320,
        child: CustomPaint(
          painter: _TasbeehBodyPainter(isDark: isDark),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              children: [
                // Progress ring + digital count
                SizedBox(
                  width: 150,
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(
                          painter: _ProgressRingPainter(
                            progress: _target > 0 ? _progress : 0,
                            track: isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0),
                            fill: Islam307Theme.emerald,
                          ),
                        ),
                      ),
                      Container(
                        width: 112,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Islam307Theme.gold.withValues(alpha: 0.55), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          display.length > 4 ? '$_count' : display,
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF8FAFC),
                            letterSpacing: 2,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _deviceSideButton(
                      icon: _vibrate ? Icons.vibration_rounded : Icons.mobile_off_rounded,
                      onTap: () async {
                        setState(() => _vibrate = !_vibrate);
                        await _persistPrefs();
                      },
                    ),
                    _deviceSideButton(
                      icon: Icons.refresh_rounded,
                      onTap: _reset,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _tap,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF14B8A6), Islam307Theme.emeraldDeep],
                      ),
                      border: Border.all(color: Islam307Theme.goldLight, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Islam307Theme.emerald.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deviceSideButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF1E293B),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Islam307Theme.emerald, size: 22),
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(
          child: _statCard('This round', _target > 0 ? '$_cycleProgress / $_target' : '$_count'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard('Cycles', '$_completedCycles'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard('Total', '$_count'),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Islam307Theme.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Islam307Theme.cardBorder),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Islam307Theme.emeraldDeep)),
        ],
      ),
    );
  }

  Widget _targetChips() {
    const options = [33, 99, 100, 0];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((t) {
        final selected = _target == t;
        final label = t == 0 ? 'Free' : '$t';
        return ChoiceChip(
          label: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : null)),
          selected: selected,
          selectedColor: Islam307Theme.emerald,
          onSelected: (_) async {
            setState(() => _target = t);
            await _persistPrefs();
          },
        );
      }).toList(),
    );
  }

  Widget _dhikrTile(AzkarDhikr d) {
    final selected = d.id == _dhikr.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? Islam307Theme.emeraldSoft : Islam307Theme.fieldFill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _selectDhikr(d),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Islam307Theme.emerald.withValues(alpha: 0.5) : Islam307Theme.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.arabic,
                        textDirection: TextDirection.rtl,
                        style: Islam307Theme.arabic(size: 20, weight: FontWeight.w600, height: 1.5),
                      ),
                      Text(d.transliteration, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(d.meaning, style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
                    ],
                  ),
                ),
                if (selected) const Icon(Icons.check_circle_rounded, color: Islam307Theme.emerald),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomTapBar(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? Islam307Theme.darkCard : Colors.white,
        border: Border(top: BorderSide(color: Islam307Theme.cardBorder.withValues(alpha: 0.8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FilledButton(
          onPressed: _tap,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 58),
            backgroundColor: Islam307Theme.emerald,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: const Text(
            'Tap to count  ·  اضغط للعد',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _TasbeehBodyPainter extends CustomPainter {
  _TasbeehBodyPainter({required this.isDark});
  final bool isDark;

  RRect _body(Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    return RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(w * 0.28),
      topRight: Radius.circular(w * 0.28),
      bottomLeft: Radius.circular(w * 0.34),
      bottomRight: Radius.circular(w * 0.34),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final r = _body(size);

    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
            : const [Color(0xFF334155), Color(0xFF0F172A)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, body);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = Islam307Theme.emerald;
    canvas.drawRRect(r.deflate(2), rim);

    final goldRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Islam307Theme.gold.withValues(alpha: 0.7);
    canvas.drawRRect(r.deflate(7), goldRim);

    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [Colors.white.withValues(alpha: 0.12), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));
    canvas.drawRRect(r.deflate(10), highlight);
  }

  @override
  bool shouldRepaint(covariant _TasbeehBodyPainter oldDelegate) => oldDelegate.isDark != isDark;
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({required this.progress, required this.track, required this.fill});
  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, radius, trackPaint);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fill != fill;
}
