import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/events_repository.dart';
import '../../domain/event_entry.dart';
import '../../domain/event_filter.dart';
import '../event_labels.dart';

typedef EventLinkLauncher = Future<void> Function(Uri url);

Future<void> _launchExternal(Uri url) async {
  await launchUrl(url, webOnlyWindowName: '_blank');
}

/// Sezione "Eventi": elenco nazionale di eventi per animali, senza mappa.
/// Si apre sulla finestra "prossimi 30 giorni"; date, regione e tipo sono
/// filtri dell'utente. Toccare una card apre il sito ufficiale dell'evento (se
/// c'è un link: altrimenti la card non fa nulla). Date e link sono verificati
/// dal curatore sul sito dell'organizzatore e possono cambiare: l'avviso in
/// fondo lo dice.
class EventsPage extends StatefulWidget {
  const EventsPage({
    super.key,
    this.repository,
    this.launcher = _launchExternal,
    this.now = DateTime.now,
  });

  /// Iniettabili per i test (nessun backend, nessun browser, data fissa).
  final EventsRepository? repository;
  final EventLinkLauncher launcher;
  final DateTime Function() now;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  late final EventsRepository _repository = widget.repository ?? EventsRepository();
  late EventFilter _filter = EventFilter.defaultWindow(widget.now());
  late Future<EventsLoadResult> _future = _load();

  Future<EventsLoadResult> _load() => _repository.loadEvents(from: _filter.from, to: _filter.to);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  bool get _isDefaultView => _filter.isDefaultWindow(widget.now()) && !_filter.hasExtraFilters;

  void _resetFilters() {
    _filter = EventFilter.defaultWindow(widget.now());
    _reload();
  }

  Future<void> _pickDates() async {
    final today = eventDay(widget.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day - 30),
      lastDate: DateTime(today.year + 2, today.month, today.day),
      initialDateRange: DateTimeRange(start: _filter.from, end: _filter.to),
      helpText: 'Scegli il periodo',
      saveText: 'Applica',
    );
    if (picked == null || !mounted) return;
    _filter = _filter.copyWith(from: eventDay(picked.start), to: eventDay(picked.end));
    _reload();
  }

  Future<void> _pickRegion(List<String> regions) async {
    final chosen = await _pickOne<String>(
      title: 'Regione',
      allLabel: 'Tutte le regioni',
      options: regions,
      labelOf: (region) => region,
      selected: _filter.region,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _filter = chosen.isAll ? _filter.copyWith(clearRegion: true) : _filter.copyWith(region: chosen.value);
    });
  }

  Future<void> _pickType(List<String> types) async {
    final chosen = await _pickOne<String>(
      title: 'Tipo di evento',
      allLabel: 'Tutti i tipi',
      options: types,
      labelOf: eventTypeLabel,
      selected: _filter.eventType,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _filter = chosen.isAll
          ? _filter.copyWith(clearEventType: true)
          : _filter.copyWith(eventType: chosen.value);
    });
  }

  Future<_Choice<T>?> _pickOne<T>({
    required String title,
    required String allLabel,
    required List<T> options,
    required String Function(T) labelOf,
    required T? selected,
  }) {
    return showModalBottomSheet<_Choice<T>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                child: Text(title, style: AppTextStyles.title),
              ),
              ListTile(
                title: Text(allLabel),
                trailing: selected == null ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.of(sheetContext).pop(_Choice<T>.all()),
              ),
              for (final option in options)
                ListTile(
                  title: Text(labelOf(option)),
                  trailing: option == selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () => Navigator.of(sheetContext).pop(_Choice<T>.value(option)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = eventDay(widget.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Eventi', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: FutureBuilder<EventsLoadResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: PetLoader(label: 'Cerco gli eventi...'));
            }

            final result = snapshot.data ?? const EventsLoadResult(events: [], failed: true);
            if (result.failed) {
              return _ErrorState(onRetry: _reload);
            }

            final inWindow = filterEventsByWindow(result.events, _filter);
            final visible = applyEventFilter(result.events, _filter);

            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxxl,
                ),
                children: [
                  _FilterBar(
                    dateLabel: eventWindowChipLabel(_filter, today),
                    regionLabel: _filter.region ?? 'Tutte le regioni',
                    typeLabel: _filter.eventType == null ? 'Tutti i tipi' : eventTypeLabel(_filter.eventType!),
                    regionActive: _filter.region != null,
                    typeActive: _filter.eventType != null,
                    datesActive: !_filter.isDefaultWindow(today),
                    onPickDates: _pickDates,
                    onPickRegion: () => _pickRegion(availableRegions(inWindow)),
                    onPickType: () => _pickType(availableEventTypes(inWindow)),
                    onReset: _isDefaultView ? null : _resetFilters,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (visible.isEmpty)
                    _EmptyState(message: eventsEmptyMessage(_filter, today))
                  else
                    for (final event in visible) ...[
                      _EventCard(event: event, launcher: widget.launcher),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Date e luoghi possono cambiare: verifica sempre sul sito dell\'organizzatore.',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Esito di una scelta in un foglio di selezione: "tutti" oppure un valore.
/// Serve a distinguere "ho scelto Tutte" da "ho chiuso il foglio" (null).
class _Choice<T> {
  const _Choice.all()
      : isAll = true,
        value = null;
  const _Choice.value(T this.value) : isAll = false;

  final bool isAll;
  final T? value;
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.dateLabel,
    required this.regionLabel,
    required this.typeLabel,
    required this.regionActive,
    required this.typeActive,
    required this.datesActive,
    required this.onPickDates,
    required this.onPickRegion,
    required this.onPickType,
    required this.onReset,
  });

  final String dateLabel;
  final String regionLabel;
  final String typeLabel;
  final bool regionActive;
  final bool typeActive;
  final bool datesActive;
  final VoidCallback onPickDates;
  final VoidCallback onPickRegion;
  final VoidCallback onPickType;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterChip(icon: Icons.event_outlined, label: dateLabel, active: datesActive, onTap: onPickDates),
        _FilterChip(icon: Icons.place_outlined, label: regionLabel, active: regionActive, onTap: onPickRegion),
        _FilterChip(icon: Icons.category_outlined, label: typeLabel, active: typeActive, onTap: onPickType),
        if (onReset != null)
          TextButton(onPressed: onReset, child: const Text('Reimposta')),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? AppColors.onPrimary : AppColors.text;
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: active ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.launcher});

  final EventEntry event;
  final EventLinkLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final url = event.launchableUrl;
    final cancelled = event.status == EventStatus.cancelled;
    final postponed = event.status == EventStatus.postponed;
    final place = event.placeLabel;
    final showRegion = event.city != null && (event.region?.isNotEmpty ?? false);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        // Nessun link verificato: nessuna azione (e nessun effetto di tocco).
        onTap: url == null ? null : () => launcher(url),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eventDateRangeLabel(event.startsOn, event.endsOn),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (cancelled || postponed) _Pill(label: cancelled ? 'Annullato' : 'Rinviato', danger: true),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                event.title,
                style: AppTextStyles.title.copyWith(
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              if (place.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_rounded, size: 18, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: place,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            if (showRegion)
                              TextSpan(
                                text: ' · ${event.region}',
                                style: AppTextStyles.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (event.venueName != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(event.venueName!, style: AppTextStyles.bodySmall),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _Pill(label: eventTypeLabel(event.eventType)),
                        _Pill(label: event.level.label, emphasized: true),
                      ],
                    ),
                  ),
                  if (url != null)
                    const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.mutedText),
                ],
              ),
              if (event.organizerName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Organizzato da ${event.organizerName}', style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.emphasized = false, this.danger = false});

  final String label;
  final bool emphasized;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (danger) {
      background = AppColors.danger.withValues(alpha: 0.14);
      foreground = AppColors.danger;
    } else if (emphasized) {
      background = AppColors.accentSoft;
      foreground = AppColors.primaryStrong;
    } else {
      background = AppColors.background;
      foreground = AppColors.secondaryText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined, size: 40, color: AppColors.mutedText),
          const SizedBox(height: AppSpacing.md),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Non riesco a caricare gli eventi. Controlla la connessione e riprova.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        ),
      ),
    );
  }
}
