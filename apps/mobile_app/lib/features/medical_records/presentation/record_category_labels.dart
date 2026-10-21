import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/record_category.dart';

/// What the owner reads for each category and type, and the icon of its tile.
extension RecordCategoryLabels on RecordCategory {
  /// Plural, as on the tiles: "Visite".
  String tileLabel(AppLocalizations l10n) => switch (this) {
    RecordCategory.visit => l10n.medCatVisit,
    RecordCategory.exam => l10n.medCatExam,
    RecordCategory.vaccine => l10n.medCatVaccine,
    RecordCategory.therapy => l10n.medCatTherapy,
    RecordCategory.document => l10n.medCatDocument,
  };

  /// Singular, for one entry: "Visita".
  String singularLabel(AppLocalizations l10n) => switch (this) {
    RecordCategory.visit => l10n.medCatVisitOne,
    RecordCategory.exam => l10n.medCatExamOne,
    RecordCategory.vaccine => l10n.medCatVaccineOne,
    RecordCategory.therapy => l10n.medCatTherapyOne,
    RecordCategory.document => l10n.medCatDocumentOne,
  };

  String newEntryTitle(AppLocalizations l10n) => switch (this) {
    RecordCategory.visit => l10n.medNewVisit,
    RecordCategory.exam => l10n.medNewExam,
    RecordCategory.vaccine => l10n.medNewVaccine,
    RecordCategory.therapy => l10n.medNewTherapy,
    RecordCategory.document => l10n.medNewDocument,
  };

  String emptyTitle(AppLocalizations l10n) => switch (this) {
    RecordCategory.visit => l10n.medEmptyVisitTitle,
    RecordCategory.exam => l10n.medEmptyExamTitle,
    RecordCategory.vaccine => l10n.medEmptyVaccineTitle,
    RecordCategory.therapy => l10n.medEmptyTherapyTitle,
    RecordCategory.document => l10n.medEmptyDocumentTitle,
  };

  String emptyBody(AppLocalizations l10n, String petName) => switch (this) {
    RecordCategory.visit => l10n.medEmptyVisitBody(petName),
    RecordCategory.exam => l10n.medEmptyExamBody(petName),
    RecordCategory.vaccine => l10n.medEmptyVaccineBody(petName),
    RecordCategory.therapy => l10n.medEmptyTherapyBody(petName),
    RecordCategory.document => l10n.medEmptyDocumentBody(petName),
  };

  String emptyAction(AppLocalizations l10n) => switch (this) {
    RecordCategory.visit => l10n.medEmptyVisitAction,
    RecordCategory.exam => l10n.medEmptyExamAction,
    RecordCategory.vaccine => l10n.medEmptyVaccineAction,
    RecordCategory.therapy => l10n.medEmptyTherapyAction,
    RecordCategory.document => l10n.medEmptyDocumentAction,
  };

  IconData get icon => switch (this) {
    RecordCategory.visit => Icons.medical_services_outlined,
    RecordCategory.exam => Icons.science_outlined,
    RecordCategory.vaccine => Icons.vaccines_outlined,
    RecordCategory.therapy => Icons.medication_outlined,
    RecordCategory.document => Icons.description_outlined,
  };
}

/// The label of a stored subtype key ("blood" → "Analisi del sangue"). An
/// unknown key (written by a newer app) is shown as it is.
String recordSubtypeLabel(AppLocalizations l10n, String key) => switch (key) {
  'checkup' => l10n.medSubCheckup,
  'specialist' => l10n.medSubSpecialist,
  'first_visit' => l10n.medSubFirstVisit,
  'emergency' => l10n.medSubEmergency,
  'post_surgery' => l10n.medSubPostSurgery,
  'blood' => l10n.medSubBlood,
  'urine' => l10n.medSubUrine,
  'stool' => l10n.medSubStool,
  'xray' => l10n.medSubXray,
  'ultrasound' => l10n.medSubUltrasound,
  'antiparasitic' => l10n.medSubAntiparasitic,
  'medication' => l10n.medSubMedication,
  'other' => l10n.medSubOther,
  _ => key,
};

const conditionIcon = Icons.healing_outlined;
