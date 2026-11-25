import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../l10n/l10n.dart';
import '../../account_consents/application/chat_notice.dart';
import '../data/chat_demo_store.dart';
import 'pages/chat_conversation_detail_page.dart';

/// Starts a new chat about a pet and opens it. The one way in, shared by the
/// pet's Chat tab and by Home: first the number of chats per pet, then the
/// notice of the first chat, and only then the conversation. The limits of the
/// plan are the server's and are met when a question is sent.
Future<void> startChatWithPet(
  BuildContext context, {
  required String petId,
  required String petName,
  Future<bool> Function(BuildContext context) noticeGate = ChatNotice.ensure,
}) async {
  final store = ChatDemoStore.instance;
  if (!store.canStartConversation(petId)) {
    _showLimitDialog(context, petName);
    return;
  }
  // Before the chat exists: declining must not leave an empty one in the list.
  if (!await noticeGate(context) || !context.mounted) return;

  final conversation = store.startConversation(petId: petId, petName: petName);
  // Not awaited: the caller is done as soon as the chat is open.
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatConversationDetailPage(
        conversationId: conversation.id,
        initialConversation: conversation,
      ),
    ),
  );
}

void _showLimitDialog(BuildContext context, String petName) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text(context.l10n.petsDetailChatLimitTitle),
      content: Text(
        context.l10n.petsDetailChatLimitMessage(ChatDemoStore.maxConversationsPerPet, petName),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.petsDetailChatLimitOk),
        ),
      ],
    ),
  );
}
