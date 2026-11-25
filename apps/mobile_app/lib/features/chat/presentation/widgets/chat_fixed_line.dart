import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../l10n/l10n.dart';

/// The fixed line under the writing field (docs/compliance/22 §2): an AI answers and
/// can be wrong, it does not replace the vet, the app does not handle emergencies. The
/// only notice of the conversation (the first chat has its own screen; every answer says
/// "Generato da IA"): always there, never dismissed, and at the top of what is exported.
class ChatFixedLine extends StatelessWidget {
  const ChatFixedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        context.l10n.chatFixedLine,
        key: const ValueKey('chat-fixed-line'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.secondaryText, fontSize: 12, height: 1.25),
      ),
    );
  }
}
