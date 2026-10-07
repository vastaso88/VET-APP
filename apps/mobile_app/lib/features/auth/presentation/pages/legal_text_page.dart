import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/legal_texts_remote_data_source.dart';

/// Shows a legal text (terms of service / privacy policy) from the public
/// consent catalog, so the wording is maintained in one place.
class LegalTextPage extends StatefulWidget {
  const LegalTextPage({
    super.key,
    required this.consentKey,
    required this.title,
    this.shareable = false,
  });

  final String consentKey;
  final String title;

  /// Adds a share/download action and the "in preparazione" notice while the
  /// catalog still holds only the short consent sentence, not the full text.
  final bool shareable;

  /// Below this length the catalog entry is the short consent-checkbox
  /// sentence, not a full legal document.
  static const fullTextMinLength = 600;

  @override
  State<LegalTextPage> createState() => _LegalTextPageState();
}

class _LegalTextPageState extends State<LegalTextPage> {
  final _dataSource = LegalTextsRemoteDataSource();
  late final Future<String?> _text = _dataSource.fetchText(widget.consentKey);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(widget.title, style: AppTextStyles.title),
        actions: [
          if (widget.shareable)
            FutureBuilder<String?>(
              future: _text,
              builder: (context, snapshot) {
                final text = snapshot.data;
                final ready = text != null && text.length >= LegalTextPage.fullTextMinLength;
                return IconButton(
                  tooltip: 'Condividi o scarica',
                  icon: const Icon(Icons.ios_share_rounded),
                  onPressed: ready ? () => Share.share(text, subject: widget.title) : null,
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _text,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final text = snapshot.data;
          if (text == null || text.trim().isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Non riesco a caricare il testo adesso. Riprova tra poco.',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final preparing = widget.shareable && text.length < LegalTextPage.fullTextMinLength;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preparing) ...[
                  Text(
                    "Il testo completo dell'informativa è in preparazione e sarà disponibile qui "
                    'a breve, con la possibilità di scaricarlo.',
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(text, style: AppTextStyles.body),
              ],
            ),
          );
        },
      ),
    );
  }
}
