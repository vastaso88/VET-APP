import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/data/chat_demo_store.dart';
import '../../../chat/domain/chat_models.dart';
import '../../../chat/presentation/pages/chat_conversation_detail_page.dart';
import '../../../chat/presentation/widgets/chat_conversation_card.dart';
import '../../../medical_records/data/medical_records_repository.dart';
import '../../../medical_records/presentation/pages/medical_records_pages.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';
import 'pet_edit_page.dart';

class PetDetailPage extends StatefulWidget {
  const PetDetailPage({
    super.key,
    this.pet,
    this.state = PetsScreenStatus.success,
    this.errorMessage = 'Questo profilo pet non e disponibile al momento.',
  });

  final PetProfile? pet;
  final PetsScreenStatus state;
  final String errorMessage;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  PetProfile? _pet;
  final MedicalRecordsRepository _recordsRepository = MedicalRecordsRepository();
  final RemindersRepository _remindersRepository = RemindersRepository();

  @override
  void initState() {
    super.initState();
    _pet = widget.pet ?? PetDemoStore.instance.list().firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet ?? widget.pet ?? PetDemoStore.instance.list().firstOrNull;

    return PetsScaffold(
      title: pet?.name ?? 'Dettaglio pet',
      subtitle: pet == null ? null : pet.species,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        IconButton(
          onPressed: pet == null ? null : () => _openEdit(context, pet),
          icon: const Icon(Icons.edit_outlined),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: AppColors.primaryStrong),
        ),
      ],
      body: switch (widget.state) {
        PetsScreenStatus.loading =>
          const PetsLoadingView(label: 'Carico il dettaglio pet...'),
        PetsScreenStatus.error => PetsErrorView(
            title: 'Dettaglio pet non disponibile',
            subtitle: widget.errorMessage,
            actionLabel: 'Torna alla lista',
            onRetry: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.empty => PetsEmptyView(
            title: 'Nessun pet selezionato',
            subtitle: 'Scegli un profilo dalla lista per vedere dettagli, chat e cartella clinica.',
            actionLabel: 'Torna alla lista',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.success => _PetDetailContent(
            pet: pet ?? PetDemoStore.instance.list().first,
            recordsRepository: _recordsRepository,
            remindersRepository: _remindersRepository,
            onEdit: pet == null ? null : () => _openEdit(context, pet),
          ),
      },
    );
  }

  Future<void> _openEdit(BuildContext context, PetProfile pet) async {
    final updated = await Navigator.of(context).push<PetProfile>(
      MaterialPageRoute<PetProfile>(builder: (_) => PetEditPage(pet: pet)),
    );

    if (!mounted) return;
    if (updated != null) {
      setState(() => _pet = updated);
    }
  }
}

class _PetDetailContent extends StatelessWidget {
  const _PetDetailContent({
    required this.pet,
    required this.recordsRepository,
    required this.remindersRepository,
    required this.onEdit,
  });

  final PetProfile pet;
  final MedicalRecordsRepository recordsRepository;
  final RemindersRepository remindersRepository;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCard(pet: pet, onEdit: onEdit),
          const SizedBox(height: AppSpacing.xxl),
          _RemindersSection(pet: pet, repository: remindersRepository),
          const SizedBox(height: AppSpacing.xxl),
          _ChatSection(pet: pet),
          const SizedBox(height: AppSpacing.xxl),
          _RecordsSection(pet: pet, repository: recordsRepository),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.pet, required this.onEdit});

  final PetProfile pet;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pet.accentColor.withValues(alpha: 0.55), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PetAvatar(label: pet.avatarEmoji, backgroundColor: pet.accentColor, size: 72),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: AppTextStyles.display.copyWith(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(pet.title, style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        pet.healthBadge,
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryStrong),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(pet.medicalNote, style: AppTextStyles.body.copyWith(color: AppColors.text)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.event_available_outlined, size: 18, color: AppColors.primaryStrong),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  pet.nextVisitLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifica'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.heading.copyWith(fontSize: 19))),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ChatSection extends StatefulWidget {
  const _ChatSection({required this.pet});

  final PetProfile pet;

  @override
  State<_ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<_ChatSection> {
  final ChatDemoStore _store = ChatDemoStore.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final conversations = _store.conversations
            .where((c) => c.activePetName == widget.pet.name)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: 'Chat',
              actionLabel: 'Nuova',
              onAction: () => _startConversation(context),
            ),
            const SizedBox(height: AppSpacing.md),
            if (conversations.isEmpty)
              _InlineEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                text: 'Nessuna conversazione ancora per ${widget.pet.name}.',
              )
            else
              ...conversations.map(
                (conversation) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ChatConversationCard(
                    conversation: conversation,
                    onTap: () => _openConversation(context, conversation),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openConversation(BuildContext context, ChatConversationSummary conversation) {
    final detail = _store.conversationById(conversation.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationDetailPage(
          conversationId: conversation.id,
          initialConversation: detail,
        ),
      ),
    );
  }

  void _startConversation(BuildContext context) {
    final conversation = _store.startConversation(
      petName: widget.pet.name,
      seedPrompt: 'Ciao, ho una domanda su ${widget.pet.name}.',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatConversationDetailPage(
          conversationId: conversation.id,
          initialConversation: conversation,
        ),
      ),
    );
  }
}

class _RemindersSection extends StatefulWidget {
  const _RemindersSection({required this.pet, required this.repository});

  final PetProfile pet;
  final RemindersRepository repository;

  @override
  State<_RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends State<_RemindersSection> {
  late Future<List<ReminderEntry>> _remindersFuture = widget.repository.loadReminders();

  Future<void> _reload() async {
    setState(() {
      _remindersFuture = widget.repository.loadReminders();
    });
    await _remindersFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Promemoria',
          actionLabel: 'Nuovo',
          onAction: () => _openCreate(context),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<ReminderEntry>>(
          future: _remindersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final reminders = (snapshot.data ?? const <ReminderEntry>[])
                .where((reminder) => reminder.petName == widget.pet.name)
                .toList(growable: false);

            if (reminders.isEmpty) {
              return _InlineEmptyState(
                icon: Icons.notifications_none_rounded,
                text: 'Nessun promemoria ancora per ${widget.pet.name}.',
              );
            }

            return Column(
              children: reminders
                  .map(
                    (reminder) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ReminderRow(
                        reminder: reminder,
                        onTap: () => _openDetail(context, reminder),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderCreatePage(petName: widget.pet.name),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openDetail(BuildContext context, ReminderEntry reminder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderDetailPage(reminder: reminder),
      ),
    );
    if (!mounted) return;
    await _reload();
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder, required this.onTap});

  final ReminderEntry reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(reminder.due, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordsSection extends StatefulWidget {
  const _RecordsSection({required this.pet, required this.repository});

  final PetProfile pet;
  final MedicalRecordsRepository repository;

  @override
  State<_RecordsSection> createState() => _RecordsSectionState();
}

class _RecordsSectionState extends State<_RecordsSection> {
  late Future<List<MedicalRecordEntry>> _recordsFuture = widget.repository.loadRecords();

  Future<void> _reload() async {
    setState(() {
      _recordsFuture = widget.repository.loadRecords();
    });
    await _recordsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Cartella clinica',
          actionLabel: 'Carica',
          onAction: () => _openUpload(context),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<MedicalRecordEntry>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final records = (snapshot.data ?? const <MedicalRecordEntry>[])
                .where((record) => record.petName == widget.pet.name)
                .toList(growable: false);

            if (records.isEmpty) {
              return _InlineEmptyState(
                icon: Icons.folder_open_outlined,
                text: 'Nessun documento ancora per ${widget.pet.name}.',
              );
            }

            return Column(
              children: records
                  .map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RecordTile(
                        record: record,
                        onTap: () => _openDetail(context, record),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openUpload(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MedicalRecordsUploadPage()),
    );
    if (!mounted) return;
    await _reload();
  }

  void _openDetail(BuildContext context, MedicalRecordEntry record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicalRecordDetailPage(record: record),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final MedicalRecordEntry record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(record.meta, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mutedText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
