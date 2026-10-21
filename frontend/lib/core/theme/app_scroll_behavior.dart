import 'package:flutter/material.dart';

/// Keep Material's platform scrolling, without stretching/glowing the content
/// when a vertical or horizontal scroll reaches either boundary.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
