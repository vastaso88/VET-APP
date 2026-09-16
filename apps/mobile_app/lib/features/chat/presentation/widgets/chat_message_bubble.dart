import 'package:flutter/material.dart';

import '../../../../design_system/atoms/ai_disclosure_badge.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/chat_models.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.author == ChatMessageAuthor.user;
    final backgroundColor = isUser ? AppColors.primary : AppColors.surface;
    final foregroundColor = isUser ? AppColors.onPrimary : AppColors.text;
    final showAiDisclosure = !isUser && message.aiGenerated;

    return Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: isUser ? null : Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: foregroundColor,
                  ),
                ),
                if (showAiDisclosure) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const AiDisclosureBadge(),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.timeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: isUser
                            ? AppColors.onPrimary.withValues(alpha: 0.72)
                            : AppColors.mutedText,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
