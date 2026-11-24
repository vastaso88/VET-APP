import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/presentation/pages/legal_text_page.dart';
import '../../domain/account_consent_models.dart';

/// The acknowledgement that Quokka does not handle emergencies (docs/compliance/22 §5):
/// its own page and its own box, never pre-ticked, with the short version in front of the
/// owner (no scrolling, not a link). Shown when the first chat is opened (see ChatNotice):
/// "Non accetto", like going back, only leaves the chat. Closes with true when accepted.
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
              child: Text(l10n.emergencyNoticeTitle, style: AppTextStyles.title),
            ),
            const SizedBox(height: AppSpacing.md),
            // The short version, always in view: not behind a link.
            Text(widget.catalogText ?? l10n.emergencyNoticeShort, style: AppTextStyles.body),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LegalTextPage(
                      consentKey: AccountConsentKeys.termsOfService,
                      title: l10n.authTermsOfServiceLabel,
                    ),
                  ),
                ),
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
              child: Text(l10n.commonContinue),
            ),
            const SizedBox(height: AppSpacing.sm),
            // The same weight as "Continua": same size, same place in the column.
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
