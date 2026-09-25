import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/pet_demo_store.dart';
import '../../domain/fish_species.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_identity_colors.dart';
import '../../domain/pet_models.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import 'pet_avatar.dart';
import 'pet_sections.dart';

class PetProfileDraft {
  const PetProfileDraft({
    required this.name,
    required this.species,
    required this.breed,
    this.birthDate,
    required this.sex,
    required this.weightKg,
    required this.medicalNote,
    required this.identityColor,
    this.photoBytes,
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
  final double weightKg;
  final String medicalNote;
  final Color identityColor;
  final Uint8List? photoBytes;
  final List<FishStock> aquariumStock;
  final HabitatDetails? habitat;
  final String? dogSizeCategory;
}

/// Species that live in an enclosure worth describing (dimensions, water/
/// substrate, equipment) rather than roaming free in the house.
bool _speciesHasHabitat(String? species) =>
    species == 'Pesce' || species == 'Rettili e anfibi' || species == 'Uccello';

String _habitatLabel(String? species) => switch (species) {
      'Pesce' => 'Acquario',
      'Rettili e anfibi' => 'Terrario',
      'Uccello' => 'Voliera',
      _ => 'Habitat',
    };

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
  late String? _dogSizeCategory;
  late String? _sex;
  DateTime? _birthDate;
  Uint8List? _photoBytes;
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
    _dogSizeCategory = pet?.dogSizeCategory;
    _sex = pet?.sex;
    _birthDate = _parseBirthDate(pet?.birthDateLabel);
    _photoBytes = pet?.photoBytes;
    _identityColor = pet?.identityColor ?? PetDemoStore.instance.nextDefaultIdentityColor();
    _isAquarium = pet?.isAquarium ?? false;
    _aquariumStock = List.of(pet?.aquariumStock ?? const []);
    _lengthController = TextEditingController(text: habitat?.lengthCm?.toString() ?? '');
    _widthController = TextEditingController(text: habitat?.widthCm?.toString() ?? '');
    _heightController = TextEditingController(text: habitat?.heightCm?.toString() ?? '');
    _volumeController = TextEditingController(text: habitat?.volumeLiters?.toString() ?? '');
    _volumeController.addListener(() {
      if (_isAutoUpdatingVolume) return;
      _volumeManuallyEdited = true;
    });
    _temperatureController = TextEditingController(text: habitat?.temperatureLabel ?? '');
    _substrateController = TextEditingController(text: habitat?.substrate ?? '');
    _habitatNotesController = TextEditingController(text: habitat?.notes ?? '');
  }

  void _recalculateVolume() {
    if (_volumeManuallyEdited) return;
    final length = int.tryParse(_lengthController.text.trim());
    final width = int.tryParse(_widthController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (length == null || width == null || height == null) return;

    final liters = (length * width * height / 1000).round();
    _isAutoUpdatingVolume = true;
    _volumeController.text = liters.toString();
    _isAutoUpdatingVolume = false;
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    setState(() => _photoBytes = bytes);
  }

  void _removePhoto() => setState(() => _photoBytes = null);

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
                  'Hai già aggiunto tutte le specie disponibili.',
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
                    child: Text('Aggiungi specie', style: AppTextStyles.title),
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
                      identityColor: _identityColor,
                      backgroundColor: _speciesAccentColor(),
                      label: label,
                      onPick: _pickPhoto,
                      onRemove: _photoBytes == null ? null : _removePhoto,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Colore identificativo', style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.xs),
                _IdentityColorPicker(
                  value: _identityColor,
                  onChanged: (color) => setState(() => _identityColor = color),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Nome', 'Moka'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Inserisci il nome del pet.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _species,
                  decoration: _inputDecoration('Specie', 'Seleziona una specie'),
                  items: PetDemoStore.speciesOptions
                      .map(
                        (option) => DropdownMenuItem<String>(
                          value: option.label,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _species = value;
                      _breed = null;
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
                      return 'Seleziona una specie.';
                    }
                    return null;
                  },
                ),
                if (_species == 'Pesce') ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Tipo di profilo', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _AquariumModeToggle(
                    value: _isAquarium,
                    onChanged: (value) => setState(() => _isAquarium = value),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_species == 'Pesce' && _isAquarium) ...[
                  Text('Popolazione dell\'acquario', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.xs),
                  _AquariumStockEditor(
                    stock: _aquariumStock,
                    onAdd: _openAddSpeciesSheet,
                    onChangeMale: _changeMaleCount,
                    onChangeFemale: _changeFemaleCount,
                    onRemove: _removeStock,
                  ),
                ] else
                  DropdownButtonFormField<String>(
                    initialValue: breedOptions.contains(_breed) ? _breed : null,
                    decoration: _inputDecoration(
                      'Razza',
                      _species == null
                          ? 'Seleziona prima la specie'
                          : 'Facoltativa',
                    ),
                    items: breedOptions
                        .map(
                          (breed) => DropdownMenuItem<String>(
                            value: breed == 'Razza non specificata' ? '' : breed,
                            child: Text(breed),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _species == null
                        ? null
                        : (value) {
                            setState(() {
                              _breed = value;
                              if (value != 'Altro') {
                                _dogSizeCategory = null;
                              }
                            });
                          },
                  ),
                if (_species == 'Cane' && _breed == 'Altro') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _dogSizeCategory,
                    decoration: _inputDecoration('Taglia', 'Seleziona una taglia'),
                    items: PetDemoStore.dogSizeCategories
                        .map(
                          (size) => DropdownMenuItem<String>(value: size, child: Text(size)),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _dogSizeCategory = value),
                  ),
                ],
                if (_speciesHasHabitat(_species)) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(_habitatLabel(_species), style: AppTextStyles.caption),
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
                  InkWell(
                    onTap: _pickBirthDate,
                    borderRadius: BorderRadius.circular(18),
                    child: InputDecorator(
                      decoration:
                          _inputDecoration('Data di nascita', 'Seleziona una data'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _birthDate == null
                                  ? 'Seleziona una data'
                                  : formatPetBirthDate(_birthDate!),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: _birthDate == null
                                    ? AppColors.mutedText
                                    : AppColors.text,
                              ),
                            ),
                          ),
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                  if (_birthDate == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Seleziona la data di nascita.',
                      style: AppTextStyles.caption.copyWith(color: Colors.red.shade700),
                    ),
                  ],
                ],
                // Fish don't get a standalone Sesso field: for an aquarium,
                // one sex value for the whole tank doesn't make sense — it's
                // tracked per species instead, right in the population
                // editor above. A single fish just doesn't show it.
                if (_species != 'Pesce') ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _sex,
                    decoration: _inputDecoration('Sesso', 'Seleziona'),
                    items: PetDemoStore.sexOptions
                        .map(
                          (sex) => DropdownMenuItem<String>(
                            value: sex,
                            child: Text(sex),
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
                        return 'Seleziona il sesso.';
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
                  decoration: _inputDecoration('Peso', 'Es. 18,4'),
                  validator: (value) {
                    final parsed = _parseWeight(value);
                    if (parsed == null) {
                      return 'Inserisci un peso valido.';
                    }
                    if (parsed <= 0) {
                      return 'Il peso deve essere maggiore di zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Note',
                    'Aggiungi note brevi su dieta, farmaci o comportamento.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded),
                label: Text(widget.submitLabel),
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

  Future<void> _pickBirthDate() async {
    final initialDate = _birthDate ?? DateTime(2021, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  void _submit() async {
    final isAquariumProfile = _species == 'Pesce' && _isAquarium;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || (!isAquariumProfile && _birthDate == null)) {
      setState(() {});
      return;
    }

    if (isAquariumProfile && _aquariumStock.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aggiungi almeno una specie all\'acquario.')),
      );
      return;
    }

    final draft = PetProfileDraft(
      name: _nameController.text.trim(),
      species: _species!.trim(),
      breed: isAquariumProfile ? null : _normalizeBreed(_breed),
      birthDate: isAquariumProfile ? null : _birthDate,
      sex: _sex!.trim(),
      weightKg: _parseWeight(_weightController.text)!,
      medicalNote: _notesController.text.trim(),
      identityColor: _identityColor,
      photoBytes: _photoBytes,
      aquariumStock: isAquariumProfile ? _aquariumStock : const [],
      habitat: _buildHabitat(),
      dogSizeCategory: _species == 'Cane' && _breed == 'Altro' ? _dogSizeCategory : null,
    );

    await widget.onSubmit(draft);
  }

  HabitatDetails? _buildHabitat() {
    if (!_speciesHasHabitat(_species)) return null;

    final habitat = HabitatDetails(
      lengthCm: int.tryParse(_lengthController.text.trim()),
      widthCm: int.tryParse(_widthController.text.trim()),
      heightCm: int.tryParse(_heightController.text.trim()),
      volumeLiters: _species == 'Pesce' ? int.tryParse(_volumeController.text.trim()) : null,
      temperatureLabel: _temperatureController.text.trim(),
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

    final normalized = raw.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _weightFromLabel(String? label) {
    final raw = label?.replaceAll('kg', '').trim() ?? '';
    return raw.replaceAll(',', '.');
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
      'Gen': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'Mag': 5,
      'Giu': 6,
      'Lug': 7,
      'Ago': 8,
      'Set': 9,
      'Ott': 10,
      'Nov': 11,
      'Dic': 12,
    };

    return months[label];
  }

}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoBytes,
    required this.identityColor,
    required this.backgroundColor,
    required this.label,
    required this.onPick,
    this.onRemove,
  });

  final Uint8List? photoBytes;
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
                label: Text(photoBytes == null ? 'Aggiungi foto' : 'Cambia foto'),
              ),
              if (onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Rimuovi'),
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
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.set_meal_outlined, size: 16),
          label: Text('Un pesce'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.water_outlined, size: 16),
          label: Text('Acquario'),
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
            child: Text('Nessuna specie aggiunta ancora.', style: AppTextStyles.bodySmall),
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
          label: const Text('Aggiungi specie'),
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
    final dimensionFormatters = [FilteringTextInputFormatter.digitsOnly];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: lengthController,
                keyboardType: TextInputType.number,
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration('Lunghezza', 'cm'),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: widthController,
                keyboardType: TextInputType.number,
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration('Larghezza', 'cm'),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextFormField(
                controller: heightController,
                keyboardType: TextInputType.number,
                inputFormatters: dimensionFormatters,
                decoration: inputDecoration('Altezza', 'cm'),
                onChanged: (_) => onDimensionChanged(),
              ),
            ),
          ],
        ),
        if (showVolume) ...[
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: volumeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: inputDecoration('Litri', 'Calcolati dalle dimensioni, modificabili'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: temperatureController,
          decoration: inputDecoration('Temperatura', 'Es. 24-26°C'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: substrateController,
          decoration: inputDecoration('Substrato', 'Es. ghiaia fine, fibra di cocco'),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: notesController,
          maxLines: 3,
          decoration: inputDecoration(
            'Attrezzatura',
            'Filtro, illuminazione, riscaldatore, piante, lampada UVB, posatoi...',
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
