import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/date_formats.dart';
import '../domain/history_event.dart';
import 'record_category_labels.dart';

/// What the Storico and its PDF say about one event, and its symbol: the same
/// icons as the category tiles.
extension HistoryEventLabels on HistoryEvent {
  IconData get icon => category?.icon ?? conditionIcon;

  /// "Vaccino", "Patologia"...
  String categoryLabel(AppLocalizations l10n) =>
      category?.singularLabel(l10n) ?? l10n.medCatConditionOne;

  /// The finer type of a visit, exam or therapy ("Analisi del sangue").
  String? subtypeLabel(AppLocalizations l10n) {
    final key = subtype;
    return key == null ? null : recordSubtypeLabel(l10n, key);
  }

  /// The notes column: the owner's notes, and for an illness also whether it is
  /// still going on and the therapy.
  String notesText(AppLocalizations l10n) {
    final illness = condition;
    final parts = <String>[];
    if (illness != null) {
      final ended = illness.endedOn;
      parts.add(
        illness.ongoing
            ? l10n.medPdfConditionOngoing
            : ended == null
                ? l10n.medPdfConditionResolved
                : l10n
                    .medPdfConditionResolvedOn(formatAppDate(ended, 'd MMM y')),
      );
      final therapy = illness.therapy.trim();
      if (therapy.isNotEmpty) parts.add(l10n.medPdfConditionTherapy(therapy));
    }
    final own = notes.trim();
    if (own.isNotEmpty) parts.add(own);
    return parts.join(' · ');
  }
}

/// The symbol key of an event in the maps of rendered symbols.
String historySymbolKey(HistoryEvent event) =>
    event.category?.key ?? 'condition';
