import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/branding/islam307_logo.dart';
import '../../core/theme/islam307_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2800), () {
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
      backgroundColor: const Color(0xFFF7F4EE),
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Islam307Logo(height: 320),
            ),
          ),
        ),
      ),
    );
  }
}
