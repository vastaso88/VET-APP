import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../data/reminders_repository.dart';

enum _ViewState { empty, loading, error, success }

class RemindersListPage extends StatefulWidget {
  const RemindersListPage({super.key});

  @override
  State<RemindersListPage> createState() => _RemindersListPageState();
}

class _RemindersListPageState extends State<RemindersListPage> {
  final RemindersRepository _repository = RemindersRepository();

  late Future<List<ReminderEntry>> _remindersFuture;
  _ViewState _state = _ViewState.success;

  @override
  void initState() {
    super.initState();
    _remindersFuture = _repository.loadReminders();
  }

  Future<void> _reload() async {
    setState(() {
      _remindersFuture = _repository.loadReminders();
    });
    await _remindersFuture;
  }

  void _openCreate() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderCreatePage()),
      ).then((_) {
        if (mounted) {
          _reload();
        }
      }),
    );
  }

  void _openDetail(ReminderEntry reminder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderDetailPage(reminder: reminder),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: 'Promemoria',
      subtitle: 'Vaccini, trattamenti e visite da tenere sotto controllo.',
      actionLabel: 'Crea',
      onAction: _openCreate,
      state: _state,
      onStateChanged: (value) => setState(() => _state = value),
      child: switch (_state) {
        _ViewState.empty => _StatePanel(
            label: 'Nessun promemoria',
            title: 'La lista dei promemoria e vuota.',
            body: 'Crea il primo promemoria per vaccino o trattamento e resta in carreggiata.',
            icon: Icons.event_note_outlined,
            actionLabel: 'Crea promemoria',
            onAction: _openCreate,
          ),
        _ViewState.loading => const _LoadingPanel(
            title: 'Caricamento promemoria',
            body: 'Sto leggendo date, ricorrenze e note del proprietario.',
          ),
        _ViewState.error => _StatePanel(
            label: 'Errore sync',
            title: 'Sincronizzazione promemoria fallita.',
            body: 'La sorgente demo e ancora disponibile. Riprova quando la rete torna su.',
            icon: Icons.wifi_off_outlined,
            actionLabel: 'Riprova',
            onAction: () {},
          ),
        _ViewState.success => FutureBuilder<List<ReminderEntry>>(
            future: _remindersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingPanel(
                  title: 'Caricamento promemoria',
                  body: 'Sto leggendo date, ricorrenze e note del proprietario.',
                );
              }

              if (snapshot.hasError) {
                return _StatePanel(
                  label: 'Errore sync',
                  title: 'Sincronizzazione promemoria fallita.',
                  body: 'La sorgente demo e ancora disponibile. Riprova quando la rete torna su.',
                  icon: Icons.wifi_off_outlined,
                  actionLabel: 'Riprova',
                  onAction: () => unawaited(_reload()),
                );
              }

              final reminders = snapshot.data ?? const <ReminderEntry>[];
              if (reminders.isEmpty) {
                return _StatePanel(
                  label: 'Nessun promemoria',
                  title: 'La lista dei promemoria e vuota.',
                  body: 'Crea il primo promemoria per vaccino o trattamento e resta in carreggiata.',
                  icon: Icons.event_note_outlined,
                  actionLabel: 'Crea promemoria',
                  onAction: _openCreate,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SummaryCard(
                    title: '3 promemoria attivi',
                    body: 'Il prossimo scade tra 3 giorni e il controllo peso e gia fissato per domani.',
                    icon: Icons.schedule_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SummaryCard(
                    title: 'Prossima azione',
                    body: 'Apri il promemoria antiparassitario e avvisa Francesco con un tap.',
                    icon: Icons.notifications_active_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...reminders.asMap().entries.expand(
                    (entry) {
                      final index = entry.key;
                      final reminder = entry.value;
                      return <Widget>[
                        _ReminderTile(
                          title: reminder.title,
                          subtitle: reminder.subtitle,
                          due: reminder.due,
                          badge: reminder.badge,
                          onTap: () => _openDetail(reminder),
                        ),
                        if (index != reminders.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ];
                    },
                  ),
                ],
              );
            },
          ),
      },
    );
  }
}

class ReminderCreatePage extends StatefulWidget {
  const ReminderCreatePage({super.key});

  @override
  State<ReminderCreatePage> createState() => _ReminderCreatePageState();
}

class _ReminderCreatePageState extends State<ReminderCreatePage> {
  _ViewState _state = _ViewState.success;
  final RemindersRepository _repository = RemindersRepository();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: 'Crea promemoria',
      subtitle: 'Aggiungi una nuova scadenza, la ricorrenza e una nota.',
      actionLabel: 'Rivedi',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const ReminderDetailPage(
            reminder: ReminderEntry(
              id: 'promemoria-bozza-vaccino',
              title: 'Richiamo vaccinale di Moka',
              subtitle: 'Ogni 12 mesi',
              due: '25 Apr 2026',
              badge: 'Bozza',
              note: 'Porta il libretto sanitario e conferma la disponibilita con Francesco.',
              schedule: 'Ricorrente ogni 12 mesi',
            ),
          ),
        ),
      ),
      state: _state,
      onStateChanged: (value) => setState(() => _state = value),
      child: switch (_state) {
        _ViewState.empty => _StatePanel(
            label: 'Bozza',
            title: 'Parti da una bozza rapida.',
            body: 'Raccogliamo titolo, data, ricorrenza e una nota breve.',
            icon: Icons.edit_calendar_outlined,
            actionLabel: 'Continua',
            onAction: () {},
          ),
        _ViewState.loading => const _LoadingPanel(
            title: 'Preparazione form',
            body: 'Sto caricando le opzioni di ricorrenza e i valori predefiniti.',
          ),
        _ViewState.error => _StatePanel(
            label: 'Errore validazione',
            title: 'Mancano alcuni campi.',
            body: 'Compila titolo e scadenza prima di salvare il promemoria.',
            icon: Icons.rule_outlined,
            actionLabel: 'Correggi campi',
            onAction: () {},
          ),
        _ViewState.success => _FormPanel(
            title: 'Nuovo promemoria',
            body: 'Titolo, data e ricorrenza sono pronti per il salvataggio.',
            items: const [
              _FormItem(label: 'Titolo', value: 'Richiamo vaccinale di Moka'),
              _FormItem(label: 'Scadenza', value: '25 Apr 2026'),
              _FormItem(label: 'Ricorrenza', value: 'Ogni 12 mesi'),
              _FormItem(label: 'Nota', value: 'Porta il libretto sanitario'),
            ],
            onSave: () {
              unawaited(
                _repository.saveReminder(
                  const ReminderEntry(
                    id: 'promemoria-bozza-vaccino',
                    title: 'Richiamo vaccinale di Moka',
                    subtitle: 'Ogni 12 mesi',
                    due: '25 Apr 2026',
                    badge: 'Bozza',
                    note: 'Porta il libretto sanitario',
                    schedule: 'Ricorrente ogni 12 mesi',
                  ),
                ),
              );
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
      },
    );
  }
}

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key});

  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  _ViewState _state = _ViewState.success;
  final RemindersRepository _repository = RemindersRepository();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: 'Modifica promemoria',
      subtitle: 'Aggiorna ricorrenza, nota e scadenza.',
      actionLabel: 'Indietro',
      onAction: () => Navigator.of(context).pop(),
      state: _state,
      onStateChanged: (value) => setState(() => _state = value),
      child: switch (_state) {
        _ViewState.empty => _StatePanel(
            label: 'Modalita modifica',
            title: 'Nessun elemento selezionato.',
            body: 'Scegli un promemoria dalla lista per aggiornarne data o nota.',
            icon: Icons.tune_outlined,
            actionLabel: 'Indietro',
            onAction: () => Navigator.of(context).pop(),
          ),
        _ViewState.loading => const _LoadingPanel(
            title: 'Caricamento promemoria',
            body: 'Sto leggendo regole di ricorrenza, note locali e avvisi.',
          ),
        _ViewState.error => _StatePanel(
            label: 'Salvataggio fallito',
            title: 'L aggiornamento non e stato salvato.',
            body: 'Riprova dopo aver controllato data e ricorrenza.',
            icon: Icons.save_outlined,
            actionLabel: 'Riprova salvataggio',
            onAction: () {},
          ),
        _ViewState.success => _FormPanel(
            title: 'Modifica promemoria',
            body: 'Tutti i campi sono gia compilati e pronti per il salvataggio.',
            items: const [
              _FormItem(label: 'Titolo', value: 'Antiparassitario di Moka'),
              _FormItem(label: 'Scadenza', value: '28 Mar 2026'),
              _FormItem(label: 'Ricorrenza', value: 'Ogni 30 giorni'),
              _FormItem(label: 'Avviso', value: 'Notifica push'),
            ],
            onSave: () {
              unawaited(
                _repository.saveReminder(
                  const ReminderEntry(
                    id: 'moka-antiparassitario',
                    title: 'Antiparassitario di Moka',
                    subtitle: 'Ogni 30 giorni',
                    due: '28 Mar 2026',
                    badge: 'Prioritario',
                    note: 'Notifica push attiva',
                    schedule: 'Ricorrente ogni 30 giorni',
                  ),
                ),
              );
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
      },
    );
  }
}

class ReminderDetailPage extends StatefulWidget {
  const ReminderDetailPage({super.key, this.reminder});

  final ReminderEntry? reminder;

  @override
  State<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends State<ReminderDetailPage> {
  _ViewState _state = _ViewState.success;

  @override
  Widget build(BuildContext context) {
    final reminder = widget.reminder;

    return _Shell(
      title: 'Dettaglio promemoria',
      subtitle: 'Data, ricorrenza e nota del promemoria.',
      actionLabel: 'Modifica',
      onAction: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReminderEditPage()),
      ),
      state: _state,
      onStateChanged: (value) => setState(() => _state = value),
      child: switch (_state) {
        _ViewState.empty => _StatePanel(
            label: 'Nessun promemoria',
            title: 'Nessun elemento da ispezionare.',
            body: 'Apri un promemoria dalla lista oppure crea una bozza nuova.',
            icon: Icons.event_available_outlined,
            actionLabel: 'Torna alla lista',
            onAction: () => Navigator.of(context).pop(),
          ),
        _ViewState.loading => const _LoadingPanel(
            title: 'Caricamento promemoria',
            body: 'Sto leggendo ricorrenza, scadenza e note.',
          ),
        _ViewState.error => _StatePanel(
            label: 'Errore anteprima',
            title: 'Anteprima del promemoria non disponibile.',
            body: 'Riprova oppure torna alla lista per aprire un altro elemento.',
            icon: Icons.broken_image_outlined,
            actionLabel: 'Riprova',
            onAction: () {},
          ),
        _ViewState.success => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCard(
                title: reminder?.title ?? 'Antiparassitario di Moka',
                body: reminder?.note ?? 'Promemoria ricorrente collegato al profilo attivo di Moka.',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              _FormPanel(
                title: 'Riepilogo promemoria',
                body: 'La vista dettaglio mantiene tutti i valori chiave in un solo posto.',
                items: [
                  _FormItem(label: 'Titolo', value: reminder?.title ?? 'Antiparassitario di Moka'),
                  _FormItem(label: 'Scadenza', value: reminder?.due ?? '28 Mar 2026'),
                  _FormItem(label: 'Ricorrenza', value: reminder?.schedule ?? 'Ricorrente ogni 30 giorni'),
                  _FormItem(label: 'Stato', value: reminder?.badge ?? 'Prioritario'),
                ],
                onSave: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ReminderEditPage()),
                ),
                onCancel: () => Navigator.of(context).pop(),
              ),
            ],
          ),
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.state,
    required this.onStateChanged,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final _ViewState state;
  final ValueChanged<_ViewState> onStateChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8FBF8),
              Color(0xFFF4F7EE),
              Color(0xFFEAF0DC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl,
              AppSpacing.lg,
              AppSpacing.xxl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(title: title, subtitle: subtitle, actionLabel: actionLabel, onAction: onAction),
                const SizedBox(height: AppSpacing.lg),
                _StateChips(value: state, onChanged: onStateChanged),
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandPill(),
              const SizedBox(height: AppSpacing.lg),
              Text(title, style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: Size.zero),
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text(
            'VET APP',
            style: TextStyle(color: AppColors.onPrimary, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StateChips extends StatelessWidget {
  const _StateChips({
    required this.value,
    required this.onChanged,
  });

  final _ViewState value;
  final ValueChanged<_ViewState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _StateChip(label: 'Vuoto', selected: value == _ViewState.empty, onTap: () => onChanged(_ViewState.empty)),
        _StateChip(label: 'Caricamento', selected: value == _ViewState.loading, onTap: () => onChanged(_ViewState.loading)),
        _StateChip(label: 'Errore', selected: value == _ViewState.error, onTap: () => onChanged(_ViewState.error)),
        _StateChip(label: 'OK', selected: value == _ViewState.success, onTap: () => onChanged(_ViewState.success)),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: label,
      title: title,
      body: body,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Card(
      label: 'Caricamento',
      title: title,
      body: body,
      icon: Icons.hourglass_empty_outlined,
      actionLabel: 'Attendi',
      onAction: null,
      loading: true,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.loading = false,
  });

  final String label;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AccentPill(label: label),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          if (loading) ...[
            const _Skeleton(width: double.infinity),
            const SizedBox(height: AppSpacing.sm),
            const _Skeleton(width: 180),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF315E55),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.subtitle,
    required this.due,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String due;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.title.copyWith(fontSize: 17)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(due, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _Badge(label: badge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8B5B3E),
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.body,
    required this.items,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final String body;
  final List<_FormItem> items;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _InputLike(label: item.label, value: item.value),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: onSave, child: const Text('Salva')),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: OutlinedButton(onPressed: onCancel, child: const Text('Annulla'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormItem {
  const _FormItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _InputLike extends StatelessWidget {
  const _InputLike({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
        ],
      ),
    );
  }
}
