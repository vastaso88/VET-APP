import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/date/calendar_days.dart';
import '../../data/event_submission_repository.dart';
import '../../domain/event_entry.dart';
import '../../domain/event_submission.dart';
import '../event_labels.dart';

/// "Segnala un evento": titolo, tipo, date, luogo e link. L'invio va in
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
    String? required(String? value) =>
        value == null || value.trim().isEmpty ? l10n.eventsSuggestRequired : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(l10n.eventsSuggestTitle, style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              Text(l10n.eventsSuggestIntro, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.eventsSuggestPrivacy, style: AppTextStyles.caption),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _title,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldTitle),
                validator: required,
              ),
              DropdownButtonFormField<String>(
                initialValue: _eventType,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldType),
                items: [
                  for (final code in eventTypeCodes)
                    DropdownMenuItem(value: code, child: Text(eventTypeLabel(code))),
                ],
                onChanged: (value) => setState(() => _eventType = value ?? _eventType),
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
              TextFormField(
                controller: _city,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldCity),
                validator: required,
              ),
              TextFormField(
                controller: _province,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldProvince),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.isNotEmpty && text.length != 2
                      ? l10n.eventsSuggestInvalidProvince
                      : null;
                },
              ),
              TextFormField(
                controller: _venue,
                maxLength: 80,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldVenue),
              ),
              TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l10n.eventsSuggestFieldLink),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return l10n.eventsSuggestRequired;
                  return isValidEventLink(value) ? null : l10n.eventsSuggestInvalidLink;
                },
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
    );
  }
}
