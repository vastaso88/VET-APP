import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/listing_content.dart';

/// Shows the notices the backend asked for, each with its own box, never
/// pre-ticked. True only when the seller ticked every box and chose to publish.
Future<bool> confirmListingContent(
  BuildContext context,
  ListingConfirmationRequiredException required,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ListingContentDialog(required: required),
  );
  return confirmed ?? false;
}

class ListingContentDialog extends StatefulWidget {
  const ListingContentDialog({super.key, required this.required});

  final ListingConfirmationRequiredException required;

  @override
  State<ListingContentDialog> createState() => _ListingContentDialogState();
}

class _ListingContentDialogState extends State<ListingContentDialog> {
  final Set<ListingContentNotice> _ticked = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notices = widget.required.notices;
    final allTicked = notices.every(_ticked.contains);
    // One notice: its title is the dialog's. Two: each keeps its own.
    return AlertDialog(
      scrollable: true,
      title: notices.length == 1 ? Text(_title(l10n, notices.single)) : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final notice in notices) ...[
            if (notices.length > 1) ...[
              Text(_title(l10n, notice), style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(_body(l10n, notice), style: AppTextStyles.bodySmall),
            if (widget.required.words[notice] case final words?) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.marketplaceContentFoundWords(words.join(', ')),
                style: AppTextStyles.caption,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: ValueKey('marketplace-content-${notice.wire}'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _ticked.contains(notice),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  _ticked.add(notice);
                } else {
                  _ticked.remove(notice);
                }
              }),
              title: Text(_confirm(l10n, notice), style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
      // Same weight for both: going back to the text is as easy as publishing.
      actions: [
        OutlinedButton(
          key: const ValueKey('marketplace-content-edit'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.marketplaceContentEdit),
        ),
        OutlinedButton(
          key: const ValueKey('marketplace-content-publish'),
          onPressed: allTicked ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.marketplaceContentPublish),
        ),
      ],
    );
  }

  String _title(AppLocalizations l10n, ListingContentNotice notice) => switch (notice) {
        ListingContentNotice.food => l10n.marketplaceContentFoodTitle,
        ListingContentNotice.activeSubstance => l10n.marketplaceContentActiveTitle,
      };

  String _body(AppLocalizations l10n, ListingContentNotice notice) => switch (notice) {
        ListingContentNotice.food => l10n.marketplaceContentFoodBody,
        ListingContentNotice.activeSubstance => l10n.marketplaceContentActiveBody,
      };

  String _confirm(AppLocalizations l10n, ListingContentNotice notice) => switch (notice) {
        ListingContentNotice.food => l10n.marketplaceContentFoodConfirm,
        ListingContentNotice.activeSubstance => l10n.marketplaceContentActiveConfirm,
      };
}
