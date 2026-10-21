import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../data/language_store.dart';
import '../../domain/app_language.dart';
import '../pages/language_picker_page.dart';

/// The same compact control on authentication screens and in Settings.
///
/// It lists *languages*. Tapping one applies the variant we know (the current
/// one, the last used for that language, or the one the phone's country points
/// to); when a language has several variants and none is known (an Italian
/// phone choosing English) it asks which, instead of guessing UK, US or
/// Australia.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  Future<void> _select(BuildContext context, LanguageStore store, String code) async {
    final known = store.knownVariantForLanguage(code);
    if (known != null) {
      await store.choose(known);
      return;
    }
    final picked = await showDialog<AppLanguageVariant>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(store.variantForLanguage(code).nativeName.split(' (').first),
        children: [
          for (final variant in store.variantsOfLanguage(code))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LanguageVariantTile(
                variant: variant,
                selected: false,
                onTap: () => Navigator.of(dialogContext).pop(variant),
              ),
            ),
        ],
      ),
    );
    if (picked != null) await store.choose(picked);
  }

  @override
  Widget build(BuildContext context) {
    final store = LanguageStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => PopupMenuButton<String>(
        tooltip: context.l10n.languageSectionTitle,
        onSelected: (code) => _select(context, store, code),
        initialValue: store.variant.languageCode,
        itemBuilder: (_) => [
          for (final code
              in store.available.map((variant) => variant.languageCode).toSet())
            PopupMenuItem(
              value: code,
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
