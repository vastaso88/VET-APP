import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/pet_conditions_repository.dart';
import '../../domain/pet_condition.dart';
import '../record_category_labels.dart';
import 'pet_condition_form_page.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';

/// "Patologie": the illnesses of a pet, ongoing first. A tap opens the entry
/// to edit it; "Aggiungi" starts a new one.
class PetConditionsPage extends StatefulWidget {
  const PetConditionsPage({required this.pet, super.key});

  final PetProfile pet;

  @override
  State<PetConditionsPage> createState() => _PetConditionsPageState();
}

class _PetConditionsPageState extends State<PetConditionsPage> {
  final _repository = PetConditionsRepository();
  late Future<List<PetConditionEntry>> _future = _repository.loadForPet(
    widget.pet.id,
  );

  @override
  void initState() {
    super.initState();
    PetConditionsRepository.changes.addListener(_reload);
  }

  @override
  void dispose() {
    PetConditionsRepository.changes.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _repository.loadForPet(widget.pet.id);
    });
  }

  Future<void> _openForm([PetConditionEntry? existing]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PetConditionFormPage(pet: widget.pet, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: l10n.medCatCondition),
      // A pet in Ricordi: read only (the form opens without saving).
      floatingActionButton: widget.pet.isMemorial
          ? null
          : FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.medAddAction),
            ),
      body: SafeArea(
        child: FutureBuilder<List<PetConditionEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: PetLoader());
            }
            if (snapshot.hasError) {
              return CenteredPageState(
                child: EmptyState.icon(
                  icon: Icons.cloud_off_outlined,
                  text: l10n.medCondLoadError,
                  action: OutlinedButton(
                    onPressed: _reload,
                    child: Text(l10n.commonRetry),
                  ),
                ),
              );
            }

            final conditions = snapshot.data ?? const <PetConditionEntry>[];
            if (conditions.isEmpty) {
              return CenteredPageState(
                child: EmptyState.icon(
                  icon: conditionIcon,
                  title: l10n.medEmptyConditionTitle,
                  text: l10n.medEmptyConditionBody(widget.pet.name),
                  action: widget.pet.isMemorial
                      ? null
                      : FilledButton.icon(
                          onPressed: _openForm,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.medEmptyConditionAction),
                        ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                96,
              ),
              children: [
                Text(
                  '${widget.pet.name} · ${l10n.medCatCount(conditions.length)}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final condition in conditions) ...[
                  _ConditionRow(
                    condition: condition,
                    onTap: () => _openForm(condition),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition, required this.onTap});

  final PetConditionEntry condition;
  final VoidCallback onTap;

  String _period(BuildContext context) {
    final l10n = context.l10n;
    String day(DateTime date) => formatAppDate(date, 'd MMM y');
    final started = condition.startedOn;
    final ended = condition.endedOn;
    if (condition.ongoing) {
      return started == null ? '' : l10n.medCondSince(day(started));
    }
    if (started != null && ended != null) {
      return l10n.medCondPeriod(day(started), day(ended));
    }
    if (ended != null) return day(ended);
    return started == null ? '' : l10n.medCondSince(day(started));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = _period(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: Icon(
              conditionIcon,
              size: 17,
              color: AppColors.secondaryStrong,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  condition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (period.isNotEmpty)
                  Text(
                    period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: condition.ongoing
                  ? AppColors.secondarySoft
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              condition.ongoing ? l10n.medCondOngoing : l10n.medCondResolved,
              style: AppTextStyles.caption.copyWith(
                color: condition.ongoing
                    ? AppColors.primary
                    : AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.mutedText,
          ),
        ],
      ),
    );
  }
}
