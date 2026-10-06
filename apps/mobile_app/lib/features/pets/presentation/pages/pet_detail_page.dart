import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:share_plus/share_plus.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../shared/files/attachment_media_type.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/data/chat_attachment_remote_data_source.dart';
import '../../../chat/data/chat_demo_store.dart';
import '../../../chat/domain/chat_models.dart';
import '../../../chat/presentation/pages/chat_conversation_detail_page.dart';
import '../../../dog_walks/data/active_walk_controller.dart';
import '../../../dog_walks/data/dog_walks_repository.dart';
import '../../../dog_walks/data/walk_history_controller.dart';
import '../../../dog_walks/domain/walk_eligibility.dart';
import '../../../dog_walks/domain/walk_retention.dart';
import '../../../dog_walks/domain/walk_route_markers.dart';
import '../../../dog_walks/domain/walk_route_segments.dart';
import '../../../dog_walks/domain/walk_session.dart';
import '../../../dog_walks/presentation/pages/active_walk_page.dart';
import '../../../dog_walks/presentation/pages/walk_detail_page.dart';
import '../../../dog_walks/presentation/walk_labels.dart';
import '../../../dog_walks/presentation/widgets/badge_gallery_dialog.dart';
import '../../../dog_walks/presentation/widgets/walk_map_style.dart';
import '../../../dog_walks/presentation/widgets/walk_route_markers_layer.dart';
import '../../../medical_records/data/medical_record_file_cache.dart';
import '../../../medical_records/data/medical_records_repository.dart';
import '../../../medical_records/presentation/pages/medical_record_upload_page.dart';
import '../../../medical_records/presentation/record_file_actions.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/domain/reminder_presentation.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../data/pet_demo_store.dart';
import '../../domain/pet_models.dart';
import '../widgets/medical_record_consent_card.dart';
import '../../../chat/presentation/widgets/chat_conversation_menu.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import '../widgets/pets_state_views.dart';
import 'pet_edit_page.dart';
import 'pet_gallery_page.dart';

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
  final MedicalRecordsRepository _recordsRepository =
      MedicalRecordsRepository();
  final RemindersRepository _remindersRepository = RemindersRepository();
  final DogWalksRepository _walksRepository = DogWalksRepository();

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
      badge: pet == null
          ? null
          : PetAvatar(
              label: pet.avatarEmoji,
              backgroundColor: pet.accentColor,
              photoBytes: pet.photoBytes,
              photoPath: pet.photoPath,
              identityColor: pet.identityColor,
              size: 36,
            ),
      actions: [
        IconButton(
          tooltip: 'Galleria foto',
          onPressed: pet == null
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PetGalleryPage(pet: pet),
                    ),
                  ),
          icon: const Icon(Icons.photo_library_outlined),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: AppColors.primaryStrong),
        ),
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
            subtitle:
                'Scegli un profilo dalla lista per vedere dettagli, chat e referti.',
            actionLabel: 'Torna alla lista',
            onAction: () => Navigator.of(context).maybePop(),
          ),
        PetsScreenStatus.success => _PetDetailContent(
            pet: pet ?? PetDemoStore.instance.list().first,
            recordsRepository: _recordsRepository,
            remindersRepository: _remindersRepository,
            walksRepository: _walksRepository,
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
    required this.walksRepository,
  });

  final PetProfile pet;
  final MedicalRecordsRepository recordsRepository;
  final RemindersRepository remindersRepository;
  final DogWalksRepository walksRepository;

  @override
  State<_PetDetailContent> createState() => _PetDetailContentState();
}

class _PetDetailContentState extends State<_PetDetailContent>
    with SingleTickerProviderStateMixin {
  /// "Passeggiate" is offered for dogs only (owner request, 2026-10-03) -
  /// for any other species the tab (and so the start button, badges and
  /// history) simply isn't there. A non-dog that still has historic walks
  /// stored just never loads them.
  bool get _showsWalks => isDogSpecies(widget.pet.species);

  late TabController _tabController =
      TabController(length: _showsWalks ? 4 : 3, vsync: this);

  @override
  void didUpdateWidget(covariant _PetDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Editing the species while this page is open can add/remove the tab;
    // a TabController's length is fixed, so it has to be rebuilt.
    final expectedLength = _showsWalks ? 4 : 3;
    if (_tabController.length != expectedLength) {
      final previousIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: expectedLength,
        vsync: this,
        initialIndex: previousIndex < expectedLength ? previousIndex : 0,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final habitat = widget.pet.habitat;
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: PetDemoStore.changes,
          builder: (context, _, __) => PetDemoStore.instance.isUnsynced(widget.pet.id)
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _UnsyncedPetBanner(petId: widget.pet.id),
                )
              : const SizedBox.shrink(),
        ),
        if (habitat != null && !habitat.isEmpty) ...[
          _HabitatSummaryRow(pet: widget.pet, habitat: habitat),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (widget.pet.isAquarium) ...[
          _AquariumStockCard(stock: widget.pet.aquariumStock),
          const SizedBox(height: AppSpacing.md),
        ],
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.mutedText,
          indicatorColor: AppColors.primary,
          labelStyle:
              AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: AppTextStyles.bodySmall,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            const Tab(text: 'Promemoria'),
            const Tab(text: 'Chat'),
            const Tab(text: 'Referti'),
            if (_showsWalks) const Tab(text: 'Passeggiate'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RemindersTab(
                  pet: widget.pet, repository: widget.remindersRepository),
              _ChatTab(pet: widget.pet),
              _RecordsTab(
                  pet: widget.pet, repository: widget.recordsRepository),
              if (_showsWalks)
                _WalksTab(pet: widget.pet, repository: widget.walksRepository),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shared "sure you want to delete this?" prompt — reused by the
/// Promemoria, Chat and Referti tabs so the confirmation reads the same
/// everywhere.
Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large)),
      title: Text(title),
      content: Text(message),
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

String _habitatLabel(String species) => switch (species) {
      'Pesce' => 'Acquario',
      'Rettili e anfibi' => 'Terrario',
      'Uccello' => 'Voliera',
      _ => 'Habitat',
    };

/// A single-line summary, tap to see the full habitat details — kept to
/// one line so it doesn't eat into the space the tabs below need.
class _HabitatSummaryRow extends StatelessWidget {
  const _HabitatSummaryRow({required this.pet, required this.habitat});

  final PetProfile pet;
  final HabitatDetails habitat;

  String _summary() {
    final parts = <String>[
      if (habitat.hasDimensions) habitat.dimensionsLabel,
      if (habitat.volumeLiters != null) '${habitat.volumeLiters} L',
      if (habitat.temperatureLabel.isNotEmpty) habitat.temperatureLabel,
    ];
    return parts.isEmpty ? 'Tocca per i dettagli' : parts.join(' · ');
  }

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
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
              Text(_habitatLabel(pet.species), style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              if (habitat.hasDimensions)
                _HabitatDetailRow('Dimensioni', habitat.dimensionsLabel),
              if (habitat.volumeLiters != null)
                _HabitatDetailRow('Volume', '${habitat.volumeLiters} litri'),
              if (habitat.temperatureLabel.isNotEmpty)
                _HabitatDetailRow('Temperatura', habitat.temperatureLabel),
              if (habitat.substrate.isNotEmpty)
                _HabitatDetailRow('Substrato', habitat.substrate),
              if (habitat.notes.isNotEmpty)
                _HabitatDetailRow('Attrezzatura', habitat.notes),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: () => _openDetails(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${_habitatLabel(pet.species)} · ${_summary()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.text, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitatDetailRow extends StatelessWidget {
  const _HabitatDetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Text(value,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.text)),
        ],
      ),
    );
  }
}

class _AquariumStockCard extends StatelessWidget {
  const _AquariumStockCard({required this.stock});

  final List<FishStock> stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Popolazione', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          // Capped so a big population can't push the tabs below off
          // screen — scrolls internally instead once there are more than
          // ~3 species.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 108),
            child: ListView.separated(
              shrinkWrap: true,
              physics: stock.length > 3
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: stock.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = stock[index];
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.species,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.text, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '× ${item.count}',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
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
  Future<void> _reload() async {
    // The list already rebuilds on its own via RemindersRepository.changes
    // (see the ValueListenableBuilder in build()) — kept for the explicit
    // reload-after-navigation-return calls below.
    await widget.repository.loadReminders();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => ReminderCreatePage(petName: widget.pet.name)),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _openDetail(ReminderEntry reminder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => ReminderDetailPage(reminder: reminder)),
    );
    if (!mounted) return;
    await _reload();
  }

  Future<void> _deleteReminder(ReminderEntry reminder) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Eliminare questo promemoria?',
      message: '"${reminder.title}" verrà eliminato definitivamente.',
    );
    if (!confirmed) return;

    try {
      await widget.repository.deleteReminder(reminder.id);
    } on ReminderSyncException catch (error) {
      if (mounted) showReminderFailure(error.message);
      return;
    }
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
          child: ValueListenableBuilder<int>(
            valueListenable: RemindersRepository.changes,
            builder: (context, _, __) => FutureBuilder<List<ReminderEntry>>(
              future: widget.repository.loadReminders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: PetLoader());
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
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) => _ReminderRow(
                    reminder: reminders[index],
                    onTap: () => _openDetail(reminders[index]),
                    onDelete: () => _deleteReminder(reminders[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow(
      {required this.reminder, required this.onTap, required this.onDelete});

  final ReminderEntry reminder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final presentation = ReminderPresentation.of(reminder);
    return _CompactRow(
      onTap: onTap,
      onDelete: onDelete,
      leading: _RowIcon(icon: presentation.icon),
      title: reminder.title,
      subtitle: presentation.kindLabel,
      trailingText: presentation.dateLabel,
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
  void initState() {
    super.initState();
    // Restores the owner's stored conversations from the backend (no-op
    // once loaded, or without a backend).
    _store.ensureHydrated();
  }

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
                      text:
                          'Nessuna conversazione ancora per ${widget.pet.name}.',
                    )
                  : ListView.separated(
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, index) {
                        final conversation = conversations[index];
                        return Dismissible(
                          key: ValueKey(conversation.id),
                          direction: DismissDirection.endToStart,
                          background: const _DeleteSwipeBackground(),
                          confirmDismiss: (_) =>
                              _confirmDeleteChat(context, conversation),
                          onDismissed: (_) =>
                              _deleteConversation(conversation.id),
                          child: _ChatRow(
                            conversation: conversation,
                            onTap: () =>
                                _openConversation(context, conversation),
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
          SnackBar(
              content: Text(
                  'Chat rimossa qui, ma non sul server: ${error.message}')),
        );
      },
    );
  }

  Future<bool> _confirmDeleteChat(
      BuildContext context, ChatConversationSummary conversation) {
    return _confirmDelete(
      context,
      title: 'Eliminare questa chat?',
      message: '"${conversation.title}" verrà eliminata definitivamente.',
    );
  }

  void _openConversation(
      BuildContext context, ChatConversationSummary conversation) {
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

    final conversation = _store.startConversation(petName: widget.pet.name);
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large)),
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
  const _ChatRow(
      {required this.conversation,
      required this.onTap,
      });

  final ChatConversationSummary conversation;
  final VoidCallback onTap;


  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      onTap: onTap,
      trailingAction: ChatConversationMenuButton(
        conversationId: conversation.id,
        title: conversation.title,
        petName: conversation.activePetName,
      ),
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
// Referti tab
// ---------------------------------------------------------------------------

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({required this.pet, required this.repository});

  final PetProfile pet;
  final MedicalRecordsRepository repository;

  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  late Future<List<MedicalRecordEntry>> _future =
      widget.repository.loadRecords();

  @override
  void initState() {
    super.initState();
    MedicalRecordsRepository.changes.addListener(_onRecordsChanged);
  }

  @override
  void dispose() {
    MedicalRecordsRepository.changes.removeListener(_onRecordsChanged);
    super.dispose();
  }

  void _onRecordsChanged() {
    if (!mounted) return;
    setState(() => _future = widget.repository.loadRecords());
  }

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

  /// Records picked for a group share. A non-empty set means selection mode:
  /// taps toggle instead of opening the actions sheet.
  final Set<String> _selectedIds = {};

  void _onRecordTap(MedicalRecordEntry record) {
    if (_selectedIds.isNotEmpty) {
      _toggleSelected(record);
      return;
    }
    showRecordActions(context, record: record, onChanged: () => unawaited(_reload()));
  }

  void _toggleSelected(MedicalRecordEntry record) {
    setState(() {
      if (!_selectedIds.remove(record.id)) _selectedIds.add(record.id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _deleteRecord(MedicalRecordEntry record) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Eliminare questo documento?',
      message: '"${record.title}" verrà eliminato definitivamente.',
    );
    if (!confirmed) return;

    try {
      await widget.repository.deleteRecord(record.id);
    } on MedicalRecordSaveException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    await _reload();
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
                if (record != records.last)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareRecord(MedicalRecordEntry record) async {
    try {
      var cached = MedicalRecordFileCache.instance.get(record.id);
      if (cached == null && record.attachmentId != null) {
        // Not in this session's cache (e.g. app was reopened) but a real
        // upload exists remotely — fetch it instead of falling back to a
        // text summary.
        final result = await HttpChatAttachmentRemoteDataSource()
            .download(record.attachmentId!);
        final bytes =
            result.fold(onSuccess: (bytes) => bytes, onFailure: (_) => null);
        if (bytes != null) {
          cached = (
            bytes: bytes,
            fileName: record.title,
            mimeType: attachmentMediaType(bytes, record.title).toString(),
          );
        }
      }

      if (cached != null) {
        await Share.shareXFiles(
          [
            XFile.fromData(cached.bytes,
                name: cached.fileName, mimeType: cached.mimeType)
          ],
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
        const SnackBar(
            content:
                Text('Condivisione non disponibile su questo dispositivo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedicalRecordEntry>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PetLoader());
        }
        if (snapshot.hasError) {
          return _RecordsLoadError(onRetry: () => unawaited(_reload()));
        }

        final records = (snapshot.data ?? const <MedicalRecordEntry>[])
            .where((record) => record.petName == widget.pet.name)
            .toList(growable: false);

        // One scrollable list: the consent card, the actions and the records
        // scroll together, so nothing can overflow a fixed-height tab body.
        return ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            MedicalRecordConsentCard(pet: widget.pet),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openUpload,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Carica file'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: records.isEmpty ? null : () => _openSendSheet(records),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Invia'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_selectedIds.isNotEmpty) ...[
              _SelectionBar(
                count: _selectedIds.length,
                onCancel: _clearSelection,
                onSend: () => shareRecords(
                  context,
                  records.where((r) => _selectedIds.contains(r.id)).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (records.isEmpty)
              _EmptyTabState(
                icon: Icons.folder_open_outlined,
                text: 'Nessun documento ancora per ${widget.pet.name}.',
              )
            else
              for (final record in records) ...[
                _RecordRow(
                  record: record,
                  selected: _selectedIds.contains(record.id),
                  onTap: () => _onRecordTap(record),
                  onLongPress: () => _toggleSelected(record),
                  onDelete: () => _deleteRecord(record),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    required this.selected,
  });

  final MedicalRecordEntry record;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return _CompactRow(
      onTap: onTap,
      onLongPress: onLongPress,
      onDelete: onDelete,
      selected: selected,
      leading: _RowIcon(
        icon: selected
            ? Icons.check_circle_rounded
            : isPdfFileName(record.title)
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
      ),
      title: record.title,
      subtitle: record.subtitle,
    );
  }
}

// ---------------------------------------------------------------------------
// Passeggiate tab
// ---------------------------------------------------------------------------

class _WalksTab extends StatefulWidget {
  const _WalksTab({required this.pet, required this.repository});

  final PetProfile pet;
  final DogWalksRepository repository;

  @override
  State<_WalksTab> createState() => _WalksTabState();
}

class _WalksTabState extends State<_WalksTab> {
  // History, records, favorites and recents all hang off this controller: it
  // reloads on any change (walk just finished, favorite toggled, a walk
  // deleted) without ever blanking the list, and applies star/trash taps
  // optimistically (owner reports, 2026-10-03 and 2026-10-05).
  late final WalkHistoryController _history = WalkHistoryController(
    petId: widget.pet.id,
    repository: widget.repository,
  )..refresh();

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  /// Pushes the live/paused/fresh-start page - ActiveWalkPage itself already
  /// knows whether to resume the singleton's in-progress walk or start a
  /// new one, so this is the only navigation this tab needs regardless of
  /// which button triggered it (owner request, 2026-09-30: "Avvia
  /// passeggiata" no longer shows at all once a walk is active for this
  /// pet, so there's nothing left for a separate "already active" branch
  /// here to guard against).
  Future<void> _openWalkPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => ActiveWalkPage(pet: widget.pet)),
    );
    if (!mounted) return;
    unawaited(_history.refresh());
  }

  Future<void> _showBadges() async {
    await _history.settled;
    if (!mounted) return;
    await showBadgeGalleryDialog(context,
        petId: widget.pet.id, walksForPet: _history.walks ?? const <WalkSession>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: ActiveWalkController.instance,
          builder: (context, _) {
            final controller = ActiveWalkController.instance;
            final activeForThisPet =
                controller.isActive && controller.walk?.petId == widget.pet.id;
            // While active for this pet, the button IS the live status - no
            // separate "Avvia" alongside it (owner request, 2026-09-30):
            // tapping it always opens the page, never the Fine/Pausa sheet
            // (that moved to the shell banner - walk_control_sheet.dart).
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openWalkPage,
                icon: Icon(
                  activeForThisPet && controller.walk!.isPaused
                      ? Icons.pause_circle_filled_rounded
                      : Icons.directions_walk_rounded,
                  size: 18,
                ),
                label: activeForThisPet
                    ? _WalkStatusLabel(walk: controller.walk!)
                    : const Text('Avvia passeggiata'),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showBadges,
            icon: const Icon(Icons.emoji_events_outlined, size: 18),
            label: const Text('Badge'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: AnimatedBuilder(
            animation: _history,
            builder: (context, _) {
              // Only the very first load shows the loader; later reloads
              // keep the walks on screen until the new ones arrive.
              final walks = _history.walks;
              if (walks == null) {
                return const Center(child: PetLoader());
              }
              if (walks.isEmpty) {
                return _EmptyTabState(
                  icon: Icons.directions_walk_outlined,
                  text: 'Nessuna passeggiata ancora per ${widget.pet.name}.',
                );
              }

              final history = buildWalkHistoryView(walks);
              return ListView(
                children: [
                  if (history.longestDistance != null || history.longestDuration != null) ...[
                    const _WalksSectionLabel('Record 🏆'),
                    if (history.longestDistance != null)
                      _WalkCard(
                        walk: history.longestDistance!,
                        petName: widget.pet.name,
                        history: _history,
                        recordLabel: history.longestDuration?.id == history.longestDistance!.id
                            ? 'Più lunga · Più duratura'
                            : 'Più lunga',
                      ),
                    if (history.longestDuration != null &&
                        history.longestDuration!.id != history.longestDistance?.id) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _WalkCard(
                        walk: history.longestDuration!,
                        petName: widget.pet.name,
                        history: _history,
                        recordLabel: 'Più duratura',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (history.favorites.isNotEmpty) ...[
                    const _WalksSectionLabel('Preferite ⭐'),
                    for (final walk in history.favorites) ...[
                      _WalkCard(
                          walk: walk,
                          petName: widget.pet.name,
                          history: _history),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (history.recent.isNotEmpty) ...[
                    const _WalksSectionLabel('Recenti'),
                    for (final walk in history.recent) ...[
                      _WalkCard(
                          walk: walk,
                          petName: widget.pet.name,
                          history: _history),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// Deleted the inline "always-visible earned badges" row here (owner
// request, 2026-09-30: badges should only be visible on demand, via the
// "Badge" button's gallery - see badge_gallery_dialog.dart).

/// The status button's content next to the walk-tracking button: live
/// "Passeggiata in corso · distanza · mm:ss" or "In pausa · ..." while
/// paused. Owns its own ticker (rather than relying on the parent's
/// AnimatedBuilder, which only fires on an accepted GPS point) so the time
/// actually counts up once a second, and stops ticking while paused since
/// walkActiveDurationSeconds freezes anyway (owner request, 2026-09-30).
class _WalkStatusLabel extends StatefulWidget {
  const _WalkStatusLabel({required this.walk});

  final WalkSession walk;

  @override
  State<_WalkStatusLabel> createState() => _WalkStatusLabelState();
}

class _WalkStatusLabelState extends State<_WalkStatusLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _WalkStatusLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.walk.isPaused) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeSeconds = walkActiveDurationSeconds(widget.walk);
    final prefix = widget.walk.isPaused ? 'In pausa' : 'Passeggiata in corso';
    return Text(
      '$prefix · ${walkDistanceLabel(widget.walk.distanceMeters)} · ${walkElapsedLabel(activeSeconds)}',
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Bumped up from AppTextStyles.caption (owner report, 2026-09-30: section
/// titles were too small to notice) - body-sized and bold instead. No
/// explicit appScaleOf multiplication here: unlike icon/avatar sizes, text
/// is already scaled once for screen width by the ambient TextScaler set
/// up in app.dart's MaterialApp.builder - multiplying the fontSize by
/// appScaleOf too would scale it a second time.
class _WalksSectionLabel extends StatelessWidget {
  const _WalksSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// A retained walk (record / favorite / recent - see walk_retention.dart),
/// shown with its map so "in evidenza" actually means something visual, not
/// just a number. Walks pruned outside retention have an empty route and
/// never reach this widget (buildWalkHistoryView only surfaces retained
/// ones).
class _WalkCard extends StatelessWidget {
  const _WalkCard({
    required this.walk,
    required this.petName,
    required this.history,
    this.recordLabel,
  });

  final WalkSession walk;
  final String petName;

  /// Star and trash go through it: the card changes at once, the write
  /// follows behind and is undone with a message if it is refused.
  final WalkHistoryController history;

  /// "Più lunga" / "Più duratura" / both, when this card is shown under the
  /// Record section (owner request, 2026-09-30: distance and duration are
  /// tracked as separate records, possibly the same walk or two different
  /// ones - walk_retention.dart). Null everywhere else.
  final String? recordLabel;

  Future<void> _toggleFavorite(BuildContext context) async {
    if (walk.isFavorite) {
      // Un-starring can hand the walk back to the "outside retention" pool,
      // where it may lose its route on the next prune if it's no longer the
      // record or among the last 3 (walk_retention.dart) - the owner should
      // know that before it happens (owner request, 2026-09-30).
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Togliere dai preferiti?'),
          content: const Text(
            'Se non è anche il record o tra le ultime 3 passeggiate, potrà perdere la mappa '
            'alla prossima pulizia automatica.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Togli dai preferiti'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await history.setFavorite(walk, !walk.isFavorite);
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare questa passeggiata?'),
        content: Text(
          'La passeggiata del ${walkDateLabel(walk.startedAt)} '
          '(${walkDistanceLabel(walk.distanceMeters)}) verrà eliminata definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await history.delete(walk);
  }

  Future<void> _openDetail(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalkDetailPage(walk: walk, petName: petName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      walkDistanceLabel(walk.distanceMeters),
      if (walk.durationSeconds != null) walkDurationLabel(walk.durationSeconds),
      if (walk.stepCountEstimate != null) '~${walk.stepCountEstimate} passi',
    ];
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: walk.route.isEmpty
                  ? const _WalkMissingRoutePlaceholder()
                  : _WalkMiniMap(route: walk.route),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recordLabel != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentSoft,
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                            ),
                            child: Text(
                              recordLabel!,
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.primaryStrong, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          walkDateLabel(walk.startedAt),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitleParts.join(' · '), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleFavorite(context),
                    icon: Icon(
                      walk.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: walk.isFavorite ? AppColors.warning : AppColors.mutedText,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.mutedText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Static (no pan/zoom) preview of one walk's route - the history cards
/// only need a glance, not an interactive map.
class _WalkMiniMap extends StatelessWidget {
  const _WalkMiniMap({required this.route});

  final List<RoutePoint> route;

  @override
  Widget build(BuildContext context) {
    final points = route
        .map((point) => latlong.LatLng(
            point.coordinates.latitude, point.coordinates.longitude))
        .toList();
    final bounds = LatLngBounds.fromPoints(points);
    final segments = splitRouteIntoSegments(route);

    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
              bounds: bounds, padding: const EdgeInsets.all(24)),
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          buildWalkTileLayer(),
          PolylineLayer(
            polylines: [
              for (final segment in segments)
                if (segment.length >= 2)
                  Polyline(
                    points: segment
                        .map((point) =>
                            latlong.LatLng(point.coordinates.latitude, point.coordinates.longitude))
                        .toList(),
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
            ],
          ),
          buildWalkRouteMarkersLayer(computeWalkRouteMarkers(route, isFinished: true)),
        ],
      ),
    );
  }
}

/// Shown instead of _WalkMiniMap for a walk whose route is empty - either
/// pruned by retention (walk_retention.dart, expected) or saved by a
/// release from before GPS tracking existed (owner report, 2026-09-30: a
/// blank thumbnail with no explanation looked like a bug either way).
class _WalkMissingRoutePlaceholder extends StatelessWidget {
  const _WalkMissingRoutePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.mutedText, size: 28),
          const SizedBox(height: 4),
          Text('Percorso non disponibile', style: AppTextStyles.caption),
        ],
      ),
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
    this.onLongPress,
    this.onDelete,
    this.trailingText,
    this.trailingAction,
    this.badgeCount = 0,
    this.selected = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final VoidCallback? onDelete;
  final String? trailingText;
  final Widget? trailingAction;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
              if (trailingAction != null) ...[
                const SizedBox(width: 2),
                trailingAction!,
              ] else ...[
              if (onDelete != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.danger),
                  tooltip: 'Elimina',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
              ],
              if (onTap != null && trailingAction == null) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.mutedText),
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
            Text(text,
                textAlign: TextAlign.center, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Shown while a pet change is only on this device. "Riprova" tries the
/// server again; the pet keeps its local data either way.
class _UnsyncedPetBanner extends StatefulWidget {
  const _UnsyncedPetBanner({required this.petId});

  final String petId;

  @override
  State<_UnsyncedPetBanner> createState() => _UnsyncedPetBannerState();
}

class _UnsyncedPetBannerState extends State<_UnsyncedPetBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final ok = await PetDemoStore.instance.retrySync(widget.petId);
    if (!mounted) return;
    setState(() => _retrying = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ancora nessun collegamento al server. Riprova più tardi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Non sincronizzato: le modifiche sono solo su questo telefono.',
              style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _retrying
              ? const PetLoader.small()
              : TextButton(onPressed: _retry, child: const Text('Riprova')),
        ],
      ),
    );
  }
}

/// Shown while records are selected for a group share.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onCancel, required this.onSend});

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count selezionat${count == 1 ? 'o' : 'i'}',
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Annulla')),
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Invia'),
          ),
        ],
      ),
    );
  }
}

class _RecordsLoadError extends StatelessWidget {
  const _RecordsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Non riesco a leggere i referti. Controlla la connessione e riprova.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
    );
  }
}
