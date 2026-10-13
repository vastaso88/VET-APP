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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(store.variantForLanguage(code).flag,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Text(store
                      .variantForLanguage(code)
                      .nativeName
                      .split(' (')
                      .first),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(store.variant.flag,
                    style: const TextStyle(fontSize: 24)),
              ),
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
