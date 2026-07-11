import 'package:flutter/material.dart';

/// Responsive breakpoints — phones, tablets, foldables (no hardcoded layouts in features).
class I307Breakpoints {
  static const phoneMax = 600.0;
  static const tabletMax = 1024.0;

  static bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < phoneMax;
  static bool isTablet(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= phoneMax && w < tabletMax;
  }

  static bool isDesktopOrLargeTablet(BuildContext c) => MediaQuery.sizeOf(c).width >= tabletMax;

  static bool useMasterDetail(BuildContext c) => MediaQuery.sizeOf(c).width >= 720;

  static double contentMaxWidth(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= tabletMax) return 960;
    if (w >= phoneMax) return 820;
    return w;
  }

  static int gridColumns(BuildContext c, {int phone = 2, int tablet = 3, int desktop = 4}) {
    if (isDesktopOrLargeTablet(c)) return desktop;
    if (isTablet(c)) return tablet;
    return phone;
  }

  static EdgeInsets pagePadding(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= tabletMax) return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    if (w >= phoneMax) return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}
