import 'package:flutter/material.dart';

/// A new page slides in over the old one, which stays still: the words of two
/// pages are never seen one through the other, as they were in a cross-fade.
/// With "reduce motion" the page simply changes.
class SlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const SlidePageTransitionsBuilder();

  static final _slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return SlideTransition(
      position: animation.drive(_slide),
      textDirection: Directionality.of(context),
      transformHitTests: false,
      child: child,
    );
  }
}
