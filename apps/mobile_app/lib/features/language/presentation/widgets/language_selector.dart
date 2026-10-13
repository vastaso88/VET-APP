import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../data/language_store.dart';
import '../../domain/app_language.dart';

/// The same compact control on authentication screens and in Settings.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = LanguageStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => PopupMenuButton<AppLanguageVariant>(
        tooltip: context.l10n.languageSectionTitle,
        onSelected: store.choose,
        initialValue: store.variant,
        itemBuilder: (_) => [
          for (final code
              in store.available.map((variant) => variant.languageCode).toSet())
            PopupMenuItem(
              value: store.variantForLanguage(code),
              child: Text(store.available
                  .firstWhere((variant) => variant.languageCode == code)
                  .nativeName
                  .split(' (')
                  .first),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_rounded, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(store.variant.nativeName.split(' (').first,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
