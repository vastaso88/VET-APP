import '../../../account_consents/presentation/widgets/consent_activation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/medical_record_consent_remote_data_source.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../../../../shared/widgets/app_card.dart';

/// Per-pet switch for letting the chat read this pet's clinical records.
/// Off means the chat sees neither titles nor contents. Read from the pet row
/// on open, written with PUT, and applied locally at once on success.
class MedicalRecordConsentCard extends StatefulWidget {
  const MedicalRecordConsentCard({required this.pet, this.remote, this.readConsent, super.key});

  final PetProfile pet;

  /// Overridable for tests.
  final MedicalRecordConsentRemoteDataSource? remote;

  /// Overridable for tests: how the stored decision is read.
  final Future<({bool reachable, bool? granted})> Function(String petId)? readConsent;

  @override
  State<MedicalRecordConsentCard> createState() => _MedicalRecordConsentCardState();
}

class _MedicalRecordConsentCardState extends State<MedicalRecordConsentCard> {
  late final _remote = widget.remote ?? MedicalRecordConsentRemoteDataSource();

  late bool? _granted = widget.pet.medicalRecordConsentGranted;
  bool _saving = false;
  bool _expanded = false;
  _CardStatus _status = _CardStatus.none;

  @override
  void initState() {
    super.initState();
    _refreshFromServer();
  }

  @override
  void didUpdateWidget(covariant MedicalRecordConsentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = widget.pet.medicalRecordConsentGranted != oldWidget.pet.medicalRecordConsentGranted;
    if (changed && !_saving) {
      _granted = widget.pet.medicalRecordConsentGranted;
    }
  }

  Future<void> _refreshFromServer() async {
    final read = await (widget.readConsent ?? PetDemoStore.instance.readMedicalRecordConsent)(
      widget.pet.id,
    );
    if (!mounted) return;
    final remote = read.granted;
    setState(() {
      // Only a read that did not reach the server is a connection problem; an
      // answer without a decision just means the owner has not decided yet.
      if (!read.reachable && _granted == null) _status = _CardStatus.readError;
      if (read.reachable) {
        _granted = remote;
        _status = _CardStatus.none;
      }
    });
    if (remote != null) {
      PetDemoStore.instance.setMedicalRecordConsentLocal(widget.pet.id, remote);
    }
  }

  Future<void> _toggle(bool value) async {
    // Turning it on: what it is, where the data goes, how to take it back, and
    // only then the decision. Turning it off is one tap, no question.
    if (value && !await askToActivateClinicalConsent(context, widget.pet.name)) return;
    if (!mounted) return;
    final previous = _granted;
    setState(() {
      _granted = value;
      _saving = true;
      _status = _CardStatus.none;
    });

    final result = await _remote.setGranted(petId: widget.pet.id, granted: value);
    if (!mounted) return;

    result.fold(
      onSuccess: (saved) {
        PetDemoStore.instance.setMedicalRecordConsentLocal(widget.pet.id, saved);
        setState(() {
          _granted = saved;
          _saving = false;
        });
      },
      onFailure: (error) {
        setState(() {
          _granted = previous;
          _saving = false;
          _status = _CardStatus.saveError;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.pet.name;
    final granted = _granted ?? false;

    // One row: tapping the title area expands the full consent text, tapping
    // again closes it. The arrow and "Leggi" make the expansion evident; the
    // switch stays separate so toggling never needs the text open.
    final titleRow = Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded
                ? context.l10n.petsConsentSemanticsExpanded(name)
                : context.l10n.petsConsentSemanticsCollapsed(name),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.small),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.petsConsentCardTitle(name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _expanded ? context.l10n.commonClose : context.l10n.petsConsentReadHow,
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.secondaryStrong,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm),
            child: PetLoader.small(),
          ),
        Semantics(
          label: context.l10n.petsConsentSwitchSemantics(name),
          child: Switch(
            value: granted,
            onChanged: _saving ? null : _toggle,
          ),
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(context.l10n.petsConsentFullText, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.petsConsentWithoutConsent,
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (_status != _CardStatus.none) ...[
            Text(
              _status == _CardStatus.saveError
                  ? context.l10n.petsConsentSaveFailed
                  : context.l10n.petsConsentStatusUnavailable,
              style: AppTextStyles.caption.copyWith(
                color: _status == _CardStatus.saveError ? AppColors.dangerStrong : AppColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

enum _CardStatus { none, saveError, readError }

/// The question before «Attiva» for the clinical-record consent of one pet: the
/// short text (what, to whom, how to turn it off), the line that nothing is
/// lost without it, and the way to read the whole text. Same words wherever the
/// switch appears (card, chat, new document, a new pet). True only for «Attiva».
Future<bool> askToActivateClinicalConsent(BuildContext context, String petName) {
  final l10n = context.l10n;
  return askToActivateConsent(
    context,
    title: l10n.petsConsentCardTitle(petName),
    summary: '${l10n.petsConsentShort(petName)}\n\n${l10n.petsConsentWithoutConsent}',
    fullText: l10n.petsConsentFullText,
  );
}
