import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../data/legal_texts_remote_data_source.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../design_system/atoms/outline_icon_button.dart';

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
      appBar: PageHeader(
        title: widget.title,
        actions: [
          if (widget.shareable)
            FutureBuilder<String?>(
              future: _text,
              builder: (context, snapshot) {
                final text = snapshot.data;
                final ready = text != null &&
                    text.length >= LegalTextPage.fullTextMinLength;
                return OutlineIconButton(
                  tooltip: context.l10n.authLegalShareTooltip,
                  icon: Icons.ios_share_rounded,
                  onPressed: ready
                      ? () => SharePlus.instance.share(
                            ShareParams(text: text, subject: widget.title),
                          )
                      : null,
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
            return CenteredPageState(
              child: EmptyState.icon(
                icon: Icons.cloud_off_outlined,
                text: context.l10n.authLegalLoadError,
              ),
            );
          }
          final preparing =
              widget.shareable && text.length < LegalTextPage.fullTextMinLength;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preparing) ...[
                  Text(
                    context.l10n.authLegalPreparingNotice,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w700),
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
