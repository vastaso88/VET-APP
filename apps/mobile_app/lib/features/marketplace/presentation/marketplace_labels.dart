import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../location/presentation/distance_label.dart';
import '../../settings/data/unit_settings_store.dart';
import '../../settings/domain/unit_conversion.dart';
import '../domain/marketplace_listing.dart';

String listingCategoryLabel(ListingCategory category) {
  switch (category) {
    case ListingCategory.kennelsCarriers:
      return appL10n.marketplaceCategoryKennelsCarriers;
    case ListingCategory.leashesCollars:
      return appL10n.marketplaceCategoryLeashesCollars;
    case ListingCategory.toys:
      return appL10n.marketplaceCategoryToys;
    case ListingCategory.clothing:
      return appL10n.marketplaceCategoryClothing;
    case ListingCategory.feeding:
      return appL10n.marketplaceCategoryFeeding;
    case ListingCategory.hygieneGrooming:
      return appL10n.marketplaceCategoryHygieneGrooming;
    case ListingCategory.aquariumsTerrariums:
      return appL10n.marketplaceCategoryAquariumsTerrariums;
    case ListingCategory.cagesAviaries:
      return appL10n.marketplaceCategoryCagesAviaries;
    case ListingCategory.other:
      return appL10n.marketplaceOther;
  }
}

IconData listingCategoryIcon(ListingCategory category) {
  switch (category) {
    case ListingCategory.kennelsCarriers:
      return Icons.bed_outlined;
    case ListingCategory.leashesCollars:
      return Icons.link_rounded;
    case ListingCategory.toys:
      return Icons.sports_baseball_outlined;
    case ListingCategory.clothing:
      return Icons.checkroom_outlined;
    case ListingCategory.feeding:
      return Icons.rice_bowl_outlined;
    case ListingCategory.hygieneGrooming:
      return Icons.shower_outlined;
    case ListingCategory.aquariumsTerrariums:
      return Icons.water_outlined;
    case ListingCategory.cagesAviaries:
      return Icons.grid_on_rounded;
    case ListingCategory.other:
      return Icons.storefront_outlined;
  }
}

String listingConditionLabel(ListingCondition condition) {
  switch (condition) {
    case ListingCondition.newItem:
      return appL10n.marketplaceConditionNew;
    case ListingCondition.likeNew:
      return appL10n.marketplaceConditionLikeNew;
    case ListingCondition.good:
      return appL10n.marketplaceConditionGood;
    case ListingCondition.worn:
      return appL10n.marketplaceConditionWorn;
  }
}

String listingSpeciesLabel(ListingSpecies species) {
  switch (species) {
    case ListingSpecies.allSpecies:
      return appL10n.marketplaceSpeciesAll;
    case ListingSpecies.dog:
      return appL10n.marketplaceSpeciesDog;
    case ListingSpecies.cat:
      return appL10n.marketplaceSpeciesCat;
    case ListingSpecies.smallMammal:
      return appL10n.marketplaceSpeciesSmallMammal;
    case ListingSpecies.bird:
      return appL10n.marketplaceSpeciesBird;
    case ListingSpecies.reptileAmphibian:
      return appL10n.marketplaceSpeciesReptileAmphibian;
    case ListingSpecies.fish:
      return appL10n.marketplaceSpeciesFish;
    case ListingSpecies.other:
      return appL10n.marketplaceOther;
  }
}

String listingPriceLabel(int? priceCents) {
  if (priceCents == null) return appL10n.marketplacePriceGift;
  return NumberFormat.currency(locale: appIntlLocale, symbol: '€').format(priceCents / 100);
}

String listingDistanceLabel(double? distanceMeters) {
  if (distanceMeters == null) return '';
  return formatDistance(distanceMeters);
}

String listingDistanceFilterLabel(double? maxDistanceKm) {
  if (maxDistanceKm == null) return appL10n.marketplaceDistanceAnywhere;
  return formatKilometersIn(maxDistanceKm, UnitSettingsStore.instance.system);
}
