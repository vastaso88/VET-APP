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
                isUser
                    ? Text(
                        message.text,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: foregroundColor,
                        ),
                      )
                    : _MarkdownLiteText(
                        text: message.text,
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

/// Minimal Markdown renderer for assistant replies: bold (`**text**`) and
/// bullet lines (`* `/`- `) are the only Markdown a real LLM reply tends to
/// use, so this covers just that instead of pulling in a full Markdown
/// package and remapping its own styles onto ours.
class _MarkdownLiteText extends StatelessWidget {
  const _MarkdownLiteText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  static final _boldPattern = RegExp(r'\*\*(.+?)\*\*');
  static final _bulletPattern = RegExp(r'^[*-]\s+(.*)');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final line in text.split('\n')) _buildLine(line)],
    );
  }

  Widget _buildLine(String line) {
    if (line.trim().isEmpty) {
      return const SizedBox(height: AppSpacing.xs);
    }

    final bulletMatch = _bulletPattern.firstMatch(line);
    if (bulletMatch != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: style),
            Expanded(child: _richText(bulletMatch.group(1)!)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _richText(line),
    );
  }

  Widget _richText(String line) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _boldPattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor)));
    }
    return RichText(text: TextSpan(style: style, children: spans));
  }
}
