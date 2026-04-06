import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';

/// A responsive layout widget that renders different widgets based on screen size.
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   mobile: MobileWidget(),
///   tablet: TabletWidget(),
///   desktop: DesktopWidget(),
/// )
/// ```
///
/// If a specific breakpoint widget is not provided, it falls back to the next
/// smaller breakpoint: desktop -> tablet -> mobile.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Widget to display on mobile screens (< 640px).
  final Widget mobile;

  /// Widget to display on tablet screens (640px - 1023px).
  /// Falls back to [mobile] if not provided.
  final Widget? tablet;

  /// Widget to display on desktop screens (>= 1024px).
  /// Falls back to [tablet] or [mobile] if not provided.
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).largerThan(TABLET)) {
      return desktop ?? tablet ?? mobile;
    }
    if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) {
      return tablet ?? mobile;
    }
    return mobile;
  }
}

/// A widget that constrains its child to a maximum width on larger screens.
///
/// On mobile, the child takes full width. On tablet and desktop, the child
/// is centered and constrained to [maxWidth].
class ResponsiveConstrainedBox extends StatelessWidget {
  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = 480,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    }
    return child;
  }
}
