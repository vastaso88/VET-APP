import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/data/chat_demo_store.dart';
import '../../../chat/domain/chat_models.dart';
import '../../../chat/presentation/pages/chat_conversation_detail_page.dart';
import '../../../medical_records/data/medical_record_file_cache.dart';
import '../../../medical_records/data/medical_records_repository.dart';
import '../../../medical_records/presentation/pages/medical_record_upload_page.dart';
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

class _PetDetailContent extends StatefulWidget {
  const _PetDetailContent({
    required this.pet,
    required this.recordsRepository,
    required this.remindersRepository,
  });

  final PetProfile pet;
  final MedicalRecordsRepository recordsRepository;
  final RemindersRepository remindersRepository;

  @override
  State<_PetDetailContent> createState() => _PetDetailContentState();
}

class _PetDetailContentState extends State<_PetDetailContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CompactHero(pet: widget.pet),
        const SizedBox(height: AppSpacing.lg),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTextStyles.bodySmall,
          tabs: const [
            Tab(text: 'Promemoria'),
            Tab(text: 'Chat'),
            Tab(text: 'Cartella clinica'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RemindersTab(pet: widget.pet, repository: widget.remindersRepository),
              _ChatTab(pet: widget.pet),
              _RecordsTab(pet: widget.pet, repository: widget.recordsRepository),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHero extends StatelessWidget {
  const _CompactHero({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pet.accentColor.withValues(alpha: 0.55), AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetAvatar(label: pet.avatarEmoji, backgroundColor: pet.accentColor, size: 52),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        pet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.title.copyWith(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
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
                const SizedBox(height: 2),
                Text(pet.title, style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.event_available_outlined, size: 13, color: AppColors.primaryStrong),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        pet.nextVisitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Promemoria tab
// ---------------------------------------------------------------------------

class _RemindersTab extends StatefulWidget {
  const _RemindersTab({required this.pet, required this.repository});

  final PetProfile pet;
  final RemindersRepository repository;

  @override
  State<_RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<_RemindersTab> {
  late Future<List<ReminderEntry>> _future = widget.repository.loadReminders();

  Future<void> _reload() async {
    setState(() => _future = widget.repository.loadReminders());
    await _future;
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReminderCreatePage(petName: widget.pet.name)),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openDetail(ReminderEntry reminder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReminderDetailPage(reminder: reminder)),
    );
    if (!mounted) return;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nuovo promemoria'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: FutureBuilder<List<ReminderEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              final reminders = (snapshot.data ?? const <ReminderEntry>[])
                  .where((reminder) => reminder.petName == widget.pet.name)
                  .toList(growable: false);

              if (reminders.isEmpty) {
                return _EmptyTabState(
                  icon: Icons.notifications_none_rounded,
                  text: 'Nessun promemoria ancora per ${widget.pet.name}.',
                );
              }

              return ListView.separated(
                itemCount: reminders.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) => _ReminderRow(
                  reminder: reminders[index],
                  onTap: () => _openDetail(reminders[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.reminder, required this.onTap});

  final ReminderEntry reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      onTap: onTap,
      leading: const _RowIcon(icon: Icons.notifications_none_rounded),
      title: reminder.title,
      subtitle: reminder.due,
    );
  }
}

// ---------------------------------------------------------------------------
// Chat tab
// ---------------------------------------------------------------------------

class _ChatTab extends StatefulWidget {
  const _ChatTab({required this.pet});

  final PetProfile pet;

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
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
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _startConversation(context),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('Nuova chat'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: conversations.isEmpty
                  ? _EmptyTabState(
                      icon: Icons.chat_bubble_outline_rounded,
                      text: 'Nessuna conversazione ancora per ${widget.pet.name}.',
                    )
                  : ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        final conversation = conversations[index];
                        return Dismissible(
                          key: ValueKey(conversation.id),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteSwipeBackground(),
                          confirmDismiss: (_) => _confirmDelete(context, conversation),
                          onDismissed: (_) => _deleteConversation(conversation.id),
                          child: _ChatRow(
                            conversation: conversation,
                            onTap: () => _openConversation(context, conversation),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteConversation(String id) async {
    final result = await _store.deleteConversation(id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat rimossa qui, ma non sul server: ${error.message}')),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, ChatConversationSummary conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: const Text('Eliminare questa chat?'),
        content: Text('"${conversation.title}" verrà eliminata definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
    if (!_store.canStartConversation(widget.pet.name)) {
      _showLimitDialog(context);
      return;
    }

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

  void _showLimitDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.large)),
        title: const Text('Limite chat raggiunto'),
        content: Text(
          'Puoi avere al massimo ${ChatDemoStore.maxConversationsPerPet} conversazioni attive per '
          '${widget.pet.name}. Elimina una chat esistente per aprirne una nuova.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Ho capito'),
          ),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.conversation, required this.onTap});

  final ChatConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      onTap: onTap,
      leading: const _RowIcon(icon: Icons.chat_bubble_outline_rounded),
      title: conversation.title,
      subtitle: conversation.previewMessage,
      trailingText: conversation.updatedAtLabel,
      badgeCount: conversation.unreadCount,
    );
  }
}

class _DeleteSwipeBackground extends StatelessWidget {
  const _DeleteSwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartella clinica tab
// ---------------------------------------------------------------------------

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({required this.pet, required this.repository});

  final PetProfile pet;
  final MedicalRecordsRepository repository;

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  late Future<List<MedicalRecordEntry>> _future = widget.repository.loadRecords();

  Future<void> _reload() async {
    setState(() => _future = widget.repository.loadRecords());
    await _future;
  }

  Future<void> _openUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute<MedicalRecordEntry>(
        builder: (_) => MedicalRecordUploadPage(petName: widget.pet.name),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  void _openDetail(MedicalRecordEntry record) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => MedicalRecordDetailPage(record: record)),
    );
  }

  Future<void> _openSendSheet(List<MedicalRecordEntry> records) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invia file', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Scegli un documento da inviare via email, WhatsApp e altro.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final record in records) ...[
                _CompactRow(
                  leading: const _RowIcon(icon: Icons.description_outlined),
                  title: record.title,
                  subtitle: record.subtitle,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareRecord(record);
                  },
                ),
                if (record != records.last) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareRecord(MedicalRecordEntry record) async {
    try {
      final cached = MedicalRecordFileCache.instance.get(record.id);
      if (cached != null) {
        await Share.shareXFiles(
          [XFile.fromData(cached.bytes, name: cached.fileName, mimeType: cached.mimeType)],
          text: record.title,
        );
      } else {
        // No real bytes behind this demo record (it's seed data, not
        // something uploaded this session) — share a text summary instead
        // of pretending there's a file attached.
        await Share.share(
          '📄 ${record.title}\n${record.detailSource} · ${record.createdAt}\n\nCondiviso da VetApp',
        );
      }
    } catch (_) {
      // The share sheet isn't available on every browser/device (e.g. no
      // Web Share API support) — fail quietly with a clear message rather
      // than letting the exception surface as a broken interaction.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Condivisione non disponibile su questo dispositivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedicalRecordEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final records = (snapshot.data ?? const <MedicalRecordEntry>[])
            .where((record) => record.petName == widget.pet.name)
            .toList(growable: false);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openUpload,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Carica nuovo file'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: records.isEmpty ? null : () => _openSendSheet(records),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Invia file'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: records.isEmpty
                  ? _EmptyTabState(
                      icon: Icons.folder_open_outlined,
                      text: 'Nessun documento ancora per ${widget.pet.name}.',
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) => _RecordRow(
                        record: records[index],
                        onTap: () => _openDetail(records[index]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.onTap});

  final MedicalRecordEntry record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      onTap: onTap,
      leading: const _RowIcon(icon: Icons.description_outlined),
      title: record.title,
      subtitle: record.subtitle,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared compact primitives
// ---------------------------------------------------------------------------

class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Icon(icon, size: 17, color: AppColors.primary),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailingText,
    this.badgeCount = 0,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? trailingText;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (trailingText != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(trailingText!, style: AppTextStyles.caption),
              ],
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mutedText),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.mutedText),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
