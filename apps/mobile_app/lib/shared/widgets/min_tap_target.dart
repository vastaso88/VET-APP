import 'package:flutter/material.dart';

/// Gives a small control (a filter pill, a tight icon) a touch area of at
/// least 48 x 48 logical pixels without changing how big it looks: the child
/// stays centred at its own size, the empty space around it answers to the
/// same tap. The child may carry its own tap (and its own ripple and spoken
/// name); the tap here is only for the margin around it.
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({super.key, required this.onTap, required this.child, this.size = 48});

  final VoidCallback? onTap;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // The child already speaks for the control; no second button.
      excludeFromSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: size, minWidth: size),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      ),
    );
  }
}
