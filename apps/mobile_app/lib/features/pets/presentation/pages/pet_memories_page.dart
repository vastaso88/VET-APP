import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
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
        title: Text(context.l10n.petsMemoriesRemoveTitle),
        content: Text(context.l10n.petsMemoriesRemoveBody(pet.name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.petsMemoriesRemoveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await PetDemoStore.instance.delete(pet.id);
    } on PetSyncException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsMemoriesTitle,
      subtitle: context.l10n.petsMemoriesSubtitle,
      onBack: () => Navigator.of(context).maybePop(),
      body: _pets.isEmpty
          ? Center(
              child: Text(context.l10n.petsMemoriesEmpty, style: AppTextStyles.bodySmall),
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
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primaryStrong),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.petsMemoriesComingSoon,
              style: AppTextStyles.caption.copyWith(color: AppColors.primaryStrong),
            ),
          ),
        ],
      ),
    );
  }
}
