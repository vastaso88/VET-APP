import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

/// A settings section with a tappable header (title + chevron) that
/// collapses/expands its body. Remembers the open/closed state per
/// [sectionId] in shared_preferences, so it survives app restarts.
///
/// Reusable on purpose: Impostazioni is touched by several sessions at once
/// (Foto e video, Notifiche, Località, ...) — wrap a section's existing
/// widgets in this instead of writing a new header each time.
class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    super.key,
    required this.sectionId,
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
  });

  /// Stable id for the shared_preferences key — keep it short and unique
  /// within this page (e.g. 'abbonamento', 'localita').
  final String sectionId;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<CollapsibleSection> createState() => CollapsibleSectionState();
}

class CollapsibleSectionState extends State<CollapsibleSection> {
  static const _keyPrefix = 'settings_section_expanded.';

  late bool _expanded = widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getBool('$_keyPrefix${widget.sectionId}');
    if (stored != null && mounted) setState(() => _expanded = stored);
  }

  Future<void> _persist(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('$_keyPrefix${widget.sectionId}', value);
  }

  /// Opens the section if it's collapsed (used when the owner is sent here
  /// from elsewhere, e.g. "Scegli un indirizzo" → Località). No-op if
  /// already open.
  void expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    unawaited(_persist(true));
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    unawaited(_persist(_expanded));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggle,
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
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mutedText, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}
