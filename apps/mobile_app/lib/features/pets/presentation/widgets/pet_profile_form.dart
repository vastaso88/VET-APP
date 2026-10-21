import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../settings/data/unit_settings_store.dart';
import '../../../settings/domain/unit_conversion.dart';
import '../../../settings/domain/unit_system.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/fish_species.dart';
import '../../domain/pet_breeds.dart';
import '../../domain/pet_species_breeds.dart';
import '../../domain/pet_identity_colors.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../../shared/widgets/pet_loader.dart';
import 'pet_avatar.dart';
import 'pet_sections.dart';

class PetProfileDraft {
  const PetProfileDraft({
    required this.name,
    required this.species,
    required this.breed,
    this.birthDate,
    required this.sex,
    this.weightKg,
    required this.medicalNote,
    required this.identityColor,
    this.photoBytes,
    this.photoTouched = false,
    this.aquariumStock = const [],
    this.habitat,
    this.dogSizeCategory,
  });

  final String name;
  final String species;
  final String? breed;

  /// Null for a multi-fish aquarium — there's no single "birth date" for a
  /// whole tank. Still asked for a single pet (including a lone fish).
  final DateTime? birthDate;
  final String sex;
  final double? weightKg;
  final String medicalNote;
  final Color identityColor;
  final Uint8List? photoBytes;

  /// True only when the owner picked or removed a photo in this form. A
  /// persisted photo the owner never touched must not be cleared on save.
  final bool photoTouched;
  final List<FishStock> aquariumStock;
  final HabitatDetails? habitat;
  final String? dogSizeCategory;
}

/// Species that live in an enclosure worth describing (dimensions, water/
/// substrate, equipment) rather than roaming free in the house.
bool _speciesHasHabitat(String? species) =>
    species == 'Pesce' || species == 'Rettili e anfibi' || species == 'Uccello';

class PetProfileForm extends StatefulWidget {
  const PetProfileForm({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    super.key,
    this.initialPet,
    this.footerActions,
  });

  final PetProfile? initialPet;
  final String title;
  final String submitLabel;
  final Future<void> Function(PetProfileDraft draft) onSubmit;

  /// Rendered below the save button — used for pet-lifecycle actions
  /// (delete, move to Ricordi) that only make sense when editing an
  /// existing pet, never while creating one.
  final Widget? footerActions;

  @override
  State<PetProfileForm> createState() => _PetProfileFormState();
}

class _PetProfileFormState extends State<PetProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  late String? _species;
  late String? _breed;
  bool _otherBreed = false;
  final _otherBreedController = TextEditingController();
  late String? _dogSizeCategory;
  late String? _sex;
  late final TextEditingController _birthDateController;
  Uint8List? _photoBytes;
  bool _photoTouched = false;
  bool _submitting = false;
  late Color _identityColor;
  late bool _isAquarium;
  late List<FishStock> _aquariumStock;
  late final TextEditingController _lengthController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late final TextEditingController _volumeController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _substrateController;
  late final TextEditingController _habitatNotesController;

  /// True once the owner has typed into the Litri field themselves — after
  /// that, changing a dimension no longer overwrites their value.
  bool _volumeManuallyEdited = false;
  bool _isAutoUpdatingVolume = false;

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;
    final habitat = pet?.habitat;
    _nameController = TextEditingController(text: pet?.name ?? '');
    _weightController = TextEditingController(
      text: _weightFromLabel(pet?.weightLabel),
    );
    _notesController = TextEditingController(text: pet?.medicalNote ?? '');
    _species = pet?.species;
    _breed = _normalizeBreed(pet?.breed);
    final initialBreed = _breed;
    if (initialBreed == 'Altro') {
      _otherBreed = true;
    } else if (initialBreed != null && _species != null && !(_species == 'Pesce' && (pet?.isAquarium ?? false)) &&
        isCustomBreed(initialBreed, PetDemoStore.breedsForSpecies(_species!))) {
      _otherBreed = true;
      _otherBreedController.text = initialBreed;
    }
    _dogSizeCategory = pet?.dogSizeCategory;
    _sex = pet?.sex;
    final initialBirthDate = _parseBirthDate(pet?.birthDateLabel);
    _birthDateController = TextEditingController(
      text: initialBirthDate == null ? '' : formatDateForInput(initialBirthDate),
    );
    _photoBytes = pet?.photoBytes;
    _identityColor = pet?.identityColor ?? PetDemoStore.instance.nextDefaultIdentityColor();
    _isAquarium = pet?.isAquarium ?? false;
    _aquariumStock = List.of(pet?.aquariumStock ?? const []);
    _lengthController = TextEditingController(text: _cmField(habitat?.lengthCm));
    _widthController = TextEditingController(text: _cmField(habitat?.widthCm));
    _heightController = TextEditingController(text: _cmField(habitat?.heightCm));
    _volumeController = TextEditingController(text: _litersField(habitat?.volumeLiters));
    _volumeController.addListener(() {
      if (_isAutoUpdatingVolume) return;
      _volumeManuallyEdited = true;
    });
    _temperatureController = TextEditingController(
      text: temperatureLabelIn(habitat?.temperatureLabel ?? '', _units),
    );
    _substrateController = TextEditingController(text: habitat?.substrate ?? '');
    _habitatNotesController = TextEditingController(text: habitat?.notes ?? '');
  }

  UnitSystem get _units => UnitSettingsStore.instance.system;

  /// Number as shown in a field in the owner's unit ("23,6"), one decimal.
  String _fieldNumber(double value) => formatDecimal(value);

  double? _typedNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  /// A dimension field (cm, or inches in the imperial/USA systems) as cm.
  int? _typedCm(TextEditingController controller) {
    final value = _typedNumber(controller.text);
    return value == null ? null : displayToCm(value, _units);
  }

  String _cmField(int? cm) => cm == null
      ? ''
      : (_units.usesInches ? _fieldNumber(cmToDisplay(cm, _units)) : cm.toString());

  /// The liters field (US gallons in the USA system) as liters.
  int? _typedLiters() {
    final value = _typedNumber(_volumeController.text);
    return value == null ? null : displayToLiters(value, _units);
  }

  String _litersField(int? liters) {
    if (liters == null) return '';
    return _units.usesUsGallons
        ? _fieldNumber(litersToDisplay(liters.toDouble(), _units))
        : liters.toString();
  }

  void _recalculateVolume() {
    if (_volumeManuallyEdited) return;
    final length = _typedCm(_lengthController);
    final width = _typedCm(_widthController);
    final height = _typedCm(_heightController);
    if (length == null || width == null || height == null) return;

    final liters = (length * width * height / 1000).round();
    _isAutoUpdatingVolume = true;
    _volumeController.text = _litersField(liters);
    _isAutoUpdatingVolume = false;
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    setState(() {
      _photoBytes = bytes;
      _photoTouched = true;
    });
  }

  void _removePhoto() => setState(() {
        _photoBytes = null;
        _photoTouched = true;
      });

  Future<void> _openAddSpeciesSheet() async {
    final existing = _aquariumStock.map((stock) => stock.species).toSet();
    final available = aquariumFishSpecies.where((species) => !existing.contains(species)).toList();

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: available.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  sheetContext.l10n.petsFormAllSpeciesAdded,
                  style: AppTextStyles.bodySmall,
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(sheetContext.l10n.petsFormAddSpecies, style: AppTextStyles.title),
                  ),
                  for (final species in available)
                    ListTile(
                      title: Text(species, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
                      onTap: () => Navigator.of(sheetContext).pop(species),
                    ),
                ],
              ),
      ),
    );

    if (selected == null) return;
    setState(
      () => _aquariumStock = [..._aquariumStock, FishStock(species: selected, maleCount: 1)],
    );
  }

  void _changeMaleCount(int index, int count) {
    if (count < 0) return;
    setState(() {
      _aquariumStock = [
        for (var i = 0; i < _aquariumStock.length; i++)
          i == index ? _aquariumStock[i].copyWith(maleCount: count) : _aquariumStock[i],
      ];
    });
  }

  void _changeFemaleCount(int index, int count) {
    if (count < 0) return;
    setState(() {
      _aquariumStock = [
        for (var i = 0; i < _aquariumStock.length; i++)
          i == index ? _aquariumStock[i].copyWith(femaleCount: count) : _aquariumStock[i],
      ];
    });
  }

  void _removeStock(int index) {
    setState(() {
      _aquariumStock = [
        for (var i = 0; i < _aquariumStock.length; i++)
          if (i != index) _aquariumStock[i],
      ];
    });
  }

  Color _speciesAccentColor() {
    final species = _species;
    if (species == null || species.trim().isEmpty) {
      return widget.initialPet?.accentColor ?? AppColors.accentSoft;
    }
    return PetDemoStore.optionForSpecies(species).accentColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _otherBreedController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _volumeController.dispose();
    _temperatureController.dispose();
    _substrateController.dispose();
    _habitatNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breedOptions = _breedOptionsForSelectedSpecies();
    final isAquariumProfile = _species == 'Pesce' && _isAquarium;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        // Re-validate each field as the owner edits it, so a message clears as
        // soon as its value becomes valid instead of lingering until next submit.
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetSection(
              title: widget.title,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _nameController,
                  builder: (context, value, _) {
                    final trimmed = value.text.trim();
                    final label = trimmed.isNotEmpty
                        ? trimmed[0].toUpperCase()
                        : (widget.initialPet?.avatarEmoji ?? '?');
                    return _PhotoPicker(
                      photoBytes: _photoBytes,
                      photoPath: _photoTouched ? null : widget.initialPet?.photoPath,
                      identityColor: _identityColor,
                      backgroundColor: _speciesAccentColor(),
                      label: label,
                      onPick: _pickPhoto,
                      onRemove: _photoBytes == null &&
                              (_photoTouched || widget.initialPet?.photoPath == null)
                          ? null
                          : _removePhoto,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(context.l10n.petsFormIdentityColor, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                _IdentityColorPicker(
                  value: _identityColor,
                  onChanged: (color) => setState(() => _identityColor = color),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(context.l10n.petsFormNameLabel, context.l10n.petsFormNameHint),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return context.l10n.petsFormNameError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _species,
                  decoration: _inputDecoration(
                    context.l10n.petsFormSpeciesLabel,
                    context.l10n.petsFormSpeciesHint,
                  ),
                  items: PetDemoStore.speciesOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.label,
                          child: Text(localizedSpeciesLabel(option.label)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _species = value;
                      _breed = null;
                      _otherBreed = false;
                      _otherBreedController.clear();
                      _dogSizeCategory = null;
                      if (value != 'Pesce') {
                        _isAquarium = false;
                        _aquariumStock = [];
                      } else {
                        // Fish don't get the standalone Sesso field (see
                        // below) — sex is tracked per aquarium species
                        // instead, so this is just a safe non-null default.
                        _sex = 'Sconosciuto';
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.petsFormSpeciesError;
                    }
                    return null;
                  },
                ),
                if (_species == 'Pesce') ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(context.l10n.petsFormProfileType, style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _AquariumModeToggle(
                    value: _isAquarium,
                    onChanged: (value) => setState(() => _isAquarium = value),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_species == 'Pesce' && _isAquarium) ...[
                  Text(context.l10n.petsFormAquariumPopulation, style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _AquariumStockEditor(
                    stock: _aquariumStock,
                    onAdd: _openAddSpeciesSheet,
                    onChangeMale: _changeMaleCount,
                    onChangeFemale: _changeFemaleCount,
                    onRemove: _removeStock,
                  ),
                ] else
                  InkWell(
                    onTap: _species == null
                        ? null
                        : () async {
                            final picked = await _pickBreed(breedOptions);
                            if (picked == null || !mounted) return;
                            setState(() {
                              if (isOtherBreedEntry(picked)) {
                                _otherBreed = true;
                                _breed = _otherBreedController.text.trim().isEmpty
                                    ? 'Altro'
                                    : _otherBreedController.text.trim();
                              } else {
                                _otherBreed = false;
                                _breed = picked == 'Razza non specificata' ? null : picked;
                              }
                            });
                          },
                    borderRadius: BorderRadius.circular(18),
                    child: InputDecorator(
                      decoration: _inputDecoration(
                        context.l10n.petsFormBreedLabel,
                        _species == null
                            ? context.l10n.petsFormBreedSelectSpeciesFirst
                            : context.l10n.petsFormBreedOptional,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _breedDisplay(context.l10n),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: _breedIsPlaceholder
                                    ? AppColors.mutedText
                                    : AppColors.text,
                              ),
                            ),
                          ),
                          const Icon(Icons.search_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                if (_otherBreed) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _otherBreedController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _species == 'Cane' || _species == 'Gatto'
                        ? _inputDecoration(
                            context.l10n.petsFormOtherBreedLabel,
                            context.l10n.petsFormOtherBreedHint,
                          )
                        : _inputDecoration(
                            context.l10n.petsFormOtherSpeciesLabel,
                            context.l10n.petsFormOtherSpeciesHint,
                          ),
                    onChanged: (value) => setState(() {
                      _breed = value.trim().isEmpty ? 'Altro' : value.trim();
                    }),
                  ),
                ],
                if (_species == 'Cane') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _dogSizeCategory,
                    decoration: _inputDecoration(
                      context.l10n.petsFormDogSizeLabel,
                      context.l10n.petsFormDogSizeHint,
                    ),
                    items: PetDemoStore.dogSizeCategories
                        .map(
                          (size) => DropdownMenuItem<String>(
                            value: size,
                            child: Text(localizedDogSizeLabel(size)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _dogSizeCategory = value),
                  ),
                ],
                if (_speciesHasHabitat(_species)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(petHabitatLabel(_species, context.l10n), style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _HabitatFields(
                    showVolume: _species == 'Pesce',
                    lengthController: _lengthController,
                    widthController: _widthController,
                    heightController: _heightController,
                    volumeController: _volumeController,
                    temperatureController: _temperatureController,
                    substrateController: _substrateController,
                    notesController: _habitatNotesController,
                    inputDecoration: _inputDecoration,
                    onDimensionChanged: _recalculateVolume,
                  ),
                ],
                // A multi-fish aquarium has no single "birth date" — asked
                // only for a single pet (a lone fish included).
                if (!isAquariumProfile) ...[
                  const SizedBox(height: AppSpacing.md),
                  TypedDateField(
                    controller: _birthDateController,
                    onPick: _pickBirthDate,
                    pickIcon: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                    decoration: _inputDecoration(
                      context.l10n.petsFormBirthDateLabel,
                      appDateInputText(context.l10n.petsFormBirthDateHint),
                    ),
                    validator: (value) {
                      final raw = (value ?? '').trim();
                      if (raw.isEmpty) {
                        return context.l10n.petsFormBirthDateRequired;
                      }
                      final parsed = parseStrictDate(raw);
                      if (parsed == null) {
                        return appDateInputText(context.l10n.petsFormBirthDateInvalid);
                      }
                      if (parsed.isAfter(DateTime.now())) {
                        return context.l10n.petsFormBirthDateFuture;
                      }
                      return null;
                    },
                  ),
                ],
                // Fish don't get a standalone Sesso field: for an aquarium,
                // one sex value for the whole tank doesn't make sense — it's
                // tracked per species instead, right in the population
                // editor above. A single fish just doesn't show it.
                if (_species != 'Pesce') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _sex,
                    decoration: _inputDecoration(context.l10n.petsFormSexLabel, context.l10n.petsFormSexHint),
                    items: [
                      ...PetDemoStore.sexOptions,
                      // A pet saved with an older value (e.g. "Sconosciuto") must
                      // still show it, or the dropdown has no matching item.
                      if (_sex != null && !PetDemoStore.sexOptions.contains(_sex)) _sex!,
                    ]
                        .map(
                          (sex) => DropdownMenuItem<String>(
                            value: sex,
                            child: Text(
                              sex == 'Sconosciuto'
                                  ? context.l10n.petsFormSexUnknown
                                  : localizedSexLabel(sex),
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setState(() {
                        _sex = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.petsFormSexError;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _weightController,
                  textInputAction: TextInputAction.next,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s]')),
                  ],
                  decoration: _inputDecoration(
                    _units.usesPounds
                        ? context.l10n.petsFormWeightLabelLb
                        : context.l10n.petsFormWeightLabelKg,
                    _units.usesPounds
                        ? context.l10n.petsFormWeightHintLb
                        : context.l10n.petsFormWeightHintKg,
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return null;
                    }
                    final parsed = _parseWeight(value);
                    if (parsed == null) {
                      return context.l10n.petsFormWeightInvalid;
                    }
                    if (parsed <= 0) {
                      return context.l10n.petsFormWeightPositive;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    context.l10n.petsFormNotesLabel,
                    context.l10n.petsFormNotesHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const PetLoader.small(color: AppColors.onPrimary)
                    : const Icon(Icons.save_rounded),
                label: Text(_submitting ? context.l10n.petsFormSaving : widget.submitLabel),
              ),
            ),
            if (widget.footerActions != null) widget.footerActions!,
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }

  /// True while the breed row shows a hint ("Seleziona una razza") rather than a value.
  bool get _breedIsPlaceholder {
    if (_species == null || _otherBreed) return false;
    final breed = _breed;
    return breed == null || breed.isEmpty;
  }

  String _breedDisplay(AppLocalizations t) {
    if (_species == null) return t.petsFormBreedSelectSpeciesFirst;
    if (_otherBreed) {
      return _species == 'Cane' || _species == 'Gatto' ? otherBreedLabel : otherEntryLabel;
    }
    final breed = _breed;
    return breed == null || breed.isEmpty ? t.petsFormBreedPlaceholder : breed;
  }

  Future<String?> _pickBreed(List<String> options) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => _BreedPickerSheet(options: options),
    );
  }

  Future<void> _pickBirthDate() async {
    final initialDate = parseStrictDate(_birthDateController.text) ?? DateTime(2021, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      // The dialog's own "write" mode has no gg/mm/aaaa slashes; typing
      // already happens in the field next to this icon, so the dialog only
      // needs to offer the calendar.
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    setState(() => _birthDateController.text = formatDateForInput(picked));
  }

  void _submit() async {
    final isAquariumProfile = _species == 'Pesce' && _isAquarium;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if (isAquariumProfile && _aquariumStock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.petsFormAquariumNeedsSpecies)),
      );
      return;
    }

    final draft = PetProfileDraft(
      name: _nameController.text.trim(),
      species: _species!.trim(),
      breed: isAquariumProfile ? null : _normalizeBreed(_breed),
      birthDate: isAquariumProfile ? null : parseStrictDate(_birthDateController.text.trim()),
      sex: _sex!.trim(),
      weightKg: _parseWeight(_weightController.text),
      medicalNote: _notesController.text.trim(),
      identityColor: _identityColor,
      photoBytes: _photoBytes,
      photoTouched: _photoTouched,
      aquariumStock: isAquariumProfile ? _aquariumStock : const [],
      habitat: _buildHabitat(),
      dogSizeCategory: _species == 'Cane' ? _dogSizeCategory : null,
    );

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(draft);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  HabitatDetails? _buildHabitat() {
    if (!_speciesHasHabitat(_species)) return null;

    final habitat = HabitatDetails(
      lengthCm: _typedCm(_lengthController),
      widthCm: _typedCm(_widthController),
      heightCm: _typedCm(_heightController),
      volumeLiters: _species == 'Pesce' ? _typedLiters() : null,
      temperatureLabel: temperatureLabelFromInput(_temperatureController.text, _units),
      substrate: _substrateController.text.trim(),
      notes: _habitatNotesController.text.trim(),
    );
    return habitat.isEmpty ? null : habitat;
  }

  List<String> _breedOptionsForSelectedSpecies() {
    final species = _species;
    if (species == null || species.trim().isEmpty) {
      return const ['Razza non specificata'];
    }
    return PetDemoStore.breedsForSpecies(species);
  }

  String? _normalizeBreed(String? breed) {
    final text = breed?.trim() ?? '';
    if (text.isEmpty || text == 'Razza non specificata') {
      return null;
    }
    return text;
  }

  double? _parseWeight(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    final typed = double.tryParse(raw.replaceAll(',', '.'));
    // Typed in the owner's unit (kg or lb); stored in kg.
    return typed == null ? null : displayToKg(typed, _units);
  }

  /// The weight field's text: the stored kg label, in the owner's unit.
  String _weightFromLabel(String? label) {
    final kg = parseWeightLabelKg(label ?? '');
    if (kg == null) return '';
    return formatDecimal(kgToDisplay(kg, _units));
  }

  DateTime? _parseBirthDate(String? label) {
    if (label == null || label.trim().isEmpty) {
      return null;
    }

    final parts = label.split(' ');
    if (parts.length < 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = _monthNumber(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  int? _monthNumber(String label) {
    const months = {
      'gen': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'mag': 5,
      'giu': 6,
      'lug': 7,
      'ago': 8,
      'set': 9,
      'ott': 10,
      'nov': 11,
      'dic': 12,
    };

    // formato salvato: sempre italiano. Saved labels may still use the old
    // capitalised form ("05 Mag 2021").
    return months[label.toLowerCase()];
  }

}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoBytes,
    required this.identityColor,
    required this.backgroundColor,
    required this.label,
    required this.onPick,
    this.photoPath,
    this.onRemove,
  });

  final Uint8List? photoBytes;
  final String? photoPath;
  final Color identityColor;
  final Color backgroundColor;
  final String label;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PetAvatar(
          label: label,
          backgroundColor: backgroundColor,
          photoBytes: photoBytes,
          photoPath: photoPath,
          identityColor: identityColor,
          size: 64,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: Text(
                  photoBytes == null && photoPath == null
                      ? context.l10n.petsFormPhotoAdd
                      : context.l10n.petsFormPhotoChange,
                ),
              ),
              if (onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(context.l10n.petsFormPhotoRemove),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AquariumModeToggle extends StatelessWidget {
  const _AquariumModeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.set_meal_outlined, size: 16),
          label: Text(context.l10n.petsFormSingleFish),
        ),
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.water_outlined, size: 16),
          label: Text(context.l10n.petsHabitatAquarium),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AquariumStockEditor extends StatelessWidget {
  const _AquariumStockEditor({
    required this.stock,
    required this.onAdd,
    required this.onChangeMale,
    required this.onChangeFemale,
    required this.onRemove,
  });

  final List<FishStock> stock;
  final VoidCallback onAdd;
  final void Function(int index, int count) onChangeMale;
  final void Function(int index, int count) onChangeFemale;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stock.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(context.l10n.petsFormNoSpeciesYet, style: AppTextStyles.bodySmall),
          )
        else
          ...stock.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _StockRow(
                item: entry.value,
                onChangeMale: (count) => onChangeMale(entry.key, count),
                onChangeFemale: (count) => onChangeFemale(entry.key, count),
                onRemove: () => onRemove(entry.key),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(context.l10n.petsFormAddSpecies),
        ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.item,
    required this.onChangeMale,
    required this.onChangeFemale,
    required this.onRemove,
  });

  final FishStock item;
  final ValueChanged<int> onChangeMale;
  final ValueChanged<int> onChangeFemale;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Stacked, not a single Row: on a narrow phone, cramming the species
    // name in with the counter controls left it no room (e.g. "Danio
    // zebra" → "Da…"). Name + remove share the top line (both fixed,
    // short); the male/female counters — the part users actually adjust —
    // get their own full-width line below.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
        color: AppColors.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.species,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                ),
              ),
              _CompactIconButton(onPressed: onRemove, icon: Icons.close_rounded, color: AppColors.mutedText),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _SexCounter(
                  icon: Icons.male_rounded,
                  color: AppColors.info,
                  count: item.maleCount,
                  onChanged: onChangeMale,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _SexCounter(
                  icon: Icons.female_rounded,
                  color: AppColors.accent,
                  count: item.femaleCount,
                  onChanged: onChangeFemale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One ♂ or ♀ stepper — used side by side in [_StockRow] so a fish
/// species' male and female counts are edited on the same line.
class _SexCounter extends StatelessWidget {
  const _SexCounter({
    required this.icon,
    required this.color,
    required this.count,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 2),
        _CompactIconButton(
          onPressed: count > 0 ? () => onChanged(count - 1) : null,
          icon: Icons.remove_circle_outline,
          color: AppColors.primary,
        ),
        SizedBox(
          width: 20,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.text),
          ),
        ),
        _CompactIconButton(
          onPressed: () => onChanged(count + 1),
          icon: Icons.add_circle_outline,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

/// A small, tight-footprint icon button for dense rows (steppers, remove
/// actions) where the default [IconButton] 48×48 minimum would crowd out
/// the content next to it on a narrow phone screen.
class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({required this.onPressed, required this.icon, required this.color});

  final VoidCallback? onPressed;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

/// Dimensions, temperature, substrate and setup notes for an aquarium,
/// terrarium or aviary — every field is optional, since owners fill in
/// whatever they actually know about the enclosure.
class _HabitatFields extends StatelessWidget {
  const _HabitatFields({
    required this.showVolume,
    required this.lengthController,
    required this.widthController,
    required this.heightController,
    required this.volumeController,
    required this.temperatureController,
    required this.substrateController,
    required this.notesController,
    required this.inputDecoration,
    required this.onDimensionChanged,
  });

  final bool showVolume;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;
  final TextEditingController volumeController;
  final TextEditingController temperatureController;
  final TextEditingController substrateController;
  final TextEditingController notesController;
  final InputDecoration Function(String label, String hint) inputDecoration;
  final VoidCallback onDimensionChanged;

  @override
  Widget build(BuildContext context) {
    final system = UnitSettingsStore.instance.system;
    final dimensionFormatters = [
      system.usesInches
          ? FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
          : FilteringTextInputFormatter.digitsOnly,
    ];
    final lengthUnit = lengthUnitName(system);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: lengthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration(context.l10n.petsFormHabitatLength, lengthUnit),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: widthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration(context.l10n.petsFormHabitatWidth, lengthUnit),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration(context.l10n.petsFormHabitatHeight, lengthUnit),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
          ],
        ),
        if (showVolume) ...[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: volumeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              system.usesUsGallons
                  ? FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))
                  : FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: inputDecoration(
              system.usesUsGallons
                  ? context.l10n.petsFormHabitatUsGallons
                  : context.l10n.petsFormHabitatLiters,
              context.l10n.petsFormHabitatVolumeHint,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: temperatureController,
          decoration: inputDecoration(
            context.l10n.petsFormHabitatTemperature,
            system.usesFahrenheit
                ? context.l10n.petsFormHabitatTemperatureHintF
                : context.l10n.petsFormHabitatTemperatureHintC,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: substrateController,
          decoration: inputDecoration(
            context.l10n.petsFormHabitatSubstrate,
            context.l10n.petsFormHabitatSubstrateHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: notesController,
          maxLines: 3,
          decoration: inputDecoration(
            context.l10n.petsFormHabitatEquipment,
            context.l10n.petsFormHabitatEquipmentHint,
          ),
        ),
      ],
    );
  }
}

class _IdentityColorPicker extends StatelessWidget {
  const _IdentityColorPicker({required this.value, required this.onChanged});

  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in petIdentityColors)
          InkWell(
            onTap: () => onChanged(color),
            customBorder: const CircleBorder(),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: color == value ? AppColors.text : Colors.transparent,
                  width: 2,
                ),
              ),
              child: color == value
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Searchable list of breeds. Typing narrows it; "Meticcio / altra razza" is
/// always offered so an unlisted breed can still be described.
class _BreedPickerSheet extends StatefulWidget {
  const _BreedPickerSheet({required this.options});

  final List<String> options;

  @override
  State<_BreedPickerSheet> createState() => _BreedPickerSheetState();
}

class _BreedPickerSheetState extends State<_BreedPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = foldBreedText(_query);
    // The free-text entry is always the last row, whatever was typed, so an
    // unlisted breed can be entered even when the search finds nothing.
    final freeText = widget.options.where(isOtherBreedEntry).toList(growable: false);
    final matches = [
      ...widget.options.where(
        (breed) => !isOtherBreedEntry(breed) && (query.isEmpty || breedMatchesQuery(breed, _query)),
      ),
      ...freeText,
    ];
    // Dogs and cats are searched by breed name; the scientific name only
    // matters for the other animal categories.
    final dogOrCat = widget.options.contains(otherBreedLabel);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: dogOrCat
                      ? context.l10n.petsFormBreedSearchHint
                      : context.l10n.petsFormBreedSearchHintScientific,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, index) {
                        final breed = matches[index];
                        final pinned = isPinnedBreedEntry(breed);
                        final lastPinned = pinned &&
                            (index + 1 >= matches.length || !isPinnedBreedEntry(matches[index + 1]));
                        final tile = ListTile(
                          tileColor: pinned ? AppColors.accentSoft.withValues(alpha: 0.35) : null,
                          leading: pinned ? const Icon(Icons.pets_outlined, color: AppColors.primary) : null,
                          title: Text(
                            breed == 'Razza non specificata'
                                ? context.l10n.petsBreedUnspecified
                                : breed,
                            style: pinned ? const TextStyle(fontWeight: FontWeight.w600) : null,
                          ),
                          onTap: () => Navigator.of(context).pop(breed),
                        );
                        if (!lastPinned) return tile;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [tile, const Divider(height: 1)],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
