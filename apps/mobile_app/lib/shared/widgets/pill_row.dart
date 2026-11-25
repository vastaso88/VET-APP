import 'package:flutter/material.dart';

/// Filter pills on one row that scrolls sideways. As tall as its pills (48 px
/// to touch at least, see MinTapTarget): large text is never cut by a fixed
/// height. [children] carry their own spacing.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(children: children),
      ),
    );
  }
}
