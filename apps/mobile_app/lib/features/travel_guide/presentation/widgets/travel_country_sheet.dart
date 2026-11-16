import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/travel_countries.dart';

/// The search sheet to pick a country: type a few letters, tap the country.
Future<TravelCountry?> showTravelCountrySheet(BuildContext context, {TravelCountry? selected}) {
  return showModalBottomSheet<TravelCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    builder: (_) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.selected});

  final TravelCountry? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = searchTravelCountries(_query);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.aroundWorldCountryHint,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(child: Text(l10n.aroundWorldCountryNone, style: AppTextStyles.bodySmall))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final country = results[index];
                          return ListTile(
                            leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                            title: Text(country.name),
                            selected: country.code == widget.selected?.code,
                            onTap: () => Navigator.of(context).pop(country),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
