import '../../../settings/domain/unit_conversion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../pets/domain/pet_details.dart';
import '../../../pets/domain/pet_format.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../settings/domain/unit_system.dart';
import '../../domain/body_condition.dart';
import '../../domain/body_condition_guide.dart';
import '../../domain/weight_measurement.dart';
import '../../domain/weight_units.dart';
import 'body_condition_picker.dart';
import '../../../../shared/widgets/app_field.dart';

/// What the owner entered in the "Nuova misurazione" sheet.
class MeasurementDraft {
  const MeasurementDraft({
    required this.measuredOn,
    required this.weightKg,
    this.bodyCondition,
    this.note = '',
  });

  final DateTime measuredOn;
  final double weightKg;
  final BodyCondition? bodyCondition;
  final String note;
}

/// Asks for a weighing: date, weight (in the owner's unit), body condition
/// and a note. With [initial] it edits that weighing. Null when dismissed.
Future<MeasurementDraft?> showMeasurementSheet(
  BuildContext context, {
  required PetProfile pet,
  required UnitSystem system,
  WeightMeasurement? initial,
  DateTime? now,
}) {
  return showModalBottomSheet<MeasurementDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.large)),
    ),
    builder: (_) =>
        MeasurementSheet(pet: pet, system: system, initial: initial, now: now),
  );
}

class MeasurementSheet extends StatefulWidget {
  const MeasurementSheet({
    required this.pet,
    required this.system,
    this.initial,
    this.now,
    super.key,
  });

  final PetProfile pet;
  final UnitSystem system;
  final WeightMeasurement? initial;

  /// Today, for tests.
  final DateTime? now;

  @override
  State<MeasurementSheet> createState() => _MeasurementSheetState();
}

class _MeasurementSheetState extends State<MeasurementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  late final TextEditingController _weightController;
  late final TextEditingController _noteController;
  BodyCondition? _bodyCondition;

  DateTime get _today {
    final now = widget.now ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The body condition is asked only for species with a published guide.
  BodyConditionGuideKind? get _guide => bodyConditionGuideFor(widget.pet);

  /// The weight the animal is known to have, in kilos (0 when it has none).
  double get _knownKg =>
      widget.initial?.weightKg ?? parseWeightLabelKg(widget.pet.weightLabel) ?? 0;

  /// The weight is typed in the unit it is shown in: grams (or ounces) for a light animal, so
  /// "385" is never 385 kg. With no weight yet, the species decides, as in the profile.
  late final bool _small = _knownKg > 0
      ? isShownInSmallUnit(_knownKg, widget.system, alwaysKg: _alwaysKg)
      : !widget.system.usesPounds && isWeighedInGrams(widget.pet.species, widget.pet.breed);

  bool get _alwaysKg => isAlwaysWeighedInKg(widget.pet.species, widget.pet.breed);

  /// The birth date, only when it is a full date (day, month, year).
  DateTime? get _birthDate => parsePetBirthdayLabel(widget.pet.birthDateLabel);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _dateController = TextEditingController(
      text: formatDateForInput(initial?.measuredOn ?? _today),
    );
    _weightController = TextEditingController(
      text: initial == null
          ? ''
          : weightInputText(initial.weightKg, widget.system, small: _small),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _bodyCondition = initial?.bodyCondition;
  }

  @override
  void dispose() {
    _dateController.dispose();
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final birth = _birthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: parseStrictDate(_dateController.text) ?? _today,
      firstDate: birth ?? DateTime(_today.year - 30),
      lastDate: _today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _dateController.text = formatDateForInput(picked));
    }
  }

  String? _validateDate(String? value) {
    final l10n = context.l10n;
    final date = parseStrictDate(value ?? '');
    if (date == null) return l10n.remindersDateInvalid;
    if (date.isAfter(_today)) return l10n.monitoringErrorDateFuture;
    final birth = _birthDate;
    if (birth != null && date.isBefore(birth)) {
      return l10n.monitoringErrorDateBirth(widget.pet.name);
    }
    return null;
  }

  String? _validateWeight(String? value) =>
      parseWeightInput(value ?? '', widget.system, small: _small) == null
          ? context.l10n.monitoringErrorWeight
          : null;

  /// Twenty times more (or less) than the known weight is almost always a slip of the unit.
  Future<bool> _confirmJump(double typedKg) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.monitoringWeightJump(
          formatMeasuredWeight(typedKg, widget.system, alwaysKg: _alwaysKg),
          formatMeasuredWeight(_knownKg, widget.system, alwaysKg: _alwaysKg),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonEdit),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    return sure ?? false;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final weightKg = parseWeightInput(_weightController.text, widget.system, small: _small)!;
    if (isWeightJump(weightKg, _knownKg) && !await _confirmJump(weightKg)) return;
    if (!mounted) return;
    Navigator.of(context).pop(
      MeasurementDraft(
        measuredOn: parseStrictDate(_dateController.text)!,
        weightKg: weightKg,
        bodyCondition: _guide == null ? null : _bodyCondition,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null
                          ? l10n.monitoringSheetTitleNew
                          : l10n.monitoringSheetTitleEdit,
                      style: AppTextStyles.title,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonClose),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppField(
                label: l10n.monitoringFieldDate,
                child: TypedDateField(
                  controller: _dateController,
                  validator: _validateDate,
                  onPick: _pickDate,
                  pickIcon: Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.primary),
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
                  decoration: InputDecoration(hintText: l10n.remindersDatePlaceholder),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppField(
                key: const ValueKey('measurement-weight'),
                label: switch (weightEntryUnit(widget.system, small: _small)) {
                    WeightUnit.kg => l10n.monitoringFieldWeightKg,
                    WeightUnit.lb => l10n.monitoringFieldWeightLb,
                    WeightUnit.g => l10n.monitoringFieldWeightG,
                    WeightUnit.oz => l10n.monitoringFieldWeightOz,
                  },
                child: TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                  ],
                  validator: _validateWeight,
                  decoration: InputDecoration(hintText: switch (weightEntryUnit(widget.system, small: _small)) {
                      WeightUnit.kg => l10n.monitoringFieldWeightHintKg,
                      WeightUnit.lb => l10n.monitoringFieldWeightHintLb,
                      WeightUnit.g || WeightUnit.oz => l10n.petsFormWeightHintG,
                    }),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_guide != null) ...[
                BodyConditionPicker(
                  kind: _guide!,
                  petName: widget.pet.name,
                  value: _bodyCondition,
                  onChanged: (value) => setState(() => _bodyCondition = value),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppField(
                key: const ValueKey('measurement-note'),
                label: l10n.monitoringFieldNote,
                child: TextFormField(
                  controller: _noteController,
                  maxLength: 500,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('measurement-save'),
                  onPressed: _save,
                  child: Text(l10n.commonSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
