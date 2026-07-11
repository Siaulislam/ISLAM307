import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/islam307_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) context.go('/welcome');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(painter: _PatternPainter()),
            ),
          ),
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Islam307Theme.emerald, Islam307Theme.emeraldDeep],
                      ),
                      boxShadow: [
                        BoxShadow(color: Islam307Theme.emerald.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
                      ],
                      border: Border.all(color: Islam307Theme.goldLight, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('307', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('ISLAM', style: TextStyle(color: Islam307Theme.goldLight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text('ISLAM 307', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
                  const SizedBox(height: 8),
                  const Text('100% Offline Islamic Companion', style: TextStyle(color: Islam307Theme.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Islam307Theme.emerald;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      for (var y = 0.0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
