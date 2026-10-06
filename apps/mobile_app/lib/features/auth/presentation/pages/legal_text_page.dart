import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/legal_texts_remote_data_source.dart';

/// Shows a legal text (terms of service / privacy policy) from the public
/// consent catalog, so the wording is maintained in one place.
class LegalTextPage extends StatefulWidget {
  const LegalTextPage({super.key, required this.consentKey, required this.title});

  final String consentKey;
  final String title;

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
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(text, style: AppTextStyles.body),
          );
        },
      ),
    );
  }
}
