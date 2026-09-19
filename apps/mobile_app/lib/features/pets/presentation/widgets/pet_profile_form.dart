import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/pet_demo_store.dart';
import '../../domain/pet_identity_colors.dart';
import '../../domain/pet_models.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import 'pet_avatar.dart';
import 'pet_sections.dart';

class PetProfileDraft {
  const PetProfileDraft({
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.sex,
    required this.weightKg,
    required this.medicalNote,
    required this.identityColor,
    this.photoBytes,
  });

  final String name;
  final String species;
  final String? breed;
  final DateTime birthDate;
  final String sex;
  final double weightKg;
  final String medicalNote;
  final Color identityColor;
  final Uint8List? photoBytes;
}

class PetProfileForm extends StatefulWidget {
  const PetProfileForm({
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    super.key,
    this.initialPet,
    this.helperText = 'Compila i campi richiesti per continuare.',
  });

  final PetProfile? initialPet;
  final String title;
  final String helperText;
  final String submitLabel;
  final Future<void> Function(PetProfileDraft draft) onSubmit;

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
  late String? _sex;
  DateTime? _birthDate;
  Uint8List? _photoBytes;
  late Color _identityColor;

  @override
  void initState() {
    super.initState();
    final pet = widget.initialPet;
    _nameController = TextEditingController(text: pet?.name ?? '');
    _weightController = TextEditingController(
      text: _weightFromLabel(pet?.weightLabel),
    );
    _notesController = TextEditingController(text: pet?.medicalNote ?? '');
    _species = pet?.species;
    _breed = _normalizeBreed(pet?.breed);
    _sex = pet?.sex;
    _birthDate = _parseBirthDate(pet?.birthDateLabel);
    _photoBytes = pet?.photoBytes;
    _identityColor = pet?.identityColor ?? PetDemoStore.instance.nextDefaultIdentityColor();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breedOptions = _breedOptionsForSelectedSpecies();

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PetSection(
              title: widget.title,
              subtitle: widget.helperText,
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
                    });
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Seleziona una specie.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
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
                          });
                        },
                ),
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
                                : _formatDate(_birthDate!),
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
                    'Note cliniche',
                    'Aggiungi note brevi su dieta, farmaci o comportamento.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PetSection(
              title: 'Salva profilo',
              subtitle: 'I campi contrassegnati sono obbligatori.',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(widget.submitLabel),
                  ),
                ),
              ],
            ),
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
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _birthDate == null) {
      setState(() {});
      return;
    }

    final draft = PetProfileDraft(
      name: _nameController.text.trim(),
      species: _species!.trim(),
      breed: _normalizeBreed(_breed),
      birthDate: _birthDate!,
      sex: _sex!.trim(),
      weightKg: _parseWeight(_weightController.text)!,
      medicalNote: _notesController.text.trim(),
      identityColor: _identityColor,
      photoBytes: _photoBytes,
    );

    await widget.onSubmit(draft);
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

  String _formatDate(DateTime date) {
    const months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic',
    ];

    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
