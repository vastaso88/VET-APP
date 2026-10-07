import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/medical_record_consent_remote_data_source.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';

/// Per-pet switch for letting the chat read this pet's clinical records.
/// Off means the chat sees neither titles nor contents. Read from the pet row
/// on open, written with PUT, and applied locally at once on success.
class MedicalRecordConsentCard extends StatefulWidget {
  const MedicalRecordConsentCard({required this.pet, super.key});

  final PetProfile pet;

  @override
  State<MedicalRecordConsentCard> createState() => _MedicalRecordConsentCardState();
}

/// The approved consent wording (packages/core/domain/medical_record/consent_text.py,
/// version v2). Kept verbatim so the copy the owner reads is the copy on record:
/// tests/unit/test_consent_texts_match_behaviour.py checks that the two match.
const _approvedConsentText =
    "Per darti un consiglio più preciso, l'assistente può leggere la "
    'cartella clinica del tuo animale. Quando fai una domanda può leggere '
    'le tre voci più recenti, con titolo, data, descrizione e testo dei '
    "documenti allegati, anche se non c'entrano con la domanda. Se chiedi "
    'di spiegare un esame, può leggere i documenti che lo riguardano, al '
    "massimo due. Di un documento molto lungo legge solo l'inizio. Ciò che "
    'legge viene inviato al fornitore esterno di intelligenza artificiale '
    'che scrive la risposta. VetApp lo usa solo per risponderti. Puoi '
    "revocare il consenso in qualsiasi momento dalla scheda dell'animale o "
    'dalle Impostazioni: vale per le richieste successive.';

class _MedicalRecordConsentCardState extends State<MedicalRecordConsentCard> {
  final _remote = MedicalRecordConsentRemoteDataSource();

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
    final remote = await PetDemoStore.instance.fetchMedicalRecordConsent(widget.pet.id);
    if (!mounted) return;
    setState(() {
      if (remote == null && _granted == null) _status = _CardStatus.readError;
      if (remote != null) {
        _granted = remote;
        _status = _CardStatus.none;
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
            label: 'Consenso alla lettura della cartella clinica di $name. '
                '${_expanded ? 'Tocca per chiudere il testo completo' : 'Tocca per leggere il testo completo'}',
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
                            'Cartella clinica di $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _expanded ? 'Chiudi' : 'Leggi come viene usata',
                            style: AppTextStyles.caption.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.primary,
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
          label: "Consenti all'assistente di leggere la cartella clinica di $name",
          child: Switch(
            value: granted,
            onChanged: _saving ? null : _toggle,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleRow,
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(_approvedConsentText, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Senza consenso l'assistente non vede né i titoli né il contenuto dei referti.",
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (_status != _CardStatus.none) ...[
            Text(
              _status == _CardStatus.saveError
                  ? 'Non sono riuscito a salvare il consenso. Riprova.'
                  : 'Stato del consenso non disponibile: controlla la connessione.',
              style: AppTextStyles.caption.copyWith(
                color: _status == _CardStatus.saveError ? Colors.red.shade700 : AppColors.mutedText,
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
