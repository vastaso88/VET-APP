import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/auth/current_user.dart';
import '../../../account_consents/application/chat_notice.dart';
import '../../../chat/data/chat_demo_store.dart';
import '../../../chat/presentation/start_chat.dart';
import '../../../dog_walks/data/walk_home_widget.dart';
import '../../../pet_news/data/pet_news_repository.dart';
import '../../../pet_news/domain/pet_news_item.dart';
import '../../../pet_news/presentation/pages/news_feed_page.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../../pets/domain/pet_models.dart';
import '../../../pets/presentation/pages/pet_create_page.dart';
import '../../../pets/presentation/pages/pet_detail_page.dart';
import '../../../pets/presentation/widgets/pet_picker.dart';
import '../../../reminders/data/reminders_repository.dart';
import '../../../reminders/presentation/pages/reminders_pages.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../widgets/home_ask_quokka_band.dart';
import '../widgets/home_calendar_section.dart';
import '../widgets/home_news_section.dart';
import '../widgets/home_pets_section.dart';

export '../widgets/home_calendar_section.dart' show HomeDayChip, homeCalendarDays;

/// Home: the owner's animals, the way into the chat, the calendar, the stories.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    super.key,
    this.petNewsRepository,
    this.remindersRepository,
    this.noticeGate = ChatNotice.ensure,
    this.onOpenNews,
    this.clock = DateTime.now,
  });

  /// Only for tests, like the rest: the page uses the app's own otherwise.
  final PetNewsRepository? petNewsRepository;
  final RemindersRepository? remindersRepository;

  /// Asks, once, that Quokka does not handle emergencies (see [ChatNotice]).
  final Future<bool> Function(BuildContext context) noticeGate;

  /// Opens a story; by default in the browser.
  final ValueChanged<PetNewsItem>? onOpenNews;

  final DateTime Function() clock;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  late final RemindersRepository _remindersRepository =
      widget.remindersRepository ?? RemindersRepository();
  late final PetNewsRepository _petNewsRepository =
      widget.petNewsRepository ?? BackendPetNewsRepository();

  late Future<List<PetNewsItem>> _petNewsFuture;

  /// False until the first read of the animals has ended, well or badly: before
  /// that an empty list does not mean "no animal".
  bool _petsChecked = false;

  bool _asking = false;
  bool _openingChat = false;

  /// The longest a tap on "Chiedi a Quokka" waits for the stored chats (they
  /// count for the limit per animal).
  static const _chatsWait = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    unawaited(_loadPets());
    _petNewsFuture = _loadPetNews();
    // Fire-and-forget: LayoutSettingsStore is a ChangeNotifier, so once the
    // persisted preference finishes loading it notifies the calendar's
    // ListenableBuilder directly — no need to await it here.
    unawaited(LayoutSettingsStore.instance.ensureLoaded());
  }

  Future<void> _loadPets() async {
    try {
      await PetDemoStore.instance.ensureHydrated();
    } catch (_) {}
    if (mounted) setState(() => _petsChecked = true);
  }

  void _retryPets() {
    setState(() => _petsChecked = false);
    unawaited(_loadPets());
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
    try {
      return await _loadPetNewsUnguarded();
    } catch (_) {
      return const <PetNewsItem>[];
    }
  }

  /// "Riprova" under an unavailable section: asks again (the shared answer is
  /// only kept when the server gave one, so this really asks the server).
  void _retryPetNews() {
    final next = _loadPetNews();
    setState(() {
      _petNewsFuture = next;
    });
  }

  Future<List<PetNewsItem>> _loadPetNewsUnguarded() async {
    // The pet list only orders the cards by species: it never holds the news up
    // for more than a few seconds (or fails them).
    try {
      await PetDemoStore.instance.ensureHydrated().timeout(const Duration(seconds: 4));
    } catch (_) {}
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

  Future<void> _openPet(PetProfile pet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PetDetailPage(pet: pet)),
    );
    _syncHomeWidget();
  }

  Future<void> _addPet() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PetCreatePage()),
    );
    _syncHomeWidget();
  }

  /// The phone's home-screen widget lists the animals too (as the Animali page
  /// does after the same two pages).
  void _syncHomeWidget() => unawaited(syncPetsToHomeWidget(PetDemoStore.instance.list()));

  /// One animal: a new chat about it. More: which one, first.
  Future<void> _askQuokka() async {
    if (_asking) return;
    _asking = true;
    try {
      final pets = PetDemoStore.instance.list();
      if (pets.isEmpty) return;
      final pet = pets.length == 1 ? pets.single : await showPetPicker(context, pets);
      if (pet == null || !mounted) return;
      setState(() => _openingChat = true);
      try {
        await ChatDemoStore.instance.ensureHydrated().timeout(_chatsWait);
      } catch (_) {
        // The chats could not be read: the server still holds the limit.
      }
      if (!mounted) return;
      await startChatWithPet(
        context,
        petId: pet.id,
        petName: pet.name,
        noticeGate: widget.noticeGate,
      );
    } finally {
      _asking = false;
      if (mounted) setState(() => _openingChat = false);
    }
  }

  void _openNews(PetNewsItem item) {
    final open = widget.onOpenNews;
    if (open != null) {
      open(item);
      return;
    }
    launchUrl(Uri.parse(item.sourceUrl), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final ownerName = CurrentUser.firstName(fallback: context.l10n.sharedGuestName);
    // A short phone gets a little less air, so the calendar is reached sooner.
    final compact = MediaQuery.sizeOf(context).width <= 375;
    final sectionGap = SizedBox(height: compact ? AppSpacing.lg + AppSpacing.xs : AppSpacing.xl);

    return SizedBox.expand(
      child: ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              compact ? AppSpacing.lg : AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.homeGreeting, style: AppTextStyles.bodySmall),
                    Text(ownerName, style: AppTextStyles.display.copyWith(fontSize: 32)),
                    const SizedBox(height: AppSpacing.lg),
                    ValueListenableBuilder<int>(
                      valueListenable: PetDemoStore.changes,
                      builder: (context, _, __) => _petsAndChat(context),
                    ),
                    sectionGap,
                    HomeCalendarSection(
                      repository: _remindersRepository,
                      clock: widget.clock,
                      onOpenReminders: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const RemindersListPage()),
                      ),
                    ),
                    sectionGap,
                    HomeNewsSection(
                      news: _petNewsFuture,
                      onRetry: _retryPetNews,
                      onOpen: _openNews,
                      onMore: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const NewsFeedPage()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _petsAndChat(BuildContext context) {
    final store = PetDemoStore.instance;
    final pets = store.list();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomePetsSection(
          pets: pets,
          loading: !_petsChecked,
          failed: store.lastHydrationFailed,
          onlyMemories: store.memorialPets().isNotEmpty,
          onOpenPet: (pet) => unawaited(_openPet(pet)),
          onAdd: () => unawaited(_addPet()),
          onRetry: _retryPets,
        ),
        // A chat is always about an animal: without one there is nothing to open.
        if (pets.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          HomeAskQuokkaBand(
            // With one animal there is nothing to choose: the chat opens straight on it.
            subtitle: pets.length == 1
                ? context.l10n.chatComposerHint(pets.single.name)
                : context.l10n.remindersChoosePet,
            opening: _openingChat,
            onTap: () => unawaited(_askQuokka()),
          ),
        ],
      ],
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
