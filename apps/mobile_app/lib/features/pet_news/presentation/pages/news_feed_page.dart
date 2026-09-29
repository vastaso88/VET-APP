import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../app/splash/loading_animation.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../data/pet_news_repository.dart';
import '../../domain/pet_news_item.dart';
import '../widgets/pet_news_card.dart';

class NewsFeedPage extends StatefulWidget {
  const NewsFeedPage({super.key});

  @override
  State<NewsFeedPage> createState() => _NewsFeedPageState();
}

class _NewsFeedPageState extends State<NewsFeedPage> {
  static const _categories = allPetNewsCategories;
  static const _cardsPerRefresh = 6;

  final _repository = GoogleNewsPetNewsRepository();
  final _random = Random();

  bool _loading = true;
  bool _refreshing = false;
  List<PetNewsItem> _pool = [];
  List<PetNewsItem> _shown = [];
  Set<String> _lastShownLinks = {};
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadPool();
  }

  // Reveals cards as soon as the FIRST batch of categories lands (see
  // fetchManyWithLimitStreaming — batches of 3, well under a second each in
  // practice) instead of blocking on every one of the 8 fixed categories,
  // which is what made this page feel slow even after speeding up the
  // batching itself. Later batches keep enriching `_pool` silently in the
  // background — visible on the next refresh or category switch, without
  // reshuffling cards the user is already looking at.
  Future<void> _loadPool() async {
    setState(() {
      _loading = true;
      _pool = [];
    });

    var revealed = false;
    await fetchManyWithLimitStreaming<List<PetNewsItem>>(
      _categories
          .map((c) => () => _repository.fetchForSpecies(c, limit: petNewsPoolLimitPerCategory))
          .toList(),
      onBatch: (batchResults) {
        if (!mounted) return;
        _pool = [..._pool, ...batchResults.expand((items) => items)];
        if (!revealed) {
          revealed = true;
          _pickNext();
          setState(() => _loading = false);
        }
      },
    );
  }

  void _pickNext() {
    final candidates = (_selectedCategory == null
        ? _pool
        : _pool.where((item) => item.species == _selectedCategory).toList())
      ..shuffle(_random);

    final fresh = candidates.where((item) => !_lastShownLinks.contains(item.sourceUrl)).toList();
    final source = fresh.length >= min(_cardsPerRefresh, candidates.length) ? fresh : candidates;
    final picked = source.take(_cardsPerRefresh).toList();

    setState(() {
      _shown = picked;
      _lastShownLinks = picked.map((item) => item.sourceUrl).toSet();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _pickNext();
    setState(() => _refreshing = false);
  }

  void _selectCategory(String? category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    _lastShownLinks = {};
    _pickNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF163A35)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Notizie', style: AppTextStyles.display.copyWith(fontSize: 26)),
                  ),
                  _RefreshButton(refreshing: _refreshing, onTap: _refresh),
                ],
              ),
            ),
            _CategoryBar(
              categories: _categories,
              selected: _selectedCategory,
              onSelect: _selectCategory,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _loading
                  ? const Center(child: LoadingAnimation(label: 'Carico le News...'))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: _shown.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              children: [
                                const SizedBox(height: AppSpacing.xxxl),
                                Text(
                                  'Nessuna notizia disponibile per questa categoria al momento.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySmall,
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.xxxl,
                              ),
                              itemCount: _shown.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                              itemBuilder: (_, index) => PetNewsCard(item: _shown[index]),
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.refreshing, required this.onTap});

  final bool refreshing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: refreshing ? null : onTap,
      icon: refreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, color: AppColors.primary),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        children: [
          _CategoryChip(
            label: 'Tutti',
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: AppSpacing.sm),
            _CategoryChip(
              label: category,
              selected: selected == category,
              onTap: () => onSelect(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGenerale = label == 'Generale';
    final isTutti = label == 'Tutti';

    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTutti)
                Icon(Icons.apps_rounded, size: 15, color: selected ? AppColors.onPrimary : AppColors.text)
              else if (isGenerale)
                Icon(Icons.campaign_outlined, size: 15, color: selected ? AppColors.onPrimary : AppColors.text)
              else
                Text(
                  PetDemoStore.optionForSpecies(label).avatarEmoji,
                  style: const TextStyle(fontSize: 14),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? AppColors.onPrimary : AppColors.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
