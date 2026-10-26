import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../l10n/regional_defaults.dart';
import '../../location/presentation/distance_label.dart';
import '../../settings/data/unit_settings_store.dart';
import '../../settings/domain/unit_conversion.dart';
import '../../territory/domain/territory.dart';
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

/// "Gift" or the price, in the currency of the listing's country ([country],
/// default the owner's), written the way the app's language variant writes
/// money ("£15.00", "$15.00", "A$15.00", "15,00 €", "CHF 15.00"). No
/// conversion: a listing in pounds read from a euro phone stays in pounds.
String listingPriceLabel(int? priceCents, {String? country}) {
  if (priceCents == null) return appL10n.marketplacePriceGift;
  final currencyCode = country == null ? null : territoryFor(country).currencyCode;
  return formatAppMoneyCents(priceCents, currencyCode);
}

/// Label of the price field: "Prezzo (€)", "Price (£)"...
String listingPriceFieldLabel({String? country}) {
  final territory = country == null ? currentTerritory() : territoryFor(country);
  return appL10n.marketplaceFieldPrice(territory.currencySymbol);
}

String listingDistanceLabel(double? distanceMeters) {
  if (distanceMeters == null) return '';
  return formatDistance(distanceMeters);
}

String listingDistanceFilterLabel(double maxDistanceKm) {
  return formatKilometersIn(maxDistanceKm, UnitSettingsStore.instance.system);
}
