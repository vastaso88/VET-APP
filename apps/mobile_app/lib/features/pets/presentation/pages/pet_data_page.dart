import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../monitoring/data/weight_measurements_repository.dart';
import '../../../monitoring/domain/body_condition.dart';
import '../../../monitoring/domain/body_condition_guide.dart';
import '../../../settings/data/unit_settings_store.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_details.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pet_sections.dart';
import '../widgets/pets_scaffold.dart';
import 'pet_edit_page.dart';

/// One line under the pet's header that opens [PetDataPage]: sex, weight and
/// whether the microchip is on file, at a glance.
class PetDataSummaryRow extends StatelessWidget {
  const PetDataSummaryRow({required this.pet, super.key});

  final PetProfile pet;

  String _summary(BuildContext context) {
    final t = context.l10n;
    final weight = pet.weightLabel.trim();
    final parts = <String>[
      if (pet.species != 'Pesce' && pet.sex.trim().isNotEmpty)
        localizedSexLabel(pet.sex),
      if (weight.isNotEmpty) weightLabelIn(weight, UnitSettingsStore.instance.system),
      if (pet.isSterilized == true) t.petsDataSummarySterilized,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final missingChip = isMicrochipMissingForDog(pet);
    final summary = _summary(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PetDataPage(petId: pet.id, initialPet: pet)),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.badge_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  summary.isEmpty
                      ? context.l10n.petsDataTitle
                      : '${context.l10n.petsDataTitle} · $summary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (missingChip) ...[
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
              ],
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Dati animale": the profile in three blocks — who the animal is, what it is
/// like, and its documents (microchip, neutering).
class PetDataPage extends StatefulWidget {
  const PetDataPage({required this.petId, required this.initialPet, super.key});

  final String petId;
  final PetProfile initialPet;

  @override
  State<PetDataPage> createState() => _PetDataPageState();
}

class _PetDataPageState extends State<PetDataPage> {
  late PetProfile _pet = widget.initialPet;

  /// Body condition of the latest weighing that recorded one: it wins over
  /// the profile's own value, so the app shows a single corporatura.
  BodyCondition? _measuredCondition;

  @override
  void initState() {
    super.initState();
    PetDemoStore.changes.addListener(_refresh);
    WeightMeasurementsRepository.changes.addListener(_loadMeasuredCondition);
    _loadMeasuredCondition();
  }

  @override
  void dispose() {
    PetDemoStore.changes.removeListener(_refresh);
    WeightMeasurementsRepository.changes.removeListener(_loadMeasuredCondition);
    super.dispose();
  }

  Future<void> _loadMeasuredCondition() async {
    final latest = await WeightMeasurementsRepository().latestWithCondition(widget.petId);
    if (!mounted) return;
    setState(() => _measuredCondition = latest?.bodyCondition);
  }

  void _refresh() {
    final updated = PetDemoStore.instance.byId(widget.petId);
    if (!mounted || updated == null) return;
    setState(() => _pet = updated);
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<PetProfile>(
      MaterialPageRoute<PetProfile>(builder: (_) => PetEditPage(pet: _pet)),
    );
    if (!mounted || updated == null) return;
    setState(() => _pet = updated);
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    final t = context.l10n;
    return PetsScaffold(
      title: t.petsDataTitle,
      subtitle: pet.name,
      onBack: () => Navigator.of(context).maybePop(),
      badge: PetAvatar(
        label: pet.avatarEmoji,
        backgroundColor: pet.accentColor,
        photoBytes: pet.photoBytes,
        photoPath: pet.photoPath,
        identityColor: pet.identityColor,
        size: 36,
      ),
      actions: [
        IconButton(
          tooltip: t.commonEdit,
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: AppColors.primaryStrong),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetSection(title: t.petsDataSectionIdentity, children: _identityRows(context, pet)),
            const SizedBox(height: AppSpacing.md),
            PetSection(title: t.petsDataSectionPhysical, children: _physicalRows(context, pet)),
            const SizedBox(height: AppSpacing.md),
            PetSection(title: t.petsDataSectionDocuments, children: _documentRows(context, pet)),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _orNotProvided(BuildContext context, String? value) =>
      value == null || value.trim().isEmpty ? context.l10n.petsDataNotProvided : value.trim();

  List<Widget> _identityRows(BuildContext context, PetProfile pet) {
    final t = context.l10n;
    final fish = pet.species == 'Pesce';
    return [
      PetInfoRow(label: t.petsFormNameLabel, value: pet.name),
      PetInfoRow(label: t.petsFormSpeciesLabel, value: localizedSpeciesLabel(pet.species)),
      PetInfoRow(label: t.petsFormBreedLabel, value: pet.breedLabel),
      if (!fish)
        PetInfoRow(
          label: t.petsFormSexLabel,
          value: _orNotProvided(context, localizedSexLabel(pet.sex)),
        ),
      if (!pet.isAquarium)
        PetInfoRow(
          label: t.petsFormBirthDateLabel,
          value: _orNotProvided(context, petBirthDateDisplayLabel(pet.birthDateLabel)),
        ),
    ];
  }

  List<Widget> _physicalRows(BuildContext context, PetProfile pet) {
    final t = context.l10n;
    final weight = pet.weightLabel.trim();
    final bodyCondition = _measuredCondition ?? BodyCondition.fromCode(pet.bodyCondition);
    final activity = pet.activityLevel;
    return [
      if (speciesHasSize(pet.species))
        PetInfoRow(
          label: t.petsFormDogSizeLabelShort,
          value: _orNotProvided(
            context,
            (pet.dogSizeCategory ?? '').isEmpty ? null : localizedDogSizeLabel(pet.dogSizeCategory!),
          ),
        ),
      PetInfoRow(
        label: t.petsDataWeightLabel,
        value: _orNotProvided(
          context,
          weight.isEmpty ? null : weightLabelIn(weight, UnitSettingsStore.instance.system),
        ),
      ),
      // Corporatura exists only for species with a published guide.
      if (supportsBodyCondition(pet))
        PetInfoRow(
          label: t.petsFormBodyConditionLabel,
          value: _orNotProvided(
            context,
            bodyCondition?.label,
          ),
        ),
      if (speciesHasBodyDetails(pet.species))
        PetInfoRow(
          label: t.petsFormActivityLabel,
          value: _orNotProvided(
            context,
            activity == null ? null : localizedActivityLevelLabel(activity),
          ),
        ),
      if (speciesHasCoatColor(pet.species))
        PetInfoRow(
          label: speciesHasCoat(pet.species) ? t.petsFormCoatColorLabel : t.petsFormColorLabel,
          value: _orNotProvided(context, pet.coatColor),
        ),
    ];
  }

  List<Widget> _documentRows(BuildContext context, PetProfile pet) {
    final t = context.l10n;
    final chip = (pet.microchipNumber ?? '').trim();
    return [
      if (speciesHasMicrochip(pet.species))
        chip.isNotEmpty
            ? PetInfoRow(label: t.petsFormMicrochipLabel, value: formatMicrochip(chip))
            : _MissingMicrochipRow(
                dog: pet.species == 'Cane',
                onAdd: _edit,
              ),
      if (speciesHasNeutering(pet.species))
        PetInfoRow(
          label: t.petsFormSterilized,
          value: switch (pet.isSterilized) {
            true => t.commonYes,
            false => t.commonNo,
            null => t.petsDataNotProvided,
          },
        ),
    ];
  }
}

/// No microchip on file: for a dog it is flagged (mandatory in Italy) with a
/// shortcut to add it; for any other animal it is just "not provided".
class _MissingMicrochipRow extends StatelessWidget {
  const _MissingMicrochipRow({required this.dog, required this.onAdd});

  final bool dog;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    if (!dog) {
      return PetInfoRow(label: t.petsFormMicrochipLabel, value: t.petsDataNotProvided);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 106,
                child: Text(
                  t.petsFormMicrochipLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  t.petsDataMicrochipMissing,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(t.petsDataMicrochipMissingDogHint, style: AppTextStyles.caption),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(t.petsDataAddMicrochip),
            ),
          ),
        ],
      ),
    );
  }
}
