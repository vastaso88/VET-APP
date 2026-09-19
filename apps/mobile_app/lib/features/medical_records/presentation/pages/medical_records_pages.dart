import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../data/medical_records_repository.dart';

class MedicalRecordsListPage extends StatefulWidget {
  const MedicalRecordsListPage({super.key});

  @override
  State<MedicalRecordsListPage> createState() => _MedicalRecordsListPageState();
}

class _MedicalRecordsListPageState extends State<MedicalRecordsListPage> {
  final MedicalRecordsRepository _repository = MedicalRecordsRepository();

  late Future<List<MedicalRecordEntry>> _recordsFuture;
  String? _selectedPetName;

  @override
  void initState() {
    super.initState();
    _recordsFuture = _repository.loadRecords();
  }

  Future<void> _reload() async {
    setState(() {
      _recordsFuture = _repository.loadRecords();
    });
    await _recordsFuture;
  }

  void _openUpload() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const MedicalRecordsUploadPage()),
      ).then((_) {
        if (mounted) {
          _reload();
        }
      }),
    );
  }

  void _openDetail(MedicalRecordEntry record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicalRecordDetailPage(record: record),
      ),
    );
  }

  void _selectPet(String? petName) {
    setState(() {
      _selectedPetName = petName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: 'Cartella clinica',
      subtitle: 'Referti, note e allegati di Moka in un archivio chiaro.',
      actionLabel: 'Carica',
      onAction: _openUpload,
      child: FutureBuilder<List<MedicalRecordEntry>>(
            future: _recordsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingState(
                  title: 'Sincronizzazione referti',
                  body: 'Sto recuperando documenti e metadati da Supabase o dalla sorgente demo.',
                );
              }

              if (snapshot.hasError) {
                return _EmptyState(
                  title: 'Impossibile caricare l archivio',
                  body: 'Riprova dopo aver controllato la connessione o continua con il fallback demo.',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: 'Riprova',
                  onAction: () => unawaited(_reload()),
                );
              }

              final records = snapshot.data ?? const <MedicalRecordEntry>[];
              final petNames = records
                  .map((record) => record.petName)
                  .toSet()
                  .toList()
                ..sort();
              final selectedPetName = petNames.contains(_selectedPetName)
                  ? _selectedPetName
                  : null;
              final filteredRecords = selectedPetName == null
                  ? records
                  : records
                      .where((record) => record.petName == selectedPetName)
                      .toList(growable: false);

              if (records.isEmpty) {
                return _EmptyState(
                  title: 'Nessun documento ancora',
                  body: 'Carica il primo referto per costruire la cartella clinica.',
                  icon: Icons.folder_open_outlined,
                  actionLabel: 'Carica il primo file',
                  onAction: _openUpload,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PetFilterBar(
                    petNames: petNames,
                    selectedPetName: selectedPetName,
                    onChanged: _selectPet,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryCard(
                    title: selectedPetName == null
                        ? '${records.length} documenti attivi'
                        : '${filteredRecords.length} documenti di $selectedPetName',
                    body: selectedPetName == null
                        ? '1 referto pronto da condividere, 1 esame da rivedere e 1 nota archiviata.'
                        : 'Filtri attivi sul profilo di $selectedPetName. Apri i documenti piu utili senza rumore.',
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryCard(
                    title: 'Prossima azione',
                    body: selectedPetName == null
                        ? 'Apri il referto vaccinale di Moka e condividilo con Francesco.'
                        : 'Condividi il documento piu recente di $selectedPetName e conserva la nota nel profilo.',
                    icon: Icons.verified_outlined,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ...filteredRecords.asMap().entries.expand(
                    (entry) {
                      final index = entry.key;
                      final record = entry.value;
                      return <Widget>[
                        _RecordTile(
                          petName: record.petName,
                          title: record.title,
                          subtitle: record.subtitle,
                          meta: record.meta,
                          badge: record.badge,
                          onTap: () => _openDetail(record),
                        ),
                        if (index != filteredRecords.length - 1)
                          const SizedBox(height: AppSpacing.sm),
                      ];
                    },
                  ),
                  if (filteredRecords.isEmpty)
                    _EmptyState(
                      title: selectedPetName == null
                          ? 'Nessun documento ancora'
                          : 'Nessun documento per $selectedPetName',
                      body: selectedPetName == null
                          ? 'Carica il primo referto per costruire la cartella clinica.'
                          : 'Cambia filtro oppure carica un nuovo documento per questo pet.',
                      icon: Icons.folder_open_outlined,
                      actionLabel: selectedPetName == null
                          ? 'Carica il primo file'
                          : 'Rimuovi filtro',
                      onAction: selectedPetName == null
                          ? _openUpload
                          : () => _selectPet(null),
                    ),
                ],
              );
            },
          ),
    );
  }
}

class MedicalRecordsUploadPage extends StatefulWidget {
  const MedicalRecordsUploadPage({super.key});

  @override
  State<MedicalRecordsUploadPage> createState() =>
      _MedicalRecordsUploadPageState();
}

class _MedicalRecordsUploadPageState extends State<MedicalRecordsUploadPage> {
  final MedicalRecordsRepository _repository = MedicalRecordsRepository();
  final MedicalRecordEntry _draftRecord = const MedicalRecordEntry(
    id: 'moka-richiamo-vaccinale-draft',
    petName: 'Moka',
    title: 'richiamo_vaccinale_moka.pdf',
    subtitle: 'Caricato con successo e pronto per la revisione dei metadati.',
    meta: 'Caricato con successo',
    badge: 'Verificato',
    detailSource: 'Clinica Vet Roma',
    createdAt: '25 Mar 2026, 09:32',
    timeline: [
      MedicalRecordTimelineEntry(label: 'Importato', value: '25 Mar 2026'),
      MedicalRecordTimelineEntry(label: 'Revisionato', value: '25 Mar 2026, 09:45'),
      MedicalRecordTimelineEntry(label: "Pronto per l'invio", value: 'Disponibile'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: 'Carica documento',
      subtitle: 'Carica PDF, JPG o PNG e completa i metadati.',
      actionLabel: 'Dettaglio',
      onAction: () {
        unawaited(_repository.saveRecord(_draftRecord));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => MedicalRecordDetailPage(record: _draftRecord),
          ),
        );
      },
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(
            title: 'richiamo_vaccinale_moka.pdf',
            body: 'Caricato con successo e pronto per la revisione dei metadati.',
            icon: Icons.check_circle_outline,
          ),
          SizedBox(height: AppSpacing.lg),
          _MetaGrid(
            items: [
              _MetaItem('Tipo', 'Vaccinazione'),
              _MetaItem('Data', '25 Mar 2026'),
              _MetaItem('Fonte', 'Clinica Vet Roma'),
              _MetaItem('Formato', 'PDF'),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _Checklist(),
        ],
      ),
    );
  }
}

class MedicalRecordDetailPage extends StatefulWidget {
  const MedicalRecordDetailPage({super.key, this.record});

  final MedicalRecordEntry? record;

  @override
  State<MedicalRecordDetailPage> createState() => _MedicalRecordDetailPageState();
}

class _MedicalRecordDetailPageState extends State<MedicalRecordDetailPage> {
  @override
  Widget build(BuildContext context) {
    return _FeatureScaffold(
      title: 'Dettaglio metadati',
      subtitle: 'Fonte, formato, data e prossima nota operativa.',
      actionLabel: 'Indietro',
      onAction: () => Navigator.of(context).pop(),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SummaryCard(
                title: widget.record?.title ?? 'richiamo_vaccinale_moka.pdf',
                body: widget.record?.detailSource ??
                    'Documento clinico collegato al profilo attivo di ${widget.record?.petName ?? 'Moka'}.',
                icon: Icons.verified_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SummaryCard(
                title: 'Prossima azione',
                body: 'Condividi il referto con Francesco e conserva la nota nel profilo di Moka.',
                icon: Icons.send_outlined,
              ),
              const SizedBox(height: AppSpacing.lg),
              _MetaGrid(
                items: [
                  _MetaItem('Pet', widget.record?.petName ?? 'Moka'),
                  _MetaItem('Clinica', widget.record?.detailSource ?? 'Clinica Vet Roma'),
                  _MetaItem('Creato', widget.record?.createdAt ?? '25 Mar 2026, 09:32'),
                  const _MetaItem('Pagine', '2'),
                  const _MetaItem('Tag', 'Vaccini, controllo annuale'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _TimelineCard(timeline: widget.record?.timeline),
            ],
          ),
    );
  }
}

class _FeatureScaffold extends StatelessWidget {
  const _FeatureScaffold({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
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
              Color(0xFFF0F6F3),
              Color(0xFFE0EEE7),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 760;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(
                      title: title,
                      subtitle: subtitle,
                      actionLabel: actionLabel,
                      onAction: onAction,
                      compact: isCompact,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    child,
                  ],
                );
              },
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
    required this.compact,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackRow(),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BackRow(),
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
          Icon(Icons.medical_services_outlined, size: 14, color: AppColors.accent),
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

class _BackRow extends StatelessWidget {
  const _BackRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: const Color(0xFF163A35)),
        ),
        const SizedBox(width: AppSpacing.sm),
        const _BrandPill(),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      accentLabel: 'Stato anteprima',
      title: title,
      body: body,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _LoadingCard(title: title, body: body);
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.accentLabel,
    required this.title,
    required this.body,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
  });

  final String accentLabel;
  final String title;
  final String body;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onAction;

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
          _AccentPill(label: accentLabel),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

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
          const _AccentPill(label: 'Caricamento'),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: AppTextStyles.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          const _Skeleton(width: double.infinity),
          const SizedBox(height: AppSpacing.sm),
          const _Skeleton(width: double.infinity),
          const SizedBox(height: AppSpacing.sm),
          const _Skeleton(width: 180),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(title, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    Text(body, style: AppTextStyles.bodySmall),
                  ],
                )
              : Row(
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
      },
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.petName,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.badge,
    required this.onTap,
  });

  final String petName;
  final String title;
  final String subtitle;
  final String meta;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppColors.primary),
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
                        Text(meta, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _PetBadge(label: petName),
                  _Badge(label: badge),
                ],
              ),
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

class _PetBadge extends StatelessWidget {
  const _PetBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF315E55),
        ),
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.items});

  final List<_MetaItem> items;

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
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: items
            .map(
              (item) => SizedBox(
                width: 148,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label, style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    Text(item.value, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MetaItem {
  const _MetaItem(this.label, this.value);

  final String label;
  final String value;
}

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LineItem(text: 'Formato file supportato'),
        _LineItem(text: 'Metadati estratti'),
        _LineItem(text: 'Collegato al pet attivo'),
      ],
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF2D6B60)),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({this.timeline});

  final List<MedicalRecordTimelineEntry>? timeline;

  @override
  Widget build(BuildContext context) {
    final rows = timeline ??
        const [
          MedicalRecordTimelineEntry(label: 'Importato', value: '25 Mar 2026'),
          MedicalRecordTimelineEntry(label: 'Revisionato', value: '25 Mar 2026, 09:45'),
          MedicalRecordTimelineEntry(label: "Pronto per l'invio", value: 'Disponibile'),
        ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cronologia documento', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.lg),
          ...rows.map(
            (row) => _TimelineRow(label: row.label, value: row.value),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }
}

class _PetFilterBar extends StatelessWidget {
  const _PetFilterBar({
    required this.petNames,
    required this.selectedPetName,
    required this.onChanged,
  });

  final List<String> petNames;
  final String? selectedPetName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (petNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            label: Text('Tutti (${petNames.length})'),
            selected: selectedPetName == null,
            onSelected: (_) => onChanged(null),
            labelStyle: TextStyle(
              color: selectedPetName == null ? AppColors.onPrimary : AppColors.secondaryText,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          ...petNames.map(
            (petName) => ChoiceChip(
              label: Text(petName),
              selected: selectedPetName == petName,
              onSelected: (_) => onChanged(petName),
              labelStyle: TextStyle(
                color: selectedPetName == petName ? AppColors.onPrimary : AppColors.secondaryText,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
