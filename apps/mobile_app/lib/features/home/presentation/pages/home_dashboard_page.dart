import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/responsive.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
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
import '../../../reminders/domain/reminder_calendar.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../../../shared/date/calendar_days.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../widgets/home_dashboard_primitives.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _remindersRepository = RemindersRepository();
  final _petNewsRepository = BackendPetNewsRepository();

  late Future<List<PetNewsItem>> _petNewsFuture;

  @override
  void initState() {
    super.initState();
    _petNewsFuture = _loadPetNews();
    // Fire-and-forget: LayoutSettingsStore is a ChangeNotifier, so once the
    // persisted preference finishes loading it notifies _AgendaSection's
    // ListenableBuilder directly — no need to await it here.
    unawaited(LayoutSettingsStore.instance.ensureLoaded());
  }

  /// Always exactly 4 cards when the fetched data allows it: the 3rd slot
  /// is always the cross-species "Generale" story (a fixed, recognizable
  /// "regulatory story" position — not part of the recency ordering), the
  /// other 3 come from up to 3 owned species, falling back to "Generale"
  /// for any slot beyond how many species the owner actually has. The 3
  /// non-generic slots are sorted newest-first by the feed's own pubDate.
  ///
  /// Each distinct category is fetched once with a pool bigger than the
  /// single card it needs, so a duplicate-title drop — or two slots both
  /// needing "Generale" — backfills from that same pool instead of the
  /// card count silently shrinking (the previous title-based dedup alone
  /// did that: fewer cards instead of different ones).
  Future<List<PetNewsItem>> _loadPetNews() async {
    await PetDemoStore.instance.ensureHydrated();
    final owned = PetDemoStore.instance.list().map((pet) => pet.species).toSet().toList();

    final nonGenericCategories = <String>[
      for (var i = 0; i < 3; i++) i < owned.length ? owned[i] : 'Generale',
    ];

    final categoriesToFetch = {...nonGenericCategories, 'Generale'}.toList(growable: false);
    final results = await fetchManyWithLimit(
      categoriesToFetch
          .map((c) => () => _petNewsRepository.fetchForSpecies(c, limit: petNewsPoolLimitPerCategory))
          .toList(),
    );
    final poolByCategory = <String, List<PetNewsItem>>{
      for (var i = 0; i < categoriesToFetch.length; i++)
        categoriesToFetch[i]: List<PetNewsItem>.of(results[i]),
    };

    return selectHomeNewsSlots(
      nonGenericCategories: nonGenericCategories,
      poolByCategory: poolByCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = CurrentUser.firstName(fallback: context.l10n.sharedGuestName);

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.homeGreeting, style: AppTextStyles.caption),
                    const SizedBox(height: AppSpacing.xs),
                    Text(ownerName, style: AppTextStyles.display),
                    const SizedBox(height: AppSpacing.xxl),
                    _AgendaSection(repository: _remindersRepository),
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

/// Newest first; an item with no parsed `pubDate` sorts as oldest rather
/// than guessing a date for it.
int _compareNewsByRecency(PetNewsItem a, PetNewsItem b) {
  final aDate = a.publishedAt;
  final bDate = b.publishedAt;
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return bDate.compareTo(aDate);
}

/// Picks Home's fixed 4-card news selection from already-fetched pools: 3
/// species slots plus a "Generale" slot ALWAYS at position 2 (the 3rd card)
/// whenever at least one generic item was fetched at all — this must hold
/// regardless of which category's batch happened to land first, so it's a
/// pure function over the already-completed [poolByCategory] rather than
/// something built incrementally as batches stream in (Home deliberately
/// doesn't reveal partial results — see `_loadPetNews` — precisely so this
/// invariant never has to race a slow "Generale" fetch).
///
/// [nonGenericCategories] is the 3-entry list (owned species, padded with
/// "Generale" if the owner has fewer than 3) that decides which pools feed
/// the non-generic slots; [poolByCategory] must contain an entry for every
/// value in it plus `'Generale'`. Pools don't need to be pre-sorted.
List<PetNewsItem> selectHomeNewsSlots({
  required List<String> nonGenericCategories,
  required Map<String, List<PetNewsItem>> poolByCategory,
}) {
  final sortedPoolByCategory = <String, List<PetNewsItem>>{
    for (final entry in poolByCategory.entries)
      entry.key: List<PetNewsItem>.of(entry.value)..sort(_compareNewsByRecency),
  };
  final allItemsNewestFirst = poolByCategory.values.expand((items) => items).toList(growable: false)
    ..sort(_compareNewsByRecency);

  final usedTitles = <String>{};
  PetNewsItem? takeFromCategory(String category) {
    for (final item in sortedPoolByCategory[category] ?? const <PetNewsItem>[]) {
      if (usedTitles.add(item.title)) return item;
    }
    return null;
  }

  PetNewsItem? takeFromAnyCategory() {
    for (final item in allItemsNewestFirst) {
      if (usedTitles.add(item.title)) return item;
    }
    return null;
  }

  // Claim the generic slot first so a "Generale" fallback slot below (an
  // owner with fewer than 3 species) backfills from what's left of the
  // same pool, rather than the two competing over the same top item.
  final generic = takeFromCategory('Generale') ?? takeFromAnyCategory();

  final nonGeneric = <PetNewsItem>[];
  for (final category in nonGenericCategories) {
    final item = takeFromCategory(category) ?? takeFromAnyCategory();
    if (item != null) nonGeneric.add(item);
  }
  nonGeneric.sort(_compareNewsByRecency);

  final result = List<PetNewsItem>.of(nonGeneric);
  if (generic != null) {
    // Always index 2 (the 3rd card) once there are at least 2 other cards
    // to sit around it — never appended at the end, which would silently
    // drop the "always position 3" guarantee whenever a batch reordering
    // changed how many non-generic slots resolved first.
    result.insert(result.length >= 2 ? 2 : result.length, generic);
  }
  return result;
}

/// The days of the home calendar strip: [weeksShown] full weeks starting from
/// the week of [today]. Calendar arithmetic, so the clock change of 29/03 and
/// 25/10 never repeats or skips a date.
@visibleForTesting
List<DateTime> homeCalendarDays(
    DateTime today, int weeksShown, WeekStartDay weekStartDay) {
  final weekStart = _startOfWeek(today, weekStartDay);
  return List.generate(weeksShown * 7, (i) => addCalendarDays(weekStart, i));
}

DateTime _startOfWeek(DateTime day, WeekStartDay weekStartDay) {
  final startOfDay = DateTime(day.year, day.month, day.day);
  final offset = weekStartDay == WeekStartDay.monday
      ? startOfDay.weekday - 1
      : startOfDay.weekday % 7;
  return addCalendarDays(startOfDay, -offset);
}

class _AgendaSection extends StatelessWidget {
  const _AgendaSection({required this.repository});

  final RemindersRepository repository;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LayoutSettingsStore.instance,
      builder: (context, _) {
        final layout = LayoutSettingsStore.instance.settings;

        // Home stays alive under the bottom-nav IndexedStack (never
        // disposed/rebuilt on tab switch), so a one-shot Future loaded in
        // initState never saw a reminder created elsewhere. Listening to
        // RemindersRepository.changes and re-fetching on every tick keeps
        // the calendar in sync no matter where the reminder was added.
        return ValueListenableBuilder<int>(
          valueListenable: RemindersRepository.changes,
          builder: (context, _, __) {
            return FutureBuilder<List<ReminderEntry>>(
              future: repository.loadReminders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardSectionHeader(
                        title: context.l10n.homeAgendaTitle,
                        subtitle: context.l10n.homeAgendaLoadingSubtitle,
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
                      title: context.l10n.homeAgendaTitle,
                      subtitle: _summaryLine(context, reminders),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ValueListenableBuilder<int>(
                      valueListenable: PetDemoStore.changes,
                      builder: (context, _, __) {
                        final pets = PetDemoStore.instance.list();
                        final legendPets = _petsWithVisibleActivity(
                          reminders,
                          pets,
                          layout.weeksShown,
                          layout.weekStartDay,
                        );
                        return DashboardSurfaceCard(
                          backgroundColor: AppColors.surfaceElevated,
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          // The whole calendar is the entry point into the full
                          // reminders view now — no separate "Vedi tutti" link.
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const RemindersListPage()),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _WeekStrip(
                                reminders: reminders,
                                pets: pets,
                                weeksShown: layout.weeksShown,
                                weekStartDay: layout.weekStartDay,
                              ),
                              if (legendPets.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _PetLegend(pets: legendPets),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
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
  String _summaryLine(BuildContext context, List<ReminderEntry> reminders) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfWindow = addCalendarDays(startOfToday, 10);

    final count = reminders.where((r) {
      if (r.kind == EventKind.course) return false;
      final d = DateTime(r.dueAt.year, r.dueAt.month, r.dueAt.day);
      return !d.isBefore(startOfToday) && !d.isAfter(endOfWindow);
    }).length;

    return context.l10n.homeAgendaSummary(count);
  }
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
  final weekStart =
      _startOfWeek(DateTime(today.year, today.month, today.day), weekStartDay);
  final activeIds = <String>{};
  for (var i = 0; i < weeksShown * 7; i++) {
    final day = addCalendarDays(weekStart, i);
    for (final reminder in reminders) {
      if (!reminderActiveOnDay(reminder, day)) continue;
      final pet = petByName(pets, reminder.petName);
      if (pet != null) activeIds.add(pet.id);
    }
  }
  return pets
      .where((pet) => activeIds.contains(pet.id))
      .toList(growable: false);
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

  /// One-letter weekday headers in the app language ("L M M G V S D" in
  /// Italian), Monday first.
  static List<String> _mondayFirstLabels() => [
        for (final name in appShortWeekdaysMondayFirst()) _initial(name),
      ];

  static List<String> _sundayFirstLabels() {
    final monday = _mondayFirstLabels();
    return [monday.last, ...monday.sublist(0, 6)];
  }

  static String _initial(String name) =>
      name.isEmpty ? '' : String.fromCharCode(name.runes.first).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final labels = weekStartDay == WeekStartDay.monday
        ? _mondayFirstLabels()
        : _sundayFirstLabels();
    final days = homeCalendarDays(startOfToday, weeksShown, weekStartDay);

    return Column(
      children: [
        for (var week = 0; week < weeksShown; week++) ...[
          if (week != 0) const SizedBox(height: AppSpacing.xs),
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
                        isToday: isSameDay(day, startOfToday),
                        markers: markersForDay(reminders, pets, day),
                      ),
                    );
                  },
                ),
                if (i != 6) const SizedBox(width: 3),
              ],
            ],
          ),
        ],
      ],
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
  final List<DayMarker> markers;

  @override
  Widget build(BuildContext context) {
    final background = isToday ? AppColors.secondarySoft : Colors.transparent;
    const foreground = AppColors.text;
    final shown = markers.take(2).toList();
    final extra = markers.length - shown.length;

    // Scaled with the same appScaleOf() rule as MarkerGlyph and PetAvatar
    // (see design_system/responsive.dart) — this chip packs a label, a day
    // number and a row of markers into a tight column, so on a screen wider
    // than the reference width the markers (which already scale up inside
    // MarkerGlyph) were previously clipped by this chip's own fixed-size
    // text and marker-row height staying pinned to the reference size.
    final scale = appScaleOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: isToday
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: foreground.withValues(alpha: 0.7),
              fontSize: 12 * scale,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${day.day}',
            style: AppTextStyles.bodySmall.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 17 * scale,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 11 * scale,
            child: markers.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final marker in shown)
                        MarkerGlyph(marker: marker, size: 9),
                      if (extra > 0)
                        Text(
                          '+$extra',
                          style: TextStyle(
                            fontSize: 8 * scale,
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
                photoPath: pet.photoPath,
                identityColor: pet.identityColor,
                size: 30,
              ),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600, color: AppColors.text),
                ),
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
        DashboardSectionHeader(
          title: context.l10n.homeNewsTitle,
          subtitle: context.l10n.homeNewsSubtitle,
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
                  // Edition without feeds yet: say so instead of "try later".
                  petNewsEditionServed()
                      ? context.l10n.homeNewsUnavailable
                      : context.l10n.petNewsEmptyLocal,
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
                    MaterialPageRoute<void>(
                        builder: (_) => const NewsFeedPage()),
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
        label: Text(context.l10n.homeNewsMore),
      ),
    );
  }
}

class _LocalEventsNotice extends StatefulWidget {
  const _LocalEventsNotice();

  @override
  State<_LocalEventsNotice> createState() => _LocalEventsNoticeState();
}

class _LocalEventsNoticeState extends State<_LocalEventsNotice> {
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
            child:
                const Icon(Icons.map_outlined, size: 18, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.l10n.homeNearbyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.text),
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
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(Icons.storefront_outlined,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              context.l10n.homeSponsorBanner,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.secondaryText),
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
          Flexible(
            child: Text(
              context.l10n.homeSectionLoading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
