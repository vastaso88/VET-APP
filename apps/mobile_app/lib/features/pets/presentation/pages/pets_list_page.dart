import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/min_tap_target.dart';
import '../../../../shared/widgets/pill_row.dart';
import '../../../dog_walks/data/walk_home_widget.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import 'pet_create_page.dart';
import 'pet_detail_page.dart';
import 'pet_memories_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../widgets/species_figure.dart';

class PetsListPage extends StatefulWidget {
  const PetsListPage({super.key});

  @override
  State<PetsListPage> createState() => _PetsListPageState();
}

class _PetsListPageState extends State<PetsListPage> {
  String _selectedSpecies = 'Tutti';
  List<PetProfile> _pets = PetDemoStore.instance.list();

  @override
  void initState() {
    super.initState();
    PetDemoStore.changes.addListener(_onPetsChanged);
    _reload();
  }

  @override
  void dispose() {
    PetDemoStore.changes.removeListener(_onPetsChanged);
    super.dispose();
  }

  void _onPetsChanged() {
    if (!mounted) return;
    setState(() {
      _pets = PetDemoStore.instance.list(species: _selectedSpecies);
    });
  }

  Future<void> _reload() async {
    await PetDemoStore.instance.ensureHydrated();
    if (!mounted) return;
    setState(() {
      _pets = PetDemoStore.instance.list(species: _selectedSpecies);
    });
    unawaited(syncPetsToHomeWidget(PetDemoStore.instance.list()));
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsListTitle,
      subtitle: petProfilesCountLabel(PetDemoStore.instance.list().length),
      actions: [
        // Ricordi is NOT up here on purpose: it sits quietly at the bottom of
        // the list (docs/product/17_ricordi_animali.md §2).
        IconButton(
          tooltip: context.l10n.petsListEmptyOnlyMemoriesAction,
          onPressed: () => _openCreate(context),
          icon: const Icon(Icons.add_rounded),
          color: AppColors.onPrimary,
          style: IconButton.styleFrom(backgroundColor: AppColors.primary),
        ),
      ],
      body: _PetsListContent(
        pets: _pets,
        selectedSpecies: _selectedSpecies,
        onSpeciesChanged: (species) {
          setState(() {
            _selectedSpecies = species;
            _pets = PetDemoStore.instance.list(species: _selectedSpecies);
          });
        },
        onOpenPet: (pet) => _openDetail(context, pet),
        memorialCount: PetDemoStore.instance.memorialPets().length,
        onOpenMemories: () => _openMemories(context),
        onCreate: () => _openCreate(context),
      ),
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

  Future<void> _openMemories(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PetMemoriesPage()),
    );
    if (!mounted) return;
    setState(() {});
  }
}

class _PetsListContent extends StatelessWidget {
  const _PetsListContent({
    required this.pets,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    required this.onOpenPet,
    required this.memorialCount,
    required this.onOpenMemories,
    required this.onCreate,
  });

  final List<PetProfile> pets;
  final String selectedSpecies;
  final ValueChanged<String> onSpeciesChanged;
  final ValueChanged<PetProfile> onOpenPet;

  /// Pets in Ricordi: when there is at least one, a quiet row closes the list.
  final int memorialCount;
  final VoidCallback onOpenMemories;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PillRow(
          children: [
            _SpeciesChip(
              label: localizedSpeciesLabel('Tutti'),
              selected: selectedSpecies == 'Tutti',
              onTap: () => onSpeciesChanged('Tutti'),
            ),
            const SizedBox(width: AppSpacing.sm),
            ...PetDemoStore.speciesOptions.map(
              (option) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _SpeciesChip(
                  label: localizedSpeciesLabel(option.label),
                  selected: selectedSpecies == option.label,
                  onTap: () => onSpeciesChanged(option.label),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: pets.isEmpty
              ? Column(
                  children: [
                    Expanded(child: CenteredPageState(child: _empty(context))),
                    if (memorialCount > 0)
                      MemoriesListRow(count: memorialCount, onTap: onOpenMemories),
                  ],
                )
              : ListView.separated(
                  itemCount: pets.length + (memorialCount > 0 ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    if (index == pets.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: MemoriesListRow(count: memorialCount, onTap: onOpenMemories),
                      );
                    }
                    final pet = pets[index];
                    return _PetRow(pet: pet, onTap: () => onOpenPet(pet));
                  },
                ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final l10n = context.l10n;
    if (selectedSpecies != 'Tutti') {
      return EmptyState.figure(
        figure: SpeciesFigure(species: selectedSpecies, size: EmptyState.figureSize),
        title: l10n.petsListFilterEmpty,
        padding: EmptyState.insidePage,
        action: FilledButton(
          onPressed: onCreate,
          child: Text(l10n.petsListEmptyOnlyMemoriesAction),
        ),
      );
    }
    if (memorialCount > 0) {
      // No active pet left, only memories: no mascot and no push, a new profile
      // is offered softly, for whenever the owner wants it.
      return EmptyState.icon(
        icon: Icons.auto_awesome_outlined,
        title: l10n.petsListEmptyOnlyMemoriesTitle,
        text: l10n.petsListEmptyOnlyMemoriesSubtitle,
        padding: EmptyState.insidePage,
        action: TextButton(
          onPressed: onCreate,
          child: Text(l10n.petsListEmptyOnlyMemoriesAction),
        ),
      );
    }
    return EmptyState(
      title: l10n.petsListEmptyTitle,
      text: l10n.petsListEmptySubtitle,
      padding: EmptyState.insidePage,
      action: FilledButton(onPressed: onCreate, child: Text(l10n.petsListEmptyAction)),
    );
  }
}

/// The entry to Ricordi at the very bottom of Animali: muted colours, no
/// badge, the count in plain grey (doc 17 §2).
class MemoriesListRow extends StatelessWidget {
  const MemoriesListRow({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('memories-row'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 20, color: AppColors.mutedText),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.petsMemoriesTitle,
                      style: AppTextStyles.body.copyWith(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.petsListMemoriesRowSubtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
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
              PetRingAvatar(pet: pet, size: 52),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.speciesDisplayLabel} · ${pet.breedLabel}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
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
    return MinTapTarget(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: selected ? AppColors.primary : AppColors.borderStrong),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.secondaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
