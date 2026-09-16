import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../pet_news/data/pet_news_repository.dart';
import '../../../pet_news/domain/pet_news_item.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/pages/pet_detail_page.dart';
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/domain/relative_date.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../widgets/home_dashboard_primitives.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _remindersRepository = RemindersRepository();
  final _petNewsRepository = GoogleNewsPetNewsRepository();

  late Future<List<ReminderEntry>> _remindersFuture;
  late Future<List<PetNewsItem>> _petNewsFuture;

  @override
  void initState() {
    super.initState();
    _remindersFuture = _remindersRepository.loadReminders();
    _petNewsFuture = _loadPetNews();
  }

  Future<List<PetNewsItem>> _loadPetNews() async {
    final species = PetDemoStore.instance.list().map((pet) => pet.species).toSet();
    final categories = {...species, 'Generale'};
    final results = await Future.wait(
      categories.map((s) => _petNewsRepository.fetchForSpecies(s)),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  Future<void> _openReminder(ReminderEntry reminder) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReminderEditPage(reminder: reminder)),
    );
    if (!mounted) return;
    setState(() => _remindersFuture = _remindersRepository.loadReminders());
  }

  @override
  Widget build(BuildContext context) {
    final pets = PetDemoStore.instance.list();
    final ownerName = CurrentUser.firstName(fallback: 'Ospite');

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF9F6F1),
              Color(0xFFF4EFE7),
              Color(0xFFEDE6DC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buongiorno', style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    Text(ownerName, style: AppTextStyles.display),
                    const SizedBox(height: AppSpacing.xxl),
                    if (pets.isEmpty)
                      const _EmptyPets()
                    else
                      _PetStrip(pets: pets),
                    const SizedBox(height: AppSpacing.xxl),
                    _CalendarSection(
                      remindersFuture: _remindersFuture,
                      pets: pets,
                      onOpenReminder: _openReminder,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _PetNewsSection(petNewsFuture: _petNewsFuture),
                    const SizedBox(height: AppSpacing.xxl),
                    const _LocalEventsWipSection(),
                    const SizedBox(height: AppSpacing.xxl),
                    const _SponsorBanner(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a pet's free-text [healthBadge] to a [DashboardTone] for the status
/// dot on the Home pet strip.
DashboardTone toneForHealthBadge(String badge) {
  final normalized = badge.toLowerCase();
  if (normalized.contains('monitorare')) return DashboardTone.warning;
  if (normalized.contains('muta')) return DashboardTone.info;
  if (normalized.contains('stabile')) return DashboardTone.success;
  return DashboardTone.neutral;
}

/// Strengthens a pale [PetProfile.accentColor] (designed as a soft card
/// background) into a saturated, higher-contrast fill for small markers —
/// same hue, forced saturation/lightness so it reads clearly at 15px.
Color strongMarkerColor(Color base) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withSaturation(0.5).withLightness(0.42).toColor();
}

class _PetStrip extends StatelessWidget {
  const _PetStrip({required this.pets});

  final List<PetProfile> pets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pets.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (context, index) => _PetStripChip(pet: pets[index]),
      ),
    );
  }
}

class _PetStripChip extends StatelessWidget {
  const _PetStripChip({required this.pet});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    final tone = toneForHealthBadge(pet.healthBadge);
    final dotColor = DashboardPrimitivePalette.colorsFor(tone).foreground;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.large),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PetDetailPage(pet: pet)),
      ),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PetAvatar(label: pet.avatarEmoji, backgroundColor: pet.accentColor, size: 56),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surfaceElevated, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.remindersFuture,
    required this.pets,
    required this.onOpenReminder,
  });

  final Future<List<ReminderEntry>> remindersFuture;
  final List<PetProfile> pets;
  final ValueChanged<ReminderEntry> onOpenReminder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          title: 'Prossime attività',
          subtitle: 'Tocca un giorno per vedere le attività, per tutti gli animali.',
          actionLabel: 'Vedi tutti',
          onActionPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RemindersListPage()),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FutureBuilder<List<ReminderEntry>>(
          future: remindersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SectionSkeleton();
            }

            final reminders = (snapshot.data ?? const [])
                .where((reminder) => reminder.dueAt != null)
                .toList(growable: false);

            return _RemindersCalendar(
              reminders: reminders,
              pets: pets,
              onOpenReminder: onOpenReminder,
            );
          },
        ),
      ],
    );
  }
}

class _RemindersCalendar extends StatefulWidget {
  const _RemindersCalendar({
    required this.reminders,
    required this.pets,
    required this.onOpenReminder,
  });

  final List<ReminderEntry> reminders;
  final List<PetProfile> pets;
  final ValueChanged<ReminderEntry> onOpenReminder;

  @override
  State<_RemindersCalendar> createState() => _RemindersCalendarState();
}

class _RemindersCalendarState extends State<_RemindersCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<ReminderEntry> _eventsForDay(DateTime day) {
    return widget.reminders.where((r) => isSameDay(r.dueAt!, day)).toList();
  }

  PetProfile? _petByName(String name) {
    for (final pet in widget.pets) {
      if (pet.name == name) return pet;
    }
    return null;
  }

  void _handleDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final events = _eventsForDay(selectedDay);
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });

    if (events.length == 1) {
      widget.onOpenReminder(events.first);
    } else if (events.length > 1) {
      _showDayEvents(events);
    }
  }

  void _showDayEvents(List<ReminderEntry> events) {
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
              Text('Attività del giorno', style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.md),
              for (final reminder in events) ...[
                DashboardListRow(
                  title: reminder.title,
                  subtitle: '${reminder.petName} · ${relativeDayLabel(reminder.dueAt!)}',
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    widget.onOpenReminder(reminder);
                  },
                ),
                if (reminder != events.last) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
      child: TableCalendar<ReminderEntry>(
        locale: 'it_IT',
        firstDay: DateTime(_focusedDay.year - 1, 1, 1),
        lastDay: DateTime(_focusedDay.year + 1, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => _selectedDay != null && isSameDay(_selectedDay!, day),
        eventLoader: _eventsForDay,
        onDaySelected: _handleDaySelected,
        onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: AppTextStyles.title.copyWith(fontSize: 16),
          leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
          rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: AppTextStyles.caption,
          weekendStyle: AppTextStyles.caption,
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
          weekendTextStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
          todayDecoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: AppColors.primaryStrong, fontWeight: FontWeight.w700),
          selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.w700),
          markerDecoration: const BoxDecoration(),
          markersMaxCount: 0,
        ),
        calendarBuilders: CalendarBuilders<ReminderEntry>(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return null;

            final petsForDay = <PetProfile>[];
            for (final reminder in events) {
              final pet = _petByName(reminder.petName);
              if (pet != null && !petsForDay.any((p) => p.id == pet.id)) {
                petsForDay.add(pet);
              }
            }
            if (petsForDay.isEmpty) return null;

            final shown = petsForDay.take(2).toList();
            final extra = petsForDay.length - shown.length;

            return Positioned(
              bottom: 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final pet in shown)
                    Container(
                      width: 15,
                      height: 15,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: strongMarkerColor(pet.accentColor),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceElevated, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          pet.avatarEmoji,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  if (extra > 0)
                    Text('+$extra', style: AppTextStyles.caption.copyWith(fontSize: 8)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PetNewsSection extends StatelessWidget {
  const _PetNewsSection({required this.petNewsFuture});

  final Future<List<PetNewsItem>> petNewsFuture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(
          title: 'Curiosità per i tuoi animali',
          subtitle: 'Notizie vere da giornali reali, in base alle specie che segui.',
        ),
        const SizedBox(height: AppSpacing.lg),
        FutureBuilder<List<PetNewsItem>>(
          future: petNewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SectionSkeleton();
            }

            final items = snapshot.data ?? const <PetNewsItem>[];
            if (items.isEmpty) {
              return DashboardSurfaceCard(
                child: Text(
                  'Curiosità non disponibili al momento. Riprova più tardi.',
                  style: AppTextStyles.bodySmall,
                ),
              );
            }

            return Column(
              children: [
                for (final item in items) ...[
                  _PetNewsCard(item: item),
                  if (item != items.last) const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PetNewsCard extends StatelessWidget {
  const _PetNewsCard({required this.item});

  final PetNewsItem item;

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      tone: DashboardTone.warm,
      onTap: () => launchUrl(Uri.parse(item.sourceUrl), webOnlyWindowName: '_blank'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: Image.network(
                item.imageUrl!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  PetDemoStore.optionForSpecies(item.species).avatarEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.newspaper_outlined, size: 14, color: AppColors.mutedText),
                    const SizedBox(width: AppSpacing.xs),
                    Text(item.extract, style: AppTextStyles.caption),
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

class _LocalEventsWipSection extends StatelessWidget {
  const _LocalEventsWipSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionHeader(title: 'Eventi nei dintorni'),
        const SizedBox(height: AppSpacing.lg),
        DashboardSurfaceCard(
          tone: DashboardTone.info,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: const Icon(Icons.construction_outlined, size: 20, color: AppColors.info),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('In arrivo', style: AppTextStyles.title.copyWith(fontSize: 16)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Promozioni di eventi vicino a te, in base alla tua zona. Ancora in lavorazione.',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SponsorBanner extends StatelessWidget {
  const _SponsorBanner();

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      tone: DashboardTone.neutral,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(Icons.storefront_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Spazio riservato ai nostri partner.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('Caricamento...', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nessun animale ancora', style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Aggiungi il primo profilo dalla scheda Animali per iniziare.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}
