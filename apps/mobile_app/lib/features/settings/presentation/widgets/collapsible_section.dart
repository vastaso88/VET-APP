import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// A settings section with a tappable header (title + chevron) that shows or
/// hides its body. Controlled by the parent, which keeps a single "open
/// section" so the page behaves as an accordion. Whenever the section opens it
/// scrolls itself so the header sits at the top of the viewport.
///
/// Reusable on purpose: Impostazioni is touched by several sessions at once —
/// wrap a section's existing widgets in this instead of writing a new header.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.sectionId,
    required this.title,
    required this.children,
    required this.expanded,
    required this.onToggle,
  });

  /// Stable id, handed back to [onToggle] (e.g. 'abbonamento', 'localita').
  final String sectionId;
  final String title;
  final List<Widget> children;
  final bool expanded;
  final ValueChanged<String> onToggle;

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  static const _animation = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    if (widget.expanded) _scrollIntoViewSoon();
  }

  @override
  void didUpdateWidget(CollapsibleSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) _scrollIntoViewSoon();
  }

  /// Waits for the previously open section to finish collapsing, otherwise the
  /// header would still move after the scroll has been computed.
  void _scrollIntoViewSoon() {
    unawaited(
      Future<void>.delayed(_animation + const Duration(milliseconds: 40), () {
        if (!mounted || !widget.expanded) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onToggle(widget.sectionId),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(letterSpacing: 0.8),
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.expanded ? 0.5 : 0,
                    duration: _animation,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.mutedText,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: _animation,
          crossFadeState: widget.expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
