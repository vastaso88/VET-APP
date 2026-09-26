import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_owner.dart';
import '../../../home/presentation/widgets/home_dashboard_primitives.dart';
import '../../../location/data/device_location_service.dart';
import '../../../location/domain/geo_math.dart';
import '../../data/marketplace_repository.dart';
import '../../domain/marketplace_listing.dart';
import '../marketplace_labels.dart';

/// Creates a listing for the internal P2P marketplace. The device's exact
/// position is requested fresh and immediately fuzzed (geo_math.dart)
/// before the listing is ever built - the exact coordinate never exists
/// outside this method's local scope.
class CreateListingPage extends StatefulWidget {
  const CreateListingPage({super.key, this.locationSampler = const GeolocatorLocationSampler()});

  /// Injectable so widget tests can substitute a fake position instead of
  /// requiring a real device/browser GPS permission prompt.
  final LocationSampler locationSampler;

  @override
  State<CreateListingPage> createState() => _CreateListingPageState();
}

class _CreateListingPageState extends State<CreateListingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();

  ListingCategory _category = ListingCategory.accessories;
  ListingCondition _condition = ListingCondition.good;
  bool _submitting = false;
  String? _locationError;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _locationError = null;
    });

    final locationResult = await widget.locationSampler.requestCurrentPosition();
    if (!locationResult.isSuccess) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _locationError =
            'Non riesco a rilevare la tua posizione: serve per mostrare l\'annuncio nella zona giusta (in forma approssimata). Controlla i permessi di localizzazione e riprova.';
      });
      return;
    }

    final now = DateTime.now();
    final id = 'listing-${now.microsecondsSinceEpoch}';
    final fuzzedLocation = fuzzCoordinates(locationResult.coordinates!, id);
    final priceText = _priceController.text.trim();
    // The form's own validator already rejects non-numeric/negative text, so
    // a successful parse is guaranteed here.
    final priceCents = priceText.isEmpty ? null : double.parse(priceText.replaceAll(',', '.')) * 100;

    final listing = MarketplaceListing(
      id: id,
      ownerId: resolveCurrentOwnerId(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      category: _category,
      condition: _condition,
      priceCents: priceCents?.round(),
      location: fuzzedLocation,
      cityLabel: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await MarketplaceRepository().saveListing(listing);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Nuovo annuncio', style: AppTextStyles.title),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione (facoltativa)'),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<ListingCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: ListingCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(listingCategoryLabel(category)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<ListingCondition>(
                initialValue: _condition,
                decoration: const InputDecoration(labelText: 'Condizione'),
                items: ListingCondition.values
                    .map(
                      (condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(listingConditionLabel(condition)),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _condition = value ?? _condition),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Prezzo in € (vuoto = gratis)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return null;
                  }
                  final parsed = double.tryParse(text.replaceAll(',', '.'));
                  if (parsed == null) {
                    return 'Inserisci un prezzo valido';
                  }
                  if (parsed < 0) {
                    return 'Il prezzo non può essere negativo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'Città (facoltativa)'),
              ),
              const SizedBox(height: AppSpacing.xl),
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
                        'Per la tua privacy, la posizione mostrata nell\'annuncio è sempre approssimata (mai il tuo indirizzo esatto).',
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ],
                ),
              ),
              if (_locationError != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_locationError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.xl),
              DashboardActionButton(
                label: _submitting ? 'Pubblicazione...' : 'Pubblica annuncio',
                icon: Icons.storefront_outlined,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
