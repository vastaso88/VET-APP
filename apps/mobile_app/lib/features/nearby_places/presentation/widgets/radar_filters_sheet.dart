import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../radar_category.dart';

/// Everything the radar page can be narrowed by. Empty sets mean "no
/// restriction" (all categories / all species).
class RadarFilters {
  const RadarFilters({
    required this.radiusKm,
    this.categories = const {},
    this.species = const {},
  });

  final double radiusKm;
  final Set<RadarCategory> categories;
  final Set<String> species;

  bool showsCategory(RadarCategory category) =>
      categories.isEmpty || categories.contains(category);

  /// How many filter groups differ from the defaults (for the badge on
  /// the "Filtri" button). Radius is excluded: it has its own control.
  int get activeCount => (categories.isEmpty ? 0 : 1) + (species.isEmpty ? 0 : 1);

  RadarFilters copyWith({
    double? radiusKm,
    Set<RadarCategory>? categories,
    Set<String>? species,
  }) {
    return RadarFilters(
      radiusKm: radiusKm ?? this.radiusKm,
      categories: categories ?? this.categories,
      species: species ?? this.species,
    );
  }
}

/// Returns the edited filters, or null when dismissed without applying.
Future<RadarFilters?> showRadarFiltersSheet(
  BuildContext context, {
  required RadarFilters filters,
  required List<double> radiusOptionsKm,
}) {
  return showModalBottomSheet<RadarFilters>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _RadarFiltersSheet(initial: filters, radiusOptionsKm: radiusOptionsKm),
  );
}

class _RadarFiltersSheet extends StatefulWidget {
  const _RadarFiltersSheet({required this.initial, required this.radiusOptionsKm});

  final RadarFilters initial;
  final List<double> radiusOptionsKm;

  @override
  State<_RadarFiltersSheet> createState() => _RadarFiltersSheetState();
}

class _RadarFiltersSheetState extends State<_RadarFiltersSheet> {
  late double _radiusKm = widget.initial.radiusKm;
  late final Set<RadarCategory> _categories = {...widget.initial.categories};
  late final Set<String> _species = {...widget.initial.species};

  void _toggle<T>(Set<T> set, T value) {
    setState(() => set.contains(value) ? set.remove(value) : set.add(value));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtri', style: AppTextStyles.title),
            const SizedBox(height: AppSpacing.lg),
            Text('Distanza', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: widget.radiusOptionsKm
                  .map(
                    (option) => ChoiceChip(
                      label: Text('${option.round()} km'),
                      selected: _radiusKm == option,
                      onSelected: (_) => setState(() => _radiusKm = option),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Categoria', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: RadarCategory.values
                  .map(
                    (category) => FilterChip(
                      avatar: Icon(category.icon, color: category.color, size: 18),
                      label: Text(category.label),
                      selected: _categories.contains(category),
                      onSelected: (_) => _toggle(_categories, category),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Specie di interesse', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nasconde i luoghi dedicati ad altre specie. Quelli che non la '
              'indicano restano visibili.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: radarSpeciesOptions.entries
                  .map(
                    (entry) => FilterChip(
                      label: Text(entry.value),
                      selected: _species.contains(entry.key),
                      onSelected: (_) => _toggle(_species, entry.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _categories.clear();
                    _species.clear();
                  }),
                  child: const Text('Azzera'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    RadarFilters(radiusKm: _radiusKm, categories: _categories, species: _species),
                  ),
                  child: const Text('Applica'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
