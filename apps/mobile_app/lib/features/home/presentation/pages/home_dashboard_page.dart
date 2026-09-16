import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../local_events/presentation/pages/local_events_page.dart';
import '../../../pet_news/data/pet_news_repository.dart';
import '../../../pet_news/domain/pet_news_item.dart';
import '../../../pet_news/presentation/pages/news_feed_page.dart';
import '../../../pet_news/presentation/widgets/pet_news_card.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
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

  /// Exactly 4 curiosità categories: the 3rd (index 2) is always the
  /// cross-species "Generale" category (regulatory/informational), the
  /// other 3 slots are filled with the owned species, in order.
  Future<List<PetNewsItem>> _loadPetNews() async {
    final owned = PetDemoStore.instance.list().map((pet) => pet.species).toSet().toList();
    final categories = <String>[];
    var ownedIndex = 0;
    for (var i = 0; i < 4; i++) {
      if (i == 2) {
        categories.add('Generale');
      } else if (ownedIndex < owned.length) {
        categories.add(owned[ownedIndex++]);
      } else {
        categories.add('Generale');
      }
    }

    final results = await Future.wait(
      categories.map((c) => _petNewsRepository.fetchForSpecies(c, limit: 1)),
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
                    _CalendarSection(
                      remindersFuture: _remindersFuture,
                      pets: pets,
                      onOpenReminder: _openReminder,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _PetNewsSection(petNewsFuture: _petNewsFuture),
                    const SizedBox(height: AppSpacing.xxl),
                    const _LocalEventsNotice(),
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
/// dot on the pet detail calendar markers.
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
                  PetNewsCard(item: item),
                  const SizedBox(height: AppSpacing.md),
                ],
                _MoreNewsButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const NewsFeedPage()),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MoreNewsButton extends StatelessWidget {
  const _MoreNewsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.newspaper_outlined, size: 18),
        label: const Text('Scopri altre notizie'),
      ),
    );
  }
}

class _LocalEventsNotice extends StatelessWidget {
  const _LocalEventsNotice();

  @override
  Widget build(BuildContext context) {
    return DashboardSurfaceCard(
      tone: DashboardTone.info,
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LocalEventsPage()),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(Icons.map_outlined, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Eventi nei dintorni · in arrivo',
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
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
