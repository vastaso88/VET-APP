import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../../domain/account_consent_models.dart';

/// The one screen before the first chat (docs/compliance/22 §5 and §9): an AI answers, the
/// provider the questions go to, and Quokka does not handle emergencies. The emergencies have
/// their own box, never pre-ticked, with their short version in front of the owner (no
/// scrolling, not a link). Shown when the first chat is opened (see ChatNotice): "Non accetto",
/// like going back, only leaves the chat. Closes with true when accepted.
class EmergencyNoticeGatePage extends StatefulWidget {
  const EmergencyNoticeGatePage({super.key, this.catalogText});

  /// The short text of the server's catalog, when it is newer than the one built into this
  /// app (its version is the one sent with the acceptance). Null: the app's own text.
  final String? catalogText;

  @override
  State<EmergencyNoticeGatePage> createState() => _EmergencyNoticeGatePageState();
}

class _EmergencyNoticeGatePageState extends State<EmergencyNoticeGatePage> {
  bool _understood = false; // never pre-ticked

  /// The text of the screen. It ends with the emergencies' short version (a test checks it, in
  /// every language): a newer one of the server takes its place, because its version is the one
  /// recorded.
  String _body(AppLocalizations l10n) {
    final newer = widget.catalogText;
    if (newer == null) return l10n.firstChatBody;
    final body = l10n.firstChatBody;
    final clause = l10n.emergencyNoticeShort;
    return body.endsWith(clause)
        ? '${body.substring(0, body.length - clause.length)}$newer'
        : '$body $newer';
  }

  void _openLegal(String consentKey, String title, {bool shareable = false}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalTextPage(
          consentKey: consentKey,
          title: title,
          shareable: shareable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(l10n.firstChatTitle, style: AppTextStyles.title),
            ),
            const SizedBox(height: AppSpacing.md),
            // The short version, always in view: not behind a link.
            Text(_body(l10n), style: AppTextStyles.body),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _openLegal(
                  AccountConsentKeys.privacyPolicy,
                  l10n.settingsPrivacyPolicyFullTitle,
                  shareable: true,
                ),
                child: Text(l10n.firstChatPrivacyLink),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    _openLegal(AccountConsentKeys.termsOfService, l10n.authTermsOfServiceLabel),
                child: Text(l10n.emergencyNoticeFullLink),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (value) => setState(() => _understood = value ?? false),
              title: Text(l10n.emergencyNoticeCheckbox, style: AppTextStyles.bodySmall),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _understood ? () => Navigator.of(context).pop(true) : null,
              child: Text(l10n.firstChatAccept),
            ),
            const SizedBox(height: AppSpacing.sm),
            // The same weight as "Accetto": same size, same place in the column.
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.emergencyNoticeDecline),
            ),
          ],
        ),
      ),
    );
  }
}
