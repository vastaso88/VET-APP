import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../l10n/l10n.dart';
import 'page_header.dart';
import 'empty_state.dart';

/// Generic placeholder for a feature that's planned but not built yet.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: title),
      body: CenteredPageState(
        child: EmptyState.icon(
          icon: icon,
          title: context.l10n.sharedComingSoon,
          text: description,
        ),
      ),
    );
  }
}
