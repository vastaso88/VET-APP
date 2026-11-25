import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/min_tap_target.dart';
import '../../../dog_walks/data/walk_home_widget.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';
import 'pet_create_page.dart';
import 'pet_detail_page.dart';
import 'pet_memories_page.dart';

class PetsListPage extends StatefulWidget {
  const PetsListPage({
    super.key,
    this.state = PetsScreenStatus.success,
    this.errorMessage,
  });

  final PetsScreenStatus state;
  final String? errorMessage;

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
    final state = widget.state;

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
      body: switch (state) {
        PetsScreenStatus.loading =>
          PetsLoadingView(label: context.l10n.petsListLoading),
        PetsScreenStatus.error => PetsErrorView(
            title: context.l10n.petsListErrorTitle,
            subtitle: widget.errorMessage ?? context.l10n.petsListErrorDefault,
            actionLabel: context.l10n.commonBack,
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.empty => PetsEmptyView(
            title: context.l10n.petsListEmptyTitle,
            subtitle: context.l10n.petsListEmptySubtitle,
            actionLabel: context.l10n.petsListEmptyAction,
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
            memorialCount: PetDemoStore.instance.memorialPets().length,
            onOpenMemories: () => _openMemories(context),
            onCreate: () => _openCreate(context),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: pets.isEmpty
              ? Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: memorialCount > 0 && selectedSpecies == 'Tutti'
                            ? _OnlyMemoriesEmpty(onCreate: onCreate)
                            : Text(
                                context.l10n.petsListFilterEmpty,
                                style: AppTextStyles.body,
                              ),
                      ),
                    ),
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
}

/// No active pet left, only memories: no "Crea pet" push — a new profile is
/// offered softly, for whenever the owner wants it.
class _OnlyMemoriesEmpty extends StatelessWidget {
  const _OnlyMemoriesEmpty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.petsListEmptyOnlyMemoriesTitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(fontSize: 17),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.petsListEmptyOnlyMemoriesSubtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onCreate,
            child: Text(context.l10n.petsListEmptyOnlyMemoriesAction),
          ),
        ],
      ),
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
              PetAvatar(
                label: pet.avatarEmoji,
                backgroundColor: pet.accentColor,
                photoBytes: pet.photoBytes,
                photoPath: pet.photoPath,
                identityColor: pet.identityColor,
                size: 52,
              ),
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
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
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
