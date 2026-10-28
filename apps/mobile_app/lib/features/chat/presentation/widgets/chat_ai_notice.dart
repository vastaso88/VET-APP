import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';

/// The transparency notice of the chat (AI Act, art. 50): the owner is told
/// they are talking to an artificial intelligence that does not replace the
/// vet, with the emergency line. Shown under the title in every state of
/// the screen, so it is there on a conversation already under way too, and
/// repeated at the top of an exported conversation or a shared summary.
class ChatAiNotice extends StatelessWidget {
  const ChatAiNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.secondaryText),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                context.l10n.chatAiNotice,
                style: const TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
