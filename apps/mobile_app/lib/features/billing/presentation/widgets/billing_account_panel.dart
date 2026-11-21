import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../l10n/l10n.dart';

/// Native purchase links require actual store eligibility and program integration.
/// Device locale, IP and a query parameter are not evidence of a storefront.
class BillingAccountPanel extends StatelessWidget {
  const BillingAccountPanel({super.key});

  static const demoEnabled = bool.fromEnvironment('BILLING_DEMO_ENABLED');
  static Uri get accountUrl {
    final configured = Uri.tryParse(
      const String.fromEnvironment(
        'QUOKKA_ACCOUNT_URL',
        defaultValue: 'https://quokkapp.net/account',
      ),
    );
    if (configured == null ||
        configured.scheme != 'https' ||
        configured.host != 'quokkapp.net' ||
        configured.path != '/account' ||
        configured.hasQuery ||
        configured.hasFragment ||
        configured.userInfo.isNotEmpty) {
      return Uri.parse('https://quokkapp.net/account');
    }
    return configured;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.billingTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(context.l10n.billingAccountStatusNotice),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                final opened = await launchUrl(
                  accountUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.billingOpenAccountError),
                    ),
                  );
                }
              },
              child: Text(context.l10n.billingOpenAccount),
            ),
          ],
        ],
      ),
    );
  }
}
