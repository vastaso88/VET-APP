import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../age/data/age_store.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/travel_cards_repository.dart';
import '../../domain/travel_card.dart';
import '../../domain/travel_countries.dart';
import '../../domain/travel_pet_species.dart';
import '../../domain/travel_resolver.dart';
import '../widgets/travel_country_sheet.dart';
import '../widgets/travel_result_view.dart';

/// "Around the world": the rules for travelling with a pet (docs/product/18).
///
/// Three choices (where from, where to, who comes along) and the cards that
/// answer them. The cards are all downloaded and picked here, on the phone:
/// nothing about the trip is sent to the server, nothing is saved.
class TravelGuidePage extends StatefulWidget {
  const TravelGuidePage({super.key, this.repository});

  final TravelCardsRepository? repository;

  @override
  State<TravelGuidePage> createState() => _TravelGuidePageState();
}

/// One traveller of the answer: a pet of the owner, or a species.
class _Traveller {
  const _Traveller(this.label, this.species);

  final String label;
  final TravelSpecies? species;
}

class _TravelGuidePageState extends State<TravelGuidePage> {
  late final TravelCardsRepository _repository = widget.repository ?? BackendTravelCardsRepository();

  TravelCountry? _from = travelCountryByCode('IT');
  TravelCountry? _to;
  final Set<String> _petIds = {};
  final Set<TravelSpecies> _species = {};
  List<PetProfile> _pets = const [];

  bool _loading = false;
  bool _failed = false;
  String? _message;
  List<TravelResultSection>? _sections;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPets());
  }

  Future<void> _loadPets() async {
    try {
      await PetDemoStore.instance.ensureHydrated();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _pets = PetDemoStore.instance.list());
  }

  String _speciesLabel(TravelSpecies species) {
    final l10n = context.l10n;
    return switch (species) {
      TravelSpecies.dog => l10n.aroundWorldSpeciesDog,
      TravelSpecies.cat => l10n.aroundWorldSpeciesCat,
      TravelSpecies.ferret => l10n.aroundWorldSpeciesFerret,
    };
  }

  Future<void> _pickCountry({required bool origin}) async {
    final picked = await showTravelCountrySheet(context, selected: origin ? _from : _to);
    if (picked == null || !mounted) return;
    setState(() {
      if (origin) {
        _from = picked;
      } else {
        _to = picked;
      }
      _sections = null;
      _message = null;
    });
  }

  Future<void> _show() async {
    final l10n = context.l10n;
    final from = _from;
    final to = _to;
    final travellers = <_Traveller>[
      for (final pet in _pets)
        if (_petIds.contains(pet.id)) _Traveller(pet.name, travelSpeciesOfPet(pet)),
      for (final species in _species) _Traveller(_speciesLabel(species), species),
    ];
    if (from == null || to == null || travellers.isEmpty) {
      setState(() {
        _message = l10n.aroundWorldPickAll;
        _sections = null;
      });
      return;
    }
    if (from.code == to.code) {
      setState(() {
        _message = l10n.aroundWorldSameCountry;
        _sections = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _message = null;
      _sections = null;
    });
    try {
      final cards = await _repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sections = [
          for (final traveller in travellers)
            TravelResultSection(
              title: l10n.aroundWorldResultHeader(traveller.label, from.name, to.name),
              answer: resolveTravel(
                cards: cards,
                fromCode: from.code,
                toCode: to.code,
                species: traveller.species,
              ),
            ),
        ];
      });
    } on TravelCardsUnavailable {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _reportError(TravelCard card) async {
    final l10n = context.l10n;
    final email = AgeStore.instance.status.supportContactEmail;
    if (email == null || email.isEmpty) return;
    final uri = Uri.parse(
      'mailto:$email?subject=${Uri.encodeComponent(l10n.aroundWorldMailSubject(card.code))}',
    );
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canReport = (AgeStore.instance.status.supportContactEmail ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l10n.aroundWorldTitle, style: AppTextStyles.heading),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
          children: [
            // Level 1 of the notices (docs/compliance/17 A.11): always visible.
            _NoticeBox(text: l10n.aroundWorldNotice),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(title: l10n.aroundWorldInfoTitle, body: l10n.aroundWorldInfoBody),
            const SizedBox(height: AppSpacing.lg),
            _CountryField(
              label: l10n.aroundWorldFromLabel,
              country: _from,
              onTap: () => _pickCountry(origin: true),
            ),
            const SizedBox(height: AppSpacing.md),
            _CountryField(
              label: l10n.aroundWorldToLabel,
              country: _to,
              onTap: () => _pickCountry(origin: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.aroundWorldWhoLabel, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            if (_pets.isNotEmpty) ...[
              Text(l10n.aroundWorldMyPets, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final pet in _pets)
                    FilterChip(
                      label: Text(pet.name),
                      selected: _petIds.contains(pet.id),
                      onSelected: (on) => setState(() {
                        on ? _petIds.add(pet.id) : _petIds.remove(pet.id);
                        _sections = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(l10n.aroundWorldBySpecies, style: AppTextStyles.caption),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final species in TravelSpecies.values)
                  FilterChip(
                    label: Text(_speciesLabel(species)),
                    selected: _species.contains(species),
                    onSelected: (on) => setState(() {
                      on ? _species.add(species) : _species.remove(species);
                      _sections = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _loading ? null : _show,
              child: Text(l10n.aroundWorldShow),
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_message!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerStrong)),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_failed) ...[
              const SizedBox(height: AppSpacing.md),
              Text(l10n.aroundWorldLoadError, style: AppTextStyles.bodySmall),
              TextButton(onPressed: _show, child: Text(l10n.aroundWorldRetry)),
            ],
            if (_sections != null) ...[
              const SizedBox(height: AppSpacing.xl),
              TravelResultView(
                sections: _sections!,
                onReportError: canReport ? _reportError : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.warningStrong, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        title: Text(title, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        children: [Text(body, style: AppTextStyles.bodySmall)],
      ),
    );
  }
}

class _CountryField extends StatelessWidget {
  const _CountryField({required this.label, required this.country, required this.onTap});

  final String label;
  final TravelCountry? country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            border: Border.all(color: AppColors.borderStrong, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Text(
                      country == null ? context.l10n.aroundWorldCountryHint : '${country!.flag}  ${country!.name}',
                      style: AppTextStyles.body.copyWith(
                        color: country == null ? AppColors.mutedText : AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.search, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
