import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';

/// Pets moved out of the active Animali list — kept here with their
/// profile and photo rather than deleted. No stats (walks, badges) yet:
/// that needs real tracking data this demo doesn't have behind it, so this
/// stays honest about being a placeholder rather than showing invented
/// numbers.
class PetMemoriesPage extends StatefulWidget {
  const PetMemoriesPage({super.key});

  @override
  State<PetMemoriesPage> createState() => _PetMemoriesPageState();
}

class _PetMemoriesPageState extends State<PetMemoriesPage> {
  List<PetProfile> _pets = PetDemoStore.instance.memorialPets();

  void _reload() => setState(() => _pets = PetDemoStore.instance.memorialPets());

  Future<void> _removePermanently(PetProfile pet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: const Text('Rimuovere definitivamente?'),
        content: Text('Il ricordo di "${pet.name}" verrà eliminato, senza possibilità di recupero.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annulla')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    PetDemoStore.instance.delete(pet.id);
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: 'Ricordi',
      subtitle: 'I profili dei pet che hanno condiviso la vostra strada.',
      onBack: () => Navigator.of(context).maybePop(),
      body: _pets.isEmpty
          ? Center(
              child: Text('Nessun ricordo conservato ancora.', style: AppTextStyles.bodySmall),
            )
          : ListView.separated(
              itemCount: _pets.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == _pets.length) {
                  return const _MemoriesComingSoonNote();
                }
                final pet = _pets[index];
                return _MemoryRow(pet: pet, onRemove: () => _removePermanently(pet));
              },
            ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.pet, required this.onRemove});

  final PetProfile pet;
  final VoidCallback onRemove;

  String _dateRange() {
    final memorialDate = pet.memorialDate;
    if (memorialDate == null) return pet.birthDateLabel;
    const months = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    final formatted = '${memorialDate.day} ${months[memorialDate.month - 1]} ${memorialDate.year}';
    return pet.birthDateLabel.isEmpty
        ? 'Con noi fino al $formatted'
        : 'Con noi dal ${pet.birthDateLabel} al $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetAvatar(
            label: pet.avatarEmoji,
            backgroundColor: pet.accentColor,
            photoBytes: pet.photoBytes,
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
                  '${pet.species} · ${pet.breedLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  _dateRange(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          _CompactRemoveButton(onPressed: onRemove),
        ],
      ),
    );
  }
}

class _CompactRemoveButton extends StatelessWidget {
  const _CompactRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.mutedText),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _MemoriesComingSoonNote extends StatelessWidget {
  const _MemoriesComingSoonNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primaryStrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Presto: i vostri momenti più belli insieme, come le passeggiate più lunghe o i traguardi '
              'raggiunti, raccolti qui.',
              style: AppTextStyles.caption.copyWith(color: AppColors.primaryStrong),
            ),
          ),
        ],
      ),
    );
  }
}
