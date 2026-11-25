import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart' show appCountryName;
import '../../../../shared/date/calendar_days.dart';
import '../../../location/data/location_preference_store.dart';
import '../../../territory/domain/territory.dart';
import '../../data/event_submission_repository.dart';
import '../../domain/event_entry.dart';
import '../../domain/event_regions.dart';
import '../../domain/event_submission.dart';
import '../event_labels.dart';
import '../../../../shared/widgets/page_header.dart';
import '../../../../shared/widgets/app_field.dart';

/// "Segnala un evento": titolo, tipo, date, paese, luogo e link. L'invio va in
/// moderazione (non compare subito nell'elenco) e non raccoglie dati di terzi.
class SubmitEventPage extends StatefulWidget {
  const SubmitEventPage({super.key, this.repository, this.now = DateTime.now});

  /// Iniettabili per i test.
  final EventSubmissionRepository? repository;
  final DateTime Function() now;

  @override
  State<SubmitEventPage> createState() => _SubmitEventPageState();
}

class _SubmitEventPageState extends State<SubmitEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _venue = TextEditingController();
  final _link = TextEditingController();
  late final EventSubmissionRepository _repository =
      widget.repository ?? EventSubmissionRepository();

  String _eventType = eventTypeCodes.first;
  late String _country =
      defaultEventCountry(LocationPreferenceStore.instance.preference.homeCountryCode);
  String? _region;
  DateTimeRange? _dates;
  bool _datesMissing = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _province.dispose();
    _venue.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final today = dayOnly(widget.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 2, today.month, today.day),
      initialDateRange: _dates,
      helpText: context.l10n.eventsSuggestPickDates,
      saveText: context.l10n.eventsPickDatesSave,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dates = picked;
      _datesMissing = false;
    });
  }

  /// Only Italy writes the two letters of the province.
  bool get _asksProvince => _country == sourceTerritoryCode;

  void _chooseCountry(String? country) {
    if (country == null || country == _country) return;
    setState(() {
      _country = country;
      _region = null;
      _province.clear();
    });
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _send() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _datesMissing = _dates == null);
    if (!valid || _dates == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    final outcome = await _repository.submit(
      EventSubmissionDraft(
        title: _title.text.trim(),
        eventType: _eventType,
        startsOn: dayOnly(_dates!.start),
        endsOn: dayOnly(_dates!.end),
        country: _country,
        region: _region,
        city: _city.text.trim(),
        provinceCode: _optional(_province)?.toUpperCase(),
        venueName: _optional(_venue),
        sourceUrl: _link.text.trim(),
      ),
    );
    if (!mounted) return;

    final l10n = context.l10n;
    switch (outcome) {
      case EventSubmissionSent():
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.eventsSuggestThanks)));
        Navigator.of(context).pop(true);
      case EventSubmissionNotSignedIn():
        _fail(l10n.eventsSuggestNeedLogin);
      case EventSubmissionLimitReached():
        _fail(l10n.eventsSuggestLimit);
      case EventSubmissionRejected(:final message):
        _fail(message);
      case EventSubmissionFailed():
        _fail(l10n.eventsSuggestError);
    }
  }

  void _fail(String message) {
    setState(() {
      _sending = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final countries = [
      for (final code in knownTerritoryCodes) (code: code, name: appCountryName(code) ?? code),
    ]..sort((a, b) => a.name.compareTo(b.name));
    final regions = eventRegionsByCountry[_country] ?? const <String>[];
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? l10n.eventsSuggestRequired : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PageHeader(title: l10n.eventsSuggestTitle),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.xxxl,
            ),
            // Not a lazy list: the fields out of view must be validated too.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.eventsSuggestIntro, style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.eventsSuggestPrivacy, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.lg),
                AppField(
                  label: l10n.eventsSuggestFieldTitle,
                  child: TextFormField(
                    controller: _title,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    validator: required,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppField(
                  label: l10n.eventsSuggestFieldType,
                  child: DropdownButtonFormField<String>(
                    initialValue: _eventType,
                    isExpanded: true,
                    items: [
                      for (final code in eventTypeCodes)
                        DropdownMenuItem(value: code, child: Text(eventTypeLabel(code))),
                    ],
                    onChanged: (value) => setState(() => _eventType = value ?? _eventType),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dates == null
                        ? l10n.eventsSuggestFieldDates
                        : eventDateRangeLabel(_dates!.start, _dates!.end),
                  ),
                ),
                if (_datesMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      l10n.eventsSuggestRequired,
                      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                AppField(
                  key: const ValueKey('event-country'),
                  label: l10n.eventsSuggestFieldCountry,
                  child: DropdownButtonFormField<String>(
                    initialValue: _country,
                    isExpanded: true,
                    items: [
                      for (final country in countries)
                        DropdownMenuItem(value: country.code, child: Text(country.name)),
                    ],
                    onChanged: _chooseCountry,
                  ),
                ),
                if (regions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppField(
                    key: ValueKey('event-region-$_country'),
                    label: l10n.eventsSuggestFieldRegion,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _region,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String?>(child: Text(l10n.eventsSuggestRegionNone)),
                        for (final region in regions)
                          DropdownMenuItem<String?>(value: region, child: Text(region)),
                      ],
                      onChanged: (value) => setState(() => _region = value),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppField(
                  // Keys: the fields below keep their own state when the region or the
                  // province comes and goes with the country.
                  key: const ValueKey('event-city'),
                  label: l10n.eventsSuggestFieldCity,
                  child: TextFormField(
                    controller: _city,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    validator: required,
                  ),
                ),
                if (_asksProvince)
                  AppField(
                    key: const ValueKey('event-province'),
                    label: l10n.eventsSuggestFieldProvince,
                    child: TextFormField(
                      controller: _province,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        return text.isNotEmpty && text.length != 2
                            ? l10n.eventsSuggestInvalidProvince
                            : null;
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppField(
                  key: const ValueKey('event-venue'),
                  label: l10n.eventsSuggestFieldVenue,
                  child: TextFormField(
                    controller: _venue,
                    maxLength: 80,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppField(
                  key: const ValueKey('event-link'),
                  label: l10n.eventsSuggestFieldLink,
                  child: TextFormField(
                    controller: _link,
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return l10n.eventsSuggestRequired;
                      return isValidEventLink(value) ? null : l10n.eventsSuggestInvalidLink;
                    },
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.danger)),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.eventsSuggestSend),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
