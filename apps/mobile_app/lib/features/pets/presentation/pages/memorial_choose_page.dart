import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../application/memorial_service.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../memorial_restore_message.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import 'memorial_move_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/app_card.dart';

/// "Which pet is no longer with you?": the active pets, one tap to the usual
/// two-step move to Ricordi ([MemorialMovePage]).
///
/// It exists for the paywall: without a plan the app shows nothing else, yet
/// moving a pet to Ricordi stays possible (owner decision 2026-11-16: whoever
/// loses an animal must not meet a paywall to stop its reminders, medicines and
/// birthday wishes; the database lets that one write through,
/// plan_access_move_gate in scripts/setup/plan_access_rules.sql). Calm, no plan
/// or payment is mentioned, and there is no "undo" here: bringing a pet back needs
/// a plan.
class MemorialChoosePage extends StatefulWidget {
  const MemorialChoosePage({super.key, this.service});

  final MemorialService? service;

  @override
  State<MemorialChoosePage> createState() => _MemorialChoosePageState();
}

class _MemorialChoosePageState extends State<MemorialChoosePage> {
  @override
  void initState() {
    super.initState();
    // The paywall may be the first screen after sign-in: make sure the pets are
    // loaded (reading is always allowed).
    unawaited(PetDemoStore.instance.ensureHydrated());
  }

  Future<void> _choose(PetProfile pet) async {
    final service = widget.service ?? MemorialService();
    try {
      // Before the farewell flow opens, as from the pet's own page.
      service.ensureRoomInMemories();
    } on MemoriesFullBlocksMove catch (blocked) {
      await showMemorialMoveBlocked(context, pet.name, blocked);
      return;
    }
    if (!mounted) return;
    final moved = await Navigator.of(context).push<PetProfile>(
      MaterialPageRoute(builder: (_) => MemorialMovePage(pet: pet, service: widget.service)),
    );
    if (moved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.memorialMoveDone(moved.name))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.petsEditMemorialAction,
      onBack: () => Navigator.of(context).maybePop(),
      body: ValueListenableBuilder<int>(
        valueListenable: PetDemoStore.changes,
        builder: (context, _, __) {
          final pets = PetDemoStore.instance.list();
          if (pets.isEmpty) {
            return CenteredPageState(
              child: EmptyState.icon(
                key: const ValueKey('memorial-choose-empty'),
                icon: Icons.auto_awesome_outlined,
                text: context.l10n.memorialChooseEmpty,
                padding: EmptyState.insidePage,
              ),
            );
          }
          return ListView(
            children: [
              Text(context.l10n.memorialChoosePrompt, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              for (final pet in pets) ...[
                _PetRow(pet: pet, onTap: () => _choose(pet)),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        },
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
    return AppCard(
      key: ValueKey('memorial-choose-${pet.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
            children: [
              PetRingAvatar(pet: pet, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(pet.name, style: AppTextStyles.body)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
    );
  }
}
