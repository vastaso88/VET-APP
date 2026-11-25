import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import 'pet_memorial_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_card.dart';

/// Pets moved to Ricordi (docs/product/17_ricordi_animali.md §6). A row
/// opens the pet's memorial page; deleting forever happens only there, with
/// a confirmation — never from a quick tap on this list.
class PetMemoriesPage extends StatefulWidget {
  const PetMemoriesPage({super.key});

  @override
  State<PetMemoriesPage> createState() => _PetMemoriesPageState();
}

class _PetMemoriesPageState extends State<PetMemoriesPage> {
  List<PetProfile> _pets = PetDemoStore.instance.memorialPets();

  @override
  void initState() {
    super.initState();
    PetDemoStore.changes.addListener(_reload);
  }

  @override
  void dispose() {
    PetDemoStore.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _pets = PetDemoStore.instance.memorialPets());
  }

  Future<void> _open(PetProfile pet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PetMemorialPage(pet: pet)),
    );
    if (!mounted) return;
    // The last memory brought back or deleted: nothing left to show here.
    if (PetDemoStore.instance.memorialPets().isEmpty) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsMemoriesTitle,
      subtitle: context.l10n.petsMemoriesSubtitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: _pets.isEmpty
          ? CenteredPageState(
              child: EmptyState.icon(
                icon: Icons.auto_awesome_outlined,
                text: context.l10n.petsMemoriesEmpty,
                padding: EmptyState.insidePage,
              ),
            )
          : ListView.separated(
              itemCount: _pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final pet = _pets[index];
                return _MemoryRow(pet: pet, onTap: () => _open(pet));
              },
            ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.pet, required this.onTap});

  final PetProfile pet;
  final VoidCallback onTap;

  String _dateRange(BuildContext context) {
    final birth = localizedBirthDateLabel(pet.birthDateLabel);
    final memorialDate = pet.memorialDate;
    if (memorialDate == null) return birth;
    final formatted = formatAppDate(memorialDate, 'd MMM y');
    return birth.isEmpty
        ? context.l10n.petsMemoriesWithUsUntil(formatted)
        : context.l10n.petsMemoriesWithUsRange(birth, formatted);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PetAvatar(
                label: pet.avatarEmoji,
                backgroundColor: pet.accentColor,
                photoBytes: pet.photoBytes,
                photoPath: pet.photoPath,
                identityColor: pet.identityColor,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pet.speciesDisplayLabel} · ${pet.breedLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateRange(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
    );
  }
}
