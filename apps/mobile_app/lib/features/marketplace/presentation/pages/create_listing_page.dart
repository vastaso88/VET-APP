import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../location/domain/coordinates.dart';
import '../../data/area_label_geocoder.dart';
import '../../data/listing_photo_store.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/listing_location.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';
import '../widgets/listing_photo.dart';

/// Where the listing's (approximated) position comes from.
enum _LocationChoice { keep, current, home }

/// A photo already on the listing (url) or just picked and cleaned (bytes).
class _DraftPhoto {
  const _DraftPhoto.existing(String this.url) : bytes = null;
  const _DraftPhoto.picked(Uint8List this.bytes) : url = null;

  final String? url;
  final Uint8List? bytes;
}

/// Creates a listing, or edits [existing] when given (author only - the
/// detail page shows the entry point only to them, and the repository
/// checks again). The exact position (GPS or the Località residence) is
/// snapped to the ~1 km grid as soon as it's read and never leaves this
/// state otherwise: the zone name is looked up from the snapped point too.
class CreateListingPage extends StatefulWidget {
  const CreateListingPage({
    super.key,
    this.existing,
    this.locationSampler = const GeolocatorLocationSampler(),
    this.areaLabelResolver,
    this.repository,
    this.currentOwnerId,
  });

  final MarketplaceListing? existing;

  /// Injectable so widget tests can substitute a fake position instead of
  /// requiring a real device/browser GPS permission prompt.
  final LocationSampler locationSampler;
  final AreaLabelResolver? areaLabelResolver;
  final MarketplaceRepository? repository;
  final String? currentOwnerId;

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _zoneController = TextEditingController();
  final _picker = ImagePicker();

  late final MarketplaceRepository _repository = widget.repository ?? MarketplaceRepository();
  late final AreaLabelResolver _areaLabelResolver =
      widget.areaLabelResolver ?? NominatimAreaLabelResolver();

  ListingCategory? _category;
  ListingCondition _condition = ListingCondition.good;
  bool _isGift = false;
  final Set<ListingSpecies> _species = {};
  final List<_DraftPhoto> _photos = [];
  bool _processingPhotos = false;

  _LocationChoice? _locationChoice;
  Coordinates? _homeLocation;
  Coordinates? _approxLocation;
  bool _resolvingLocation = false;
  bool _zoneEditedByUser = false;
  int _locationRequest = 0;
  String? _locationError;

  bool _submitting = false;
  String? _submitError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _category = existing.category;
      _condition = existing.condition;
      _isGift = existing.isGift;
      if (existing.priceCents != null) {
        _priceController.text =
            (existing.priceCents! / 100).toStringAsFixed(2).replaceAll('.', ',');
      }
      _species.addAll(existing.species);
      _photos.addAll(existing.photoUrls.map(_DraftPhoto.existing));
    }
    _initLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _zoneController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;
    if (!mounted) return;
    setState(() => _homeLocation = preference.home);

    final _LocationChoice initial;
    if (_isEditing) {
      initial = _LocationChoice.keep;
    } else if (preference.mode == LocationMode.homeResidence && preference.home != null) {
      initial = _LocationChoice.home;
    } else {
      initial = _LocationChoice.current;
    }
    await _selectLocation(initial);
  }

  Future<void> _selectLocation(_LocationChoice choice) async {
    final request = ++_locationRequest;
    setState(() {
      _locationChoice = choice;
      _locationError = null;
      _approxLocation = null;
      _resolvingLocation = choice != _LocationChoice.keep;
    });

    if (choice == _LocationChoice.keep) {
      final existing = widget.existing!;
      setState(() {
        _approxLocation = existing.location;
        _zoneController.text = existing.cityLabel ?? '';
        _zoneEditedByUser = false;
      });
      return;
    }

    Coordinates? exact;
    if (choice == _LocationChoice.home) {
      exact = _homeLocation;
    } else {
      final result = await widget.locationSampler.requestCurrentPosition();
      exact = result.coordinates;
    }
    if (!mounted || request != _locationRequest) return;

    if (exact == null) {
      setState(() {
        _resolvingLocation = false;
        _locationError = _homeLocation != null
            ? 'Non riesco a rilevare la tua posizione. Controlla i permessi di localizzazione oppure usa la residenza.'
            : 'Non riesco a rilevare la tua posizione: serve per mostrare l\'annuncio nella zona giusta (in forma approssimata). Controlla i permessi di localizzazione e riprova.';
      });
      return;
    }

    final approx = approximateListingLocation(exact);
    setState(() => _approxLocation = approx);

    final label = await _areaLabelResolver.areaLabelOf(approx);
    if (!mounted || request != _locationRequest) return;
    setState(() {
      _resolvingLocation = false;
      if (label != null && !_zoneEditedByUser) _zoneController.text = label;
    });
  }

  Future<void> _pickPhotos(ImageSource source) async {
    final remaining = maxListingPhotos - _photos.length;
    if (remaining <= 0) return;

    final List<XFile> files;
    try {
      if (source == ImageSource.camera) {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 100,
          // Metadata is stripped anyway; asking for it would need a library permission.
          requestFullMetadata: false,
        );
        files = file == null ? const [] : [file];
      } else {
        files = await _picker.pickMultiImage(
          imageQuality: 100,
          limit: remaining > 1 ? remaining : null,
          requestFullMetadata: false,
        );
      }
    } catch (_) {
      _showMessage(
          'Non riesco ad aprire ${source == ImageSource.camera ? 'la fotocamera' : 'la galleria'}.');
      return;
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _processingPhotos = true);
    var skipped = 0;
    for (final file in files.take(remaining)) {
      try {
        final cleaned = await compute(prepareListingPhoto, await file.readAsBytes());
        if (!mounted) return;
        setState(() => _photos.add(_DraftPhoto.picked(cleaned)));
      } catch (_) {
        skipped++;
      }
    }
    if (!mounted) return;
    setState(() => _processingPhotos = false);
    if (skipped > 0) _showMessage('$skipped foto non leggibili sono state saltate.');
    if (files.length > remaining) {
      _showMessage('Puoi aggiungere al massimo $maxListingPhotos foto.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// "Tutte le specie" and the single species exclude each other.
  void _toggleSpecies(ListingSpecies species, bool selected) {
    if (!selected) {
      _species.remove(species);
    } else if (species == ListingSpecies.allSpecies) {
      _species
        ..clear()
        ..add(species);
    } else {
      _species
        ..remove(ListingSpecies.allSpecies)
        ..add(species);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_approxLocation == null) {
      if (_locationChoice != null && !_resolvingLocation) {
        await _selectLocation(_locationChoice!);
      }
      if (_approxLocation == null) {
        setState(() => _locationError ??= 'Aspetta che la zona sia stata trovata, poi riprova.');
        return;
      }
    }

    setState(() => _submitting = true);
    final requesterId = widget.currentOwnerId ?? resolveCurrentOwnerId();
    final existing = widget.existing;
    final now = DateTime.now();
    final id = existing?.id ?? 'listing-${now.microsecondsSinceEpoch}';
    final ownerId = existing?.ownerId ?? requesterId;
    final uploaded = <String>[];

    try {
      final photoUrls = <String>[];
      for (final photo in _photos) {
        if (photo.url != null) {
          photoUrls.add(photo.url!);
        } else {
          final url = await _repository.photoStore.upload(
            ownerId: ownerId,
            listingId: id,
            preparedJpeg: photo.bytes!,
          );
          uploaded.add(url);
          photoUrls.add(url);
        }
      }

      final description = _descriptionController.text.trim();
      final zone = _zoneController.text.trim();
      final priceCents = _isGift
          ? null
          : (double.parse(_priceController.text.trim().replaceAll(',', '.')) * 100).round();
      final species = ListingSpecies.values.where(_species.contains).toList();

      if (existing == null) {
        await _repository.createListing(
          MarketplaceListing(
            id: id,
            ownerId: ownerId,
            title: _titleController.text.trim(),
            description: description.isEmpty ? null : description,
            category: _category!,
            condition: _condition,
            priceCents: priceCents,
            photoUrls: photoUrls,
            species: species,
            location: _approxLocation!,
            cityLabel: zone.isEmpty ? null : zone,
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await _repository.updateListing(
          existing.copyWith(
            title: _titleController.text.trim(),
            description: () => description.isEmpty ? null : description,
            category: _category,
            condition: _condition,
            priceCents: () => priceCents,
            photoUrls: photoUrls,
            species: species,
            location: _approxLocation,
            cityLabel: () => zone.isEmpty ? null : zone,
            updatedAt: now,
          ),
          requesterId: requesterId,
        );
        // Only once the listing no longer points at them.
        await _repository.photoStore.remove(
          existing.photoUrls.where((url) => !photoUrls.contains(url)).toList(),
        );
      }
    } catch (error) {
      await _repository.photoStore.remove(uploaded);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = error is ListingPermissionException
            ? error.toString()
            : 'Non sono riuscito a salvare l\'annuncio. Controlla la connessione e riprova.';
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  String? _validatePrice(String? value) {
    if (_isGift) return null;
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Inserisci un prezzo, oppure scegli "In regalo"';
    final parsed = double.tryParse(text.replaceAll(',', '.'));
    if (parsed == null) return 'Inserisci un prezzo valido';
    if (parsed < 0) return 'Il prezzo non può essere negativo';
    if (parsed == 0) return 'Per regalarlo scegli "In regalo"';
    if (parsed > 100000) return 'Prezzo troppo alto';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title:
            Text(_isEditing ? 'Modifica annuncio' : 'Nuovo annuncio', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            children: [
              _PhotosSection(
                photos: _photos,
                processing: _processingPhotos,
                onAddFromCamera: () => _pickPhotos(ImageSource.camera),
                onAddFromGallery: () => _pickPhotos(ImageSource.gallery),
                onRemove: (index) => setState(() => _photos.removeAt(index)),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo'),
                maxLength: 80,
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione (facoltativa)'),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<ListingCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: ListingCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(listingCategoryLabel(category)),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? 'Scegli una categoria' : null,
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Condizione', style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: ListingCondition.values
                    .map(
                      (condition) => ChoiceChip(
                        label: Text(listingConditionLabel(condition)),
                        selected: _condition == condition,
                        onSelected: (_) => setState(() => _condition = condition),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Per quali animali', style: AppTextStyles.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              FormField<Set<ListingSpecies>>(
                validator: (_) => _species.isEmpty
                    ? 'Indica per quali animali è, oppure "Tutte le specie"'
                    : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: ListingSpecies.values
                          .map(
                            (species) => FilterChip(
                              label: Text(listingSpeciesLabel(species)),
                              selected: _species.contains(species),
                              onSelected: (selected) {
                                setState(() => _toggleSpecies(species, selected));
                                field.didChange(_species);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    if (field.hasError) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        field.errorText!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('In regalo'),
                subtitle: const Text('Lo regali a chi ne ha bisogno'),
                value: _isGift,
                onChanged: (value) => setState(() => _isGift = value),
              ),
              if (!_isGift)
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Prezzo in €'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validatePrice,
                ),
              const SizedBox(height: AppSpacing.xl),
              _LocationSection(
                choice: _locationChoice,
                isEditing: _isEditing,
                hasHome: _homeLocation != null,
                resolving: _resolvingLocation,
                hasLocation: _approxLocation != null,
                error: _locationError,
                zoneController: _zoneController,
                onZoneEdited: () => _zoneEditedByUser = true,
                onChoice: _selectLocation,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_submitError!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.xl),
              DashboardActionButton(
                label: _submitting
                    ? 'Salvataggio...'
                    : _isEditing
                        ? 'Salva modifiche'
                        : 'Pubblica annuncio',
                icon: _isEditing ? Icons.check_rounded : Icons.storefront_outlined,
                onPressed: _submitting || _processingPhotos ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.photos,
    required this.processing,
    required this.onAddFromCamera,
    required this.onAddFromGallery,
    required this.onRemove,
  });

  final List<_DraftPhoto> photos;
  final bool processing;
  final VoidCallback onAddFromCamera;
  final VoidCallback onAddFromGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final full = photos.length >= maxListingPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto (${photos.length}/$maxListingPhotos)', style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        if (photos.isNotEmpty || processing)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + (processing ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return const SizedBox(
                    width: 88,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final photo = photos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: photo.bytes != null
                            ? Image.memory(photo.bytes!, fit: BoxFit.cover)
                            : ListingPhoto(url: photo.url!),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => onRemove(index),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            OutlinedButton.icon(
              onPressed: full || processing ? null : onAddFromCamera,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Scatta foto'),
            ),
            OutlinedButton.icon(
              onPressed: full || processing ? null : onAddFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Dalla galleria'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Prima dell\'invio togliamo dalle foto i dati nascosti (posizione, dispositivo, data).',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.choice,
    required this.isEditing,
    required this.hasHome,
    required this.resolving,
    required this.hasLocation,
    required this.error,
    required this.zoneController,
    required this.onZoneEdited,
    required this.onChoice,
  });

  final _LocationChoice? choice;
  final bool isEditing;
  final bool hasHome;
  final bool resolving;
  final bool hasLocation;
  final String? error;
  final TextEditingController zoneController;
  final VoidCallback onZoneEdited;
  final ValueChanged<_LocationChoice> onChoice;

  @override
  Widget build(BuildContext context) {
    Widget chip(_LocationChoice value, String label, {bool enabled = true}) => ChoiceChip(
          label: Text(label),
          selected: choice == value,
          onSelected: enabled ? (_) => onChoice(value) : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dove si trova', style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (isEditing) chip(_LocationChoice.keep, 'Zona attuale dell\'annuncio'),
            chip(_LocationChoice.current, 'Dove sono ora'),
            chip(_LocationChoice.home, 'Residenza', enabled: hasHome),
          ],
        ),
        if (!hasHome) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Per usare la residenza impostala in Impostazioni → Località.',
            style: AppTextStyles.caption,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (resolving)
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Cerco la tua zona...', style: AppTextStyles.caption),
            ],
          ),
        if (error != null)
          Text(error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
        TextFormField(
          controller: zoneController,
          decoration: const InputDecoration(
            labelText: 'Zona mostrata (quartiere o comune)',
            helperText: 'Niente via o numero civico',
          ),
          maxLength: 80,
          onChanged: (_) => onZoneEdited(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  hasLocation
                      ? 'Sulla mappa l\'annuncio appare in un punto approssimato (circa 1 km), mai al tuo indirizzo.'
                      : 'Per la tua privacy, la posizione dell\'annuncio è sempre approssimata (circa 1 km), mai il tuo indirizzo esatto.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
