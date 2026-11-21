import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

/// Before any "Attiva" outside Settings: what the consent is, where the data
/// goes and how to take it back (a few lines), with the way to read the whole
/// text. The consent is saved only when the owner presses «Attiva», and what is
/// recorded is the version of the text shown here (docs/compliance/23, §2.1).
///
/// «Attiva» and «Non ora» weigh the same: nothing pushes towards a yes, and the
/// app and the chat work without it. Returns true only for «Attiva».
///
/// [summary] is the short text; [fullText] (optional) opens under it when the
/// owner taps «Leggi come viene usata». Turning a consent OFF never asks: that
/// is one tap, with no confirmation in the way.
Future<bool> askToActivateConsent(
  BuildContext context, {
  required String title,
  required String summary,
  String? fullText,
}) async {
  final activate = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _ActivationDialog(title: title, summary: summary, fullText: fullText),
  );
  return activate == true;
}

class _ActivationDialog extends StatefulWidget {
  const _ActivationDialog({required this.title, required this.summary, this.fullText});

  final String title;
  final String summary;
  final String? fullText;

  @override
  State<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<_ActivationDialog> {
  bool _showFull = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fullText = widget.fullText;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.summary, style: AppTextStyles.bodySmall),
            if (fullText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                key: const ValueKey('consent-read-how'),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => setState(() => _showFull = !_showFull),
                child: Text(_showFull ? l10n.commonClose : l10n.petsConsentReadHow),
              ),
              if (_showFull) Text(fullText, style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('consent-activate-not-now'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.consentChoicesNotNow),
        ),
        TextButton(
          key: const ValueKey('consent-activate-yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.petsConsentProposalActivate),
        ),
      ],
    );
  }
}
