import 'dart:async';

import 'package:flutter/material.dart';

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
import '../../../pets/presentation/widgets/pet_avatar.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../../settings/data/layout_settings_store.dart';
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
    // Fire-and-forget: LayoutSettingsStore is a ChangeNotifier, so once the
    // persisted preference finishes loading it notifies _AgendaSection's
    // ListenableBuilder directly — no need to await it here.
    unawaited(LayoutSettingsStore.instance.ensureLoaded());
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

    final results = await fetchManyWithLimit(
      categories.map((c) => () => _petNewsRepository.fetchForSpecies(c, limit: 1)).toList(),
    );
    return results.expand((items) => items).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
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
                    _AgendaSection(remindersFuture: _remindersFuture),
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

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _startOfWeek(DateTime day, WeekStartDay weekStartDay) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final offset = weekStartDay == WeekStartDay.monday
      ? startOfDay.weekday - 1
      : startOfDay.weekday % 7;
  return startOfDay.subtract(Duration(days: offset));
}

class _AgendaSection extends StatelessWidget {
  const _AgendaSection({required this.remindersFuture});

  final Future<List<ReminderEntry>> remindersFuture;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LayoutSettingsStore.instance,
      builder: (context, _) {
        final layout = LayoutSettingsStore.instance.settings;

        return FutureBuilder<List<ReminderEntry>>(
          future: remindersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardSectionHeader(
                    title: 'Prossime attività',
                    subtitle: 'Spot e cicli, per tutti gli animali.',
                    actionLabel: 'Vedi tutti',
                    onActionPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RemindersListPage()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionSkeleton(),
                ],
              );
            }

            final reminders = (snapshot.data ?? const <ReminderEntry>[])
                .where((r) => !r.isDone)
                .toList(growable: false)
              ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardSectionHeader(
                  title: 'Prossime attività',
                  subtitle: _summaryLine(reminders),
                  actionLabel: 'Vedi tutti',
                  onActionPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const RemindersListPage()),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _WeekStrip(
                  reminders: reminders,
                  pets: PetDemoStore.instance.list(),
                  weeksShown: layout.weeksShown,
                  weekStartDay: layout.weekStartDay,
                ),
                Builder(
                  builder: (context) {
                    final legendPets = _petsWithVisibleActivity(
                      reminders,
                      PetDemoStore.instance.list(),
                      layout.weeksShown,
                      layout.weekStartDay,
                    );
                    if (legendPets.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: _PetLegend(pets: legendPets),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Fixed 10-day window, deliberately independent of the "weeks shown"
  /// layout setting, which only governs the calendar strip above. Courses
  /// aren't counted here — they're ongoing rather than "upcoming", and are
  /// shown on the calendar as capsule markers instead.
  String _summaryLine(List<ReminderEntry> reminders) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfWindow = startOfToday.add(const Duration(days: 10));

    final count = reminders.where((r) {
      if (r.kind == EventKind.course) return false;
      final d = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
      return !d.isBefore(startOfToday) && !d.isAfter(endOfWindow);
    }).length;

    return '$count attività nei prossimi 10 giorni';
  }
}

PetProfile? _petByName(List<PetProfile> pets, String name) {
  for (final pet in pets) {
    if (pet.name == name) return pet;
  }
  return null;
}

/// True when [reminder] should show a calendar marker on [day]: the exact
/// due date for spot/recurring events, or any day within the course's
/// start..start+duration-1 span for courses (so an ongoing treatment shows
/// as a visible band rather than a single day).
bool _reminderActiveOnDay(ReminderEntry reminder, DateTime day) {
  if (reminder.kind == EventKind.course) {
    final start = DateTime(reminder.dueAt.year, reminder.dueAt.month, reminder.dueAt.day);
    final end = start.add(Duration(days: (reminder.courseDurationDays ?? 1) - 1));
    return !day.isBefore(start) && !day.isAfter(end);
  }
  return _isSameDay(reminder.dueAt, day);
}

/// Distinct pets with at least one calendar marker somewhere in the
/// currently visible weeks — used to build the calendar's color legend.
List<PetProfile> _petsWithVisibleActivity(
  List<ReminderEntry> reminders,
  List<PetProfile> pets,
  int weeksShown,
  WeekStartDay weekStartDay,
) {
  final today = DateTime.now();
  final weekStart = _startOfWeek(DateTime(today.year, today.month, today.day), weekStartDay);
  final activeIds = <String>{};
  for (var i = 0; i < weeksShown * 7; i++) {
    final day = weekStart.add(Duration(days: i));
    for (final reminder in reminders) {
      if (!_reminderActiveOnDay(reminder, day)) continue;
      final pet = _petByName(pets, reminder.petName);
      if (pet != null) activeIds.add(pet.id);
    }
  }
  return pets.where((pet) => activeIds.contains(pet.id)).toList(growable: false);
}

enum _MarkerShape { dot, capsule }

class _DayMarker {
  const _DayMarker({required this.color, required this.shape});
  final Color color;
  final _MarkerShape shape;
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.reminders,
    required this.pets,
    required this.weeksShown,
    required this.weekStartDay,
  });

  final List<ReminderEntry> reminders;
  final List<PetProfile> pets;
  final int weeksShown;
  final WeekStartDay weekStartDay;

  static const _mondayFirstLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
  static const _sundayFirstLabels = ['D', 'L', 'M', 'M', 'G', 'V', 'S'];

  List<_DayMarker> _markersForDay(DateTime day) {
    final markers = <_DayMarker>[];
    final seenDots = <String>{};
    final seenCapsules = <String>{};
    for (final reminder in reminders) {
      if (!_reminderActiveOnDay(reminder, day)) continue;
      final pet = _petByName(pets, reminder.petName);
      if (pet == null) continue;

      final isCourse = reminder.kind == EventKind.course;
      final seen = isCourse ? seenCapsules : seenDots;
      if (!seen.add(pet.id)) continue;

      markers.add(_DayMarker(
        color: pet.identityColor,
        shape: isCourse ? _MarkerShape.capsule : _MarkerShape.dot,
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final weekStart = _startOfWeek(startOfToday, weekStartDay);
    final labels = weekStartDay == WeekStartDay.monday ? _mondayFirstLabels : _sundayFirstLabels;
    final totalDays = weeksShown * 7;
    final days = List.generate(totalDays, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        for (var week = 0; week < weeksShown; week++) ...[
          if (week != 0) const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                Builder(
                  builder: (context) {
                    final day = days[week * 7 + i];
                    return Expanded(
                      child: _DayChip(
                        day: day,
                        label: labels[i],
                        isToday: _isSameDay(day, startOfToday),
                        markers: _markersForDay(day),
                      ),
                    );
                  },
                ),
                if (i != 6) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MarkerGlyph extends StatelessWidget {
  const _MarkerGlyph({required this.marker});

  final _DayMarker marker;

  @override
  Widget build(BuildContext context) {
    if (marker.shape == _MarkerShape.dot) {
      return Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: marker.color,
          border: Border.all(color: AppColors.surfaceElevated, width: 0.5),
        ),
      );
    }

    return Container(
      width: 10,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.surfaceElevated, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(child: Container(color: Colors.white)),
          Expanded(child: Container(color: marker.color)),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.label,
    required this.isToday,
    required this.markers,
  });

  final DateTime day;
  final String label;
  final bool isToday;
  final List<_DayMarker> markers;

  @override
  Widget build(BuildContext context) {
    final background = isToday ? AppColors.accentSoft : Colors.transparent;
    const foreground = AppColors.text;
    final shown = markers.take(2).toList();
    final extra = markers.length - shown.length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: isToday ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: foreground.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.day}',
            style: AppTextStyles.bodySmall.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 8,
            child: markers.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final marker in shown) _MarkerGlyph(marker: marker),
                      if (extra > 0)
                        Text(
                          '+$extra',
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            color: foreground,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PetLegend extends StatelessWidget {
  const _PetLegend({required this.pets});

  final List<PetProfile> pets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final pet in pets)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PetAvatar(
                label: pet.avatarEmoji,
                backgroundColor: pet.accentColor,
                photoBytes: pet.photoBytes,
                identityColor: pet.identityColor,
                size: 26,
              ),
              const SizedBox(width: 6),
              Text(
                pet.name,
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
      ],
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
          subtitle: 'Notizie dal mondo dei pet selezionate per te.',
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
