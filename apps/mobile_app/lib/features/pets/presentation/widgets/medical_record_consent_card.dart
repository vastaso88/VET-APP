import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/medical_record_consent_remote_data_source.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';

/// Per-pet switch for letting the chat read this pet's clinical records.
/// Off means the chat sees neither titles nor contents. Read from the pet row
/// on open, written with PUT, and applied locally at once on success.
class MedicalRecordConsentCard extends StatefulWidget {
  const MedicalRecordConsentCard({required this.pet, this.compact = false, super.key});

  final PetProfile pet;

  /// Settings variant: title and switch only, without the consent explanation
  /// (the full text is shown where the records are).
  final bool compact;

  @override
  State<MedicalRecordConsentCard> createState() => _MedicalRecordConsentCardState();
}

/// The approved consent wording (packages/core/domain/medical_record/consent_text.py,
/// version v1). Kept verbatim so the copy the owner reads is the copy on record.
const _approvedConsentText =
    "Per darti un consiglio più preciso, l'assistente può consultare le "
    'informazioni cliniche già registrate per il tuo animale (es. visite, '
    'esami, vaccinazioni). Verranno usate solo le informazioni rilevanti '
    "per la domanda in corso, mai l'intera cartella. Puoi revocare questo "
    'consenso in qualsiasi momento dalle impostazioni.';

class _MedicalRecordConsentCardState extends State<MedicalRecordConsentCard> {
  final _remote = MedicalRecordConsentRemoteDataSource();

  late bool? _granted = widget.pet.medicalRecordConsentGranted;
  bool _saving = false;
  bool _statusUnknown = false;
  String? _error;

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
    final remote = await PetDemoStore.instance.fetchMedicalRecordConsent(widget.pet.id);
    if (!mounted) return;
    setState(() {
      _statusUnknown = remote == null && _granted == null;
      if (remote != null) {
        _granted = remote;
        _statusUnknown = false;
      }
    });
    if (remote != null) {
      PetDemoStore.instance.setMedicalRecordConsentLocal(widget.pet.id, remote);
    }
  }

  Future<void> _toggle(bool value) async {
    final previous = _granted;
    setState(() {
      _granted = value;
      _saving = true;
      _error = null;
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
          _error = error.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.pet.name;
    final granted = _granted ?? false;

    final titleRow = Row(
      children: [
        Expanded(
          child: Text(
            "Consenti all'assistente di leggere la cartella clinica di $name",
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          value: granted,
          onChanged: _saving ? null : _toggle,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          if (!widget.compact) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_approvedConsentText, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Senza consenso l'assistente non vede né i titoli né il contenuto dei referti.",
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: Colors.red.shade700),
            ),
          ],
          if (_statusUnknown) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Non riesco a leggere lo stato del consenso: controlla la connessione.',
              style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
            ),
          ],
        ],
      ),
    );
  }
}
