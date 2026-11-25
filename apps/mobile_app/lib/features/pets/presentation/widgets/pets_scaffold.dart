import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../shared/widgets/page_header.dart';

/// Frame of the pages about the animals: the header of every page and the body
/// within the one margin.
class PetsScaffold extends StatelessWidget {
  const PetsScaffold({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.actions,
    this.onBack,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget body;

  /// Beside the back arrow: pass a [PetAvatar] on pages tied to one real pet
  /// (detail/edit) so the header shows its actual photo or initial.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageHeader(
        title: title,
        subtitle: subtitle,
        actions: actions ?? const [],
        badge: badge,
        onBack: onBack,
        showBack: onBack != null,
        // A page of the bar at the bottom: no arrow, no animal.
        root: onBack == null && badge == null,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: body,
        ),
      ),
    );
  }
}
