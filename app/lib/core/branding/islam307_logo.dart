import 'package:flutter/material.dart';
import '../theme/islam307_theme.dart';

/// Official ISLAM 307 brand mark (calligraphy · 307 · tagline).
class Islam307Logo extends StatelessWidget {
  const Islam307Logo({
    super.key,
    this.height = 220,
    this.width,
    this.fit = BoxFit.contain,
  });

  final double height;
  final double? width;
  final BoxFit fit;

  static const assetPath = 'assets/branding/islam307_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _FallbackMark(size: height.clamp(48, 120)),
    );
  }
}

/// Compact header/footer brand strip for dashboard chrome.
class Islam307BrandBar extends StatelessWidget {
  const Islam307BrandBar({
    super.key,
    this.compact = true,
    this.showTagline = false,
    this.alignment = MainAxisAlignment.start,
  });

  final bool compact;
  final bool showTagline;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 40.0 : 52.0;
    return Row(
      mainAxisAlignment: alignment,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
            color: const Color(0xFFF7F4EE),
            child: Image.asset(
              Islam307Logo.assetPath,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _FallbackMark(size: logoSize),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ISLAM 307',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Islam307Theme.emeraldDeep,
                  letterSpacing: 0.2,
                ),
              ),
              if (showTagline)
                const Text(
                  'KNOWLEDGE · GUIDANCE · PEACE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Islam307Theme.gold,
                    letterSpacing: 0.6,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FallbackMark extends StatelessWidget {
  const _FallbackMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          colors: [Islam307Theme.emerald, Islam307Theme.emeraldDeep],
        ),
        border: Border.all(color: Islam307Theme.goldLight, width: 2),
      ),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('307', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
          Text('ISLAM', style: TextStyle(color: Islam307Theme.goldLight, fontWeight: FontWeight.w800, fontSize: 8, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
