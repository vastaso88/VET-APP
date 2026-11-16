import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../dog_walks/data/dog_walks_repository.dart';
import '../../../dog_walks/domain/walk_session.dart';
import '../../../dog_walks/presentation/pages/walk_detail_page.dart';
import '../../../dog_walks/presentation/walk_labels.dart';
import '../../../medical_records/data/medical_records_repository.dart';
import '../../../medical_records/presentation/pet_medical_records_tab.dart';
import '../../../notifications/domain/memory_notifications.dart';
import '../../application/memorial_service.dart';
import '../../data/memorial_moments.dart';
import '../../data/pet_demo_store.dart';
import '../../data/pet_photo_repository.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../../domain/pet_value_labels.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import 'memorial_move_page.dart';
import 'pet_data_page.dart';
import 'pet_gallery_page.dart';

/// One pet in Ricordi (docs/product/17_ricordi_animali.md §6): its photo and
/// dates, "moved by mistake? bring back", photos, favourite walks, the memory
/// reminders, documents and — alone at the bottom — delete forever. Everything
/// is read only: the gallery, profile and records pages open without editing
/// (owner's request after build 39). [focus] is the memory notification that
/// opened the page, shown first.
class PetMemorialPage extends StatefulWidget {
  const PetMemorialPage({
    super.key,
    required this.pet,
    this.focus,
    this.service,
    this.loadMoments = MemorialMoments.load,
    this.today,
  });

  final PetProfile pet;
  final MemoryTap? focus;
  final MemorialService? service;
  final Future<MemorialMoments> Function(String petId) loadMoments;
  final DateTime? today;

  @override
  State<PetMemorialPage> createState() => _PetMemorialPageState();
}

class _PetMemorialPageState extends State<PetMemorialPage> {
  late PetProfile _pet = widget.pet;
  late Future<MemorialMoments> _moments = widget.loadMoments(widget.pet.id);
  bool _busy = false;

  MemorialService get _service => widget.service ?? MemorialService();

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    PetDemoStore.changes.addListener(_refreshPet);
    if (widget.focus?.kind == 'walk') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_openFocusedWalk()),
      );
    }
  }

  @override
  void dispose() {
    PetDemoStore.changes.removeListener(_refreshPet);
    super.dispose();
  }

  void _refreshPet() {
    final fresh = PetDemoStore.instance.byId(_pet.id);
    if (!mounted || fresh == null) return;
    setState(() => _pet = fresh);
  }

  String _dateLine(BuildContext context) {
    final birth = localizedBirthDateLabel(_pet.birthDateLabel);
    final loss = _pet.memorialDate;
    if (loss == null) return birth;
    final formatted = formatAppDate(loss, 'd MMM y');
    return birth.isEmpty
        ? context.l10n.petsMemoriesWithUsUntil(formatted)
        : context.l10n.petsMemoriesWithUsRange(birth, formatted);
  }

  Future<void> _changeLossDate() async {
    final birth = parsePetBirthDateLabel(_pet.birthDateLabel);
    final first = birth != null && birth.isBefore(_today) ? birth : DateTime(1990);
    final current = _pet.memorialDate ?? _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(_today) ? _today : current,
      firstDate: first,
      lastDate: _today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null || !mounted) return;
    await _save(
      () => PetDemoStore.instance.upsert(_pet.copyWith(memorialDate: picked)),
    );
  }

  Future<void> _save(Future<PetProfile> Function() write) async {
    setState(() => _busy = true);
    try {
      final saved = await write();
      if (mounted) setState(() => _pet = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.memorialSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      title: l10n.memorialRestoreTitle(_pet.name),
      body: l10n.memorialRestoreBody(_pet.name),
      confirm: l10n.memorialRestoreConfirm,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final restored = await _service.restore(_pet);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.memorialRestoreDone(restored.name))),
      );
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.memorialSaveFailed)));
    }
  }

  Future<void> _deleteForever() async {
    final l10n = context.l10n;
    final confirmed = await _confirm(
      title: l10n.petsMemoriesRemoveTitle(_pet.name),
      body: l10n.petsMemoriesRemoveBody(_pet.name),
      confirm: l10n.petsMemoriesRemoveConfirm,
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await PetDemoStore.instance.delete(_pet.id);
      navigator.pop();
    } on PetSyncException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirm,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirm),
          ),
        ],
      ),
    );
  }

  Future<void> _openWalk(WalkSession summary) async {
    final ownerId = CurrentUser.get()?.id;
    var walk = summary;
    // The summary has no route: the map needs the full walk.
    if (ownerId != null) {
      try {
        final full = await DogWalksRepository().loadWalks(ownerId);
        walk = full.firstWhere(
          (item) => item.id == summary.id,
          orElse: () => summary,
        );
      } catch (_) {}
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalkDetailPage(walk: walk, petName: _pet.name),
      ),
    );
  }

  Future<void> _openFocusedWalk() async {
    final walkId = widget.focus?.walkId;
    if (walkId == null) return;
    final moments = await _moments;
    final walk = moments.walks.where((item) => item.id == walkId).firstOrNull;
    if (walk != null && mounted) await _openWalk(walk);
  }

  void _open(Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) {
      if (!mounted) return;
      // Block body: an arrow returning the Future would make setState throw.
      setState(() {
        _moments = widget.loadMoments(_pet.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PetsScaffold(
      title: _pet.name,
      onBack: () => Navigator.of(context).maybePop(),
      badge: const Icon(
        Icons.auto_awesome_outlined,
        color: AppColors.mutedText,
      ),
      body: FutureBuilder<MemorialMoments>(
        future: _moments,
        builder: (context, snapshot) {
          final moments = snapshot.data ?? const MemorialMoments();
          final loading = snapshot.connectionState != ConnectionState.done;
          return ListView(
            children: [
              _Header(
                pet: _pet,
                dateLine: _dateLine(context),
                onChangeDate: _busy ? null : _changeLossDate,
              ),
              // Easy to find, so a move made by mistake (or out of curiosity)
              // is undone without hunting for it.
              Center(
                child: TextButton.icon(
                  key: const ValueKey('memorial-restore'),
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text(
                    l10n.memorialRestoreShortcut(_sexKey(_pet)),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (widget.focus != null && !loading) ...[
                const SizedBox(height: AppSpacing.lg),
                _FocusSection(
                  focus: widget.focus!,
                  moments: moments,
                  today: _today,
                  onOpenWalk: _openWalk,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(l10n.memorialPagePhotos),
              _PhotoStrip(
                photos: [
                  for (final photo in moments.photos)
                    if (!photo.isVideo) photo,
                ].take(12).toList(),
                loading: loading,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _open(PetGalleryPage(pet: _pet)),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(l10n.memorialPageOpenGallery),
                ),
              ),
              if (moments.favouriteWalks.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionTitle(l10n.memorialPageWalks),
                Text(
                  l10n.memorialPageWalksTogether(
                    moments.walks.length,
                    walkDistanceLabel(moments.totalDistanceMeters),
                  ),
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final walk in moments.favouriteWalks)
                  _WalkRow(walk: walk, onTap: () => _openWalk(walk)),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(l10n.memorialPageReminders),
              MemorialReminderSwitches(
                canBirthday: parsePetBirthdayLabel(_pet.birthDateLabel) != null,
                canWalks: moments.favouriteWalks.isNotEmpty || _pet.memorialWalksReminder,
                canPhotos: moments.datedPhotos.isNotEmpty || _pet.memorialPhotosReminder,
                birthday: _pet.memorialBirthdayReminder,
                walks: _pet.memorialWalksReminder,
                photos: _pet.memorialPhotosReminder,
                onChanged:
                    _busy ? null : (choices) => _save(() => _service.updateChoices(_pet, choices)),
              ),
              const SizedBox(height: AppSpacing.lg),
              _LinkRow(
                icon: Icons.folder_outlined,
                label: l10n.memorialPageRecords,
                onTap: () => _open(_MemorialRecordsPage(pet: _pet)),
              ),
              _LinkRow(
                icon: Icons.badge_outlined,
                label: l10n.memorialPageProfile,
                onTap: () => _open(PetDataPage(petId: _pet.id, initialPet: _pet)),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.memorialReadOnlyNote(_pet.name),
                style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
              ),
              if ((_pet.microchipNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _ChipNote(pet: _pet),
              ],
              const SizedBox(height: AppSpacing.xxl),
              const Divider(color: AppColors.border),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('memorial-delete'),
                  onPressed: _busy ? null : _deleteForever,
                  child: Text(
                    l10n.petsMemoriesRemoveAction,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pet,
    required this.dateLine,
    required this.onChangeDate,
  });

  final PetProfile pet;
  final String dateLine;
  final VoidCallback? onChangeDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PetAvatar(
          label: pet.avatarEmoji,
          backgroundColor: pet.accentColor,
          photoBytes: pet.photoBytes,
          photoPath: pet.photoPath,
          identityColor: pet.identityColor,
          size: 112,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${pet.speciesDisplayLabel} · ${pet.breedLabel}',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall,
        ),
        // The date of the loss can be corrected here (a tap on the line).
        TextButton.icon(
          key: const ValueKey('memorial-change-date'),
          onPressed: onChangeDate,
          icon: const Icon(
            Icons.edit_calendar_outlined,
            size: 16,
            color: AppColors.mutedText,
          ),
          label: Text(
            dateLine,
            style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
          ),
        ),
      ],
    );
  }
}

/// What the tapped memory notification was about, shown first.
class _FocusSection extends StatelessWidget {
  const _FocusSection({
    required this.focus,
    required this.moments,
    required this.today,
    required this.onOpenWalk,
  });

  final MemoryTap focus;
  final MemorialMoments moments;
  final DateTime today;
  final ValueChanged<WalkSession> onOpenWalk;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photos = [
      for (final photo in moments.photos)
        if (!photo.isVideo) photo,
    ];
    switch (focus.kind) {
      case 'walk':
        final walk = moments.walks.where((item) => item.id == focus.walkId).firstOrNull;
        if (walk == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.memorialPageWalkPhotos),
            _PhotoStrip(photos: photosDuringWalk(photos, walk), loading: false),
            TextButton.icon(
              onPressed: () => onOpenWalk(walk),
              icon: const Icon(Icons.route_outlined, size: 18),
              label: Text(l10n.memorialPageOpenWalk),
            ),
          ],
        );
      case 'photos':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.memorialPageOnThisDay),
            _PhotoStrip(photos: photosOnThisDay(photos, today), loading: false),
          ],
        );
      default:
        final birthdayPhotos = photosAroundAnniversary(photos, today);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.memorialPageBirthdayPhotos),
            if (birthdayPhotos.isEmpty)
              Text(
                l10n.memorialPageNoBirthdayPhotos,
                style: AppTextStyles.bodySmall,
              )
            else
              _PhotoStrip(photos: birthdayPhotos, loading: false),
          ],
        );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: AppTextStyles.title.copyWith(fontSize: 17)),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.loading});

  final List<PetPhotoEntry> photos;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return loading
          ? const SizedBox(height: 88)
          : Text(
              context.l10n.memorialPageNoPhotos,
              style: AppTextStyles.bodySmall,
            );
    }
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => _Thumb(photo: photos[index]),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.photo});

  final PetPhotoEntry photo;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<Uint8List?> _bytes = PetPhotoRepository().loadThumbnail(
    widget.photo.storagePath,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.medium),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PetPhotoViewerPage(storagePath: widget.photo.storagePath),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: SizedBox.square(
          dimension: 88,
          child: FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return bytes == null
                  ? const ColoredBox(color: AppColors.secondarySoft)
                  : Image.memory(bytes, fit: BoxFit.cover);
            },
          ),
        ),
      ),
    );
  }
}

class _WalkRow extends StatelessWidget {
  const _WalkRow({required this.walk, required this.onTap});

  final WalkSession walk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = formatAppDate(walk.startedAt.toLocal(), 'd MMM y');
    final distance = walkDistanceLabel(walk.distanceMeters);
    return _LinkRow(icon: Icons.star_outline_rounded, label: '$day · $distance', onTap: onTap);
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.secondaryText),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
          ],
        ),
      ),
    );
  }
}

/// Only with a microchip; no terms, forms, fines or links, and the app does
/// not record whether the death was reported (MARKETING e NORMATIVA,
/// compliance doc 17 §B.5).
class _ChipNote extends StatelessWidget {
  const _ChipNote({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    final sex = _sexKey(pet);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.memorialPageChipNote(pet.name, sex),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The clinical records of a pet in Ricordi: read, sent and exported as PDF,
/// never changed (PetMedicalRecordsTab reads `pet.isMemorial`).
class _MemorialRecordsPage extends StatelessWidget {
  const _MemorialRecordsPage({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    return PetsScaffold(
      title: context.l10n.memorialPageRecords,
      subtitle: pet.name,
      onBack: () => Navigator.of(context).maybePop(),
      body: PetMedicalRecordsTab(
        pet: pet,
        repository: MedicalRecordsRepository(),
      ),
    );
  }
}

/// The pet's sex as the ICU `select` keys of the Ricordi texts.
String _sexKey(PetProfile pet) => switch (pet.sex) {
      'Maschio' => 'male',
      'Femmina' => 'female',
      _ => 'other',
    };
