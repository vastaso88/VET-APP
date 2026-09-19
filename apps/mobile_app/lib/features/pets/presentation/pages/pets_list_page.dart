import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';
import 'pet_create_page.dart';
import 'pet_detail_page.dart';

class PetsListPage extends StatefulWidget {
  const PetsListPage({
    super.key,
    this.state = PetsScreenStatus.success,
    this.errorMessage = 'Al momento non riesco a caricare i profili pet.',
  });

  final PetsScreenStatus state;
  final String errorMessage;

  @override
  State<PetsListPage> createState() => _PetsListPageState();
}

class _PetsListPageState extends State<PetsListPage> {
  String _selectedSpecies = 'Tutti';
  List<PetProfile> _pets = PetDemoStore.instance.list();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _pets = PetDemoStore.instance.list(species: _selectedSpecies);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;

    return PetsScaffold(
      title: 'Animali',
      subtitle: '${PetDemoStore.instance.list().length} profili',
      actions: [
        IconButton(
          onPressed: () => _openCreate(context),
          icon: const Icon(Icons.add_rounded),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: AppColors.primaryStrong),
        ),
      ],
      body: switch (state) {
        PetsScreenStatus.loading =>
          const PetsLoadingView(label: 'Carico la lista pet...'),
        PetsScreenStatus.error => PetsErrorView(
            title: 'Pet non disponibili',
            subtitle: widget.errorMessage,
            actionLabel: 'Indietro',
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.empty => PetsEmptyView(
            title: 'Nessun pet ancora',
            subtitle: 'Crea il primo profilo per tenere sotto controllo salute, note e scadenze.',
            actionLabel: 'Crea pet',
            onAction: () => _openCreate(context),
          ),
        PetsScreenStatus.success => _PetsListContent(
            pets: _pets,
            selectedSpecies: _selectedSpecies,
            onSpeciesChanged: (species) {
              setState(() {
                _selectedSpecies = species;
                _pets = PetDemoStore.instance.list(species: _selectedSpecies);
              });
            },
            onOpenPet: (pet) => _openDetail(context, pet),
          ),
      },
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PetCreatePage()),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _openDetail(BuildContext context, PetProfile pet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PetDetailPage(pet: pet)),
    );
    if (!mounted) return;
    _reload();
  }
}

class _PetsListContent extends StatelessWidget {
  const _PetsListContent({
    required this.pets,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    required this.onOpenPet,
  });

  final List<PetProfile> pets;
  final String selectedSpecies;
  final ValueChanged<String> onSpeciesChanged;
  final ValueChanged<PetProfile> onOpenPet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _SpeciesChip(
                label: 'Tutti',
                selected: selectedSpecies == 'Tutti',
                onTap: () => onSpeciesChanged('Tutti'),
              ),
              const SizedBox(width: AppSpacing.sm),
              ...PetDemoStore.speciesOptions.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _SpeciesChip(
                    label: option.label,
                    selected: selectedSpecies == option.label,
                    onTap: () => onSpeciesChanged(option.label),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: pets.isEmpty
              ? Center(
                  child: Text(
                    'Nessun pet per questo filtro.',
                    style: AppTextStyles.body,
                  ),
                )
              : ListView.separated(
                  itemCount: pets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return _PetRow(pet: pet, onTap: () => onOpenPet(pet));
                  },
                ),
        ),
      ],
    );
  }
}

class _PetRow extends StatelessWidget {
  const _PetRow({required this.pet, required this.onTap});

  final PetProfile pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              PetAvatar(
                label: pet.avatarEmoji,
                backgroundColor: pet.accentColor,
                photoBytes: pet.photoBytes,
                identityColor: pet.identityColor,
                size: 52,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: AppTextStyles.title.copyWith(fontSize: 17)),
                    const SizedBox(height: 2),
                    Text('${pet.species} · ${pet.breedLabel}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(pet.healthBadge, style: AppTextStyles.caption),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryStrong : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primaryStrong : AppColors.border),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
