import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../account_consents/data/account_consents_remote_data_source.dart';
import '../../account_consents/presentation/widgets/account_consents_group.dart';

/// The Mercatino rules are an ACCEPTANCE (a condition of using the Mercatino,
/// docs/compliance/24), not a consent: a checkbox that starts unchecked, with
/// the rules shown, recorded with the version and the date like the radar's
/// contribution rules. Needed to publish or change an ad and to write a
/// message; browsing needs nothing.
const marketplaceRulesKey = 'marketplace_rules';

/// True when the owner may go on: the current version of the rules is already
/// accepted, or has just been. False when they leave the question ("Non ora").
///
/// It does not get in the way when the rules cannot be checked: an unreachable
/// server leaves the decision to the server (which refuses a write on its own
/// when the rules are required), and a catalog without the rules has none to ask.
Future<bool> ensureMarketplaceRulesAccepted(
  BuildContext context, {
  AccountConsentsRemoteDataSource? dataSource,
}) async {
  final source = dataSource ?? HttpAccountConsentsRemoteDataSource();
  final result = await source.fetch();
  final snapshot = result.fold(onSuccess: (value) => value, onFailure: (_) => null);
  if (snapshot == null) return true;
  final entry = snapshot.catalog[marketplaceRulesKey];
  if (entry == null) return true;
  final decision = snapshot.decisions[marketplaceRulesKey];
  if (consentDecisionIsCurrent(decision, entry) && (decision?.granted ?? false)) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RulesDialog(text: entry.text),
  );
  if (accepted != true) return false;
  final saved = await source.setConsent(consentKey: marketplaceRulesKey, granted: true);
  return saved.isSuccess;
}

class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.text});

  final String text;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  bool _read = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.marketplaceRulesTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.text, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            CheckboxListTile(
              key: const ValueKey('marketplace-rules-checkbox'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              // Never pre-ticked: the owner ticks it to accept.
              value: _read,
              onChanged: (value) => setState(() => _read = value ?? false),
              title: Text(l10n.marketplaceRulesAccept, style: AppTextStyles.bodySmall),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('marketplace-rules-not-now'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.consentChoicesNotNow),
        ),
        TextButton(
          key: const ValueKey('marketplace-rules-continue'),
          onPressed: _read ? () => Navigator.of(context).pop(true) : null,
          child: Text(l10n.commonContinue),
        ),
      ],
    );
  }
}
