import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../billing/data/billing_demo_store.dart';
import '../../application/memorial_service.dart';
import '../../data/pet_demo_store.dart';
import '../../data/memorial_moments.dart';
import '../../domain/pet_format.dart';
import '../../domain/pet_models.dart';
import '../memorial_restore_message.dart';
import '../widgets/pet_avatar.dart';
import '../widgets/pets_scaffold.dart';
import '../../../../shared/widgets/app_field.dart';

/// "Sposta nei ricordi" in two quiet steps (docs/product/17_ricordi_animali.md
/// §3): the date of the loss, then — only when at least one is possible —
/// the memory reminders, all off. Pops with the moved [PetProfile], or null
/// when the owner went back.
class MemorialMovePage extends StatefulWidget {
  const MemorialMovePage({
    super.key,
    required this.pet,
    this.service,
    this.loadMoments = MemorialMoments.load,
    this.today,
  });

  final PetProfile pet;
  final MemorialService? service;
  final Future<MemorialMoments> Function(String petId) loadMoments;

  /// Replaces "today" (tests).
  final DateTime? today;

  @override
  State<MemorialMovePage> createState() => _MemorialMovePageState();
}

class _MemorialMovePageState extends State<MemorialMovePage> {
  late final DateTime _today;
  late DateTime _lossDate;
  late final Future<MemorialMoments> _moments;
  bool _onRemindersStep = false;
  bool _saving = false;
  bool _birthday = false;
  bool _walks = false;
  bool _photos = false;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _lossDate = _today;
    _moments = widget.loadMoments(widget.pet.id);
  }

  DateTime? get _birth => parsePetBirthDateLabel(widget.pet.birthDateLabel);

  bool get _canRememberBirthday => parsePetBirthdayLabel(widget.pet.birthDateLabel) != null;

  Future<void> _pickDate() async {
    final birth = _birth;
    final first = birth != null && birth.isBefore(_today) ? birth : DateTime(1990);
    final picked = await showDatePicker(
      context: context,
      initialDate: _lossDate,
      firstDate: first,
      lastDate: _today,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _lossDate = picked);
  }

  Future<void> _continue() async {
    final moments = await _moments;
    if (!mounted) return;
    final anyPossible =
        _canRememberBirthday || moments.favouriteWalks.isNotEmpty || moments.datedPhotos.isNotEmpty;
    if (anyPossible) {
      setState(() => _onRemindersStep = true);
    } else {
      await _confirm();
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final moved = await (widget.service ?? MemorialService()).moveToMemories(
        widget.pet,
        lossDate: _lossDate,
        choices: MemorialReminderChoices(
          birthday: _birthday,
          walks: _walks,
          photos: _photos,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(moved);
    } on MemoriesFullBlocksMove catch (blocked) {
      // The count was out of date: the pet stays among the active ones.
      if (!mounted) return;
      setState(() => _saving = false);
      await showMemorialMoveBlocked(context, widget.pet.name, blocked);
      if (mounted) Navigator.of(context).pop();
    } on PetSyncException catch (refused) {
      // The server did not take the move: the pet stays among the active ones.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(refused.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.memorialSaveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    return PopScope(
      canPop: !_onRemindersStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _onRemindersStep) setState(() => _onRemindersStep = false);
      },
      child: PetsScaffold(
        title: context.l10n.memorialMoveConfirm,
        onBack: () => _onRemindersStep
            ? setState(() => _onRemindersStep = false)
            : Navigator.of(context).maybePop(),
        badge: PetAvatar(
          label: pet.avatarEmoji,
          backgroundColor: pet.accentColor,
          photoBytes: pet.photoBytes,
          photoPath: pet.photoPath,
          identityColor: pet.identityColor,
          size: 40,
        ),
        body: SingleChildScrollView(
          child: _onRemindersStep ? _remindersStep(context) : _dateStep(context),
        ),
      ),
    );
  }

  Widget _dateStep(BuildContext context) {
    final pet = widget.pet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PetAvatar(
            label: pet.avatarEmoji,
            backgroundColor: pet.accentColor,
            photoBytes: pet.photoBytes,
            photoPath: pet.photoPath,
            identityColor: pet.identityColor,
            size: 96,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          context.l10n.memorialMoveSorry(pet.name),
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          context.l10n.memorialMoveBody(pet.name),
          style: AppTextStyles.body.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppField(
          label: context.l10n.memorialMoveDateLabel,
          child: PickerField(
            key: const ValueKey('memorial-loss-date'),
            icon: Icons.calendar_today_outlined,
            text: formatAppDate(_lossDate, 'd MMMM y'),
            onTap: _saving ? null : _pickDate,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.l10n.memorialMoveDateHelp,
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: AppSpacing.md),
        // One calm sentence about the way back, where the choice is made: it is the
        // consequence nobody expects. Nothing about plans or what counts.
        Text(
          // For an account with no plan and no trial the way back is to choose a plan
          // (Normativa, 2026-11-16): "a free place in your plan" would be wrong there.
          BillingDemoStore.instance.hasAccess
              ? context.l10n.memorialMoveReturnNeedsPlace(pet.name)
              : context.l10n.memorialMoveReturnNeedsPlan(pet.name),
          key: const ValueKey('memorial-return-needs-place'),
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _continue,
          child: Text(context.l10n.memorialMoveContinue),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }

  Widget _remindersStep(BuildContext context) {
    return FutureBuilder<MemorialMoments>(
      future: _moments,
      builder: (context, snapshot) {
        final moments = snapshot.data ?? const MemorialMoments();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.memorialRemindTitle, style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.memorialRemindBody,
              style: AppTextStyles.body.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            MemorialReminderSwitches(
              canBirthday: _canRememberBirthday,
              canWalks: moments.favouriteWalks.isNotEmpty,
              canPhotos: moments.datedPhotos.isNotEmpty,
              birthday: _birthday,
              walks: _walks,
              photos: _photos,
              onChanged: _saving
                  ? null
                  : (choices) => setState(() {
                        _birthday = choices.birthday;
                        _walks = choices.walks;
                        _photos = choices.photos;
                      }),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const ValueKey('memorial-confirm'),
              onPressed: _saving ? null : _confirm,
              child: Text(context.l10n.memorialMoveConfirm),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _saving ? null : () => setState(() => _onRemindersStep = false),
              child: Text(context.l10n.commonBack),
            ),
          ],
        );
      },
    );
  }
}

/// The three memory reminders, each shown only when it can work for this
/// pet (doc 17 §5.1). Used in the move flow and on the memorial page.
class MemorialReminderSwitches extends StatelessWidget {
  const MemorialReminderSwitches({
    super.key,
    required this.canBirthday,
    required this.canWalks,
    required this.canPhotos,
    required this.birthday,
    required this.walks,
    required this.photos,
    required this.onChanged,
  });

  final bool canBirthday;
  final bool canWalks;
  final bool canPhotos;
  final bool birthday;
  final bool walks;
  final bool photos;
  final ValueChanged<MemorialReminderChoices>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onChanged = this.onChanged;
    Widget tile(
      String key,
      String title,
      String help,
      bool value,
      MemorialReminderChoices Function(bool on) next,
    ) {
      return SwitchListTile(
        key: ValueKey(key),
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged == null ? null : (on) => onChanged(next(on)),
        title: Text(title, style: AppTextStyles.body),
        subtitle: Text(
          help,
          style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
        ),
      );
    }

    return Column(
      children: [
        if (canBirthday)
          tile(
            'memorial-switch-birthday',
            l10n.memorialRemindBirthday,
            l10n.memorialRemindBirthdayHelp,
            birthday,
            (on) => MemorialReminderChoices(
              birthday: on,
              walks: walks,
              photos: photos,
            ),
          ),
        if (canWalks)
          tile(
            'memorial-switch-walks',
            l10n.memorialRemindWalks,
            l10n.memorialRemindWalksHelp,
            walks,
            (on) => MemorialReminderChoices(
              birthday: birthday,
              walks: on,
              photos: photos,
            ),
          ),
        if (canPhotos)
          tile(
            'memorial-switch-photos',
            l10n.memorialRemindPhotos,
            l10n.memorialRemindPhotosHelp,
            photos,
            (on) => MemorialReminderChoices(
              birthday: birthday,
              walks: walks,
              photos: on,
            ),
          ),
      ],
    );
  }
}
