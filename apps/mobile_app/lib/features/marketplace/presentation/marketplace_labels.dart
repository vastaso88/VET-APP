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

/// The flag emoji of an ISO 3166-1 alpha-2 country ("CH" -> the Swiss flag);
/// empty for anything else.
String countryFlag(String countryCode) {
  final code = countryCode.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
  return String.fromCharCodes(code.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41));
}

/// Whether the ad is from a country other than the owner's: near a border the
/// search also shows the ads across it.
bool isForeignListing(MarketplaceListing listing) =>
    listing.country.toUpperCase() != currentTerritory().countryCode.toUpperCase();

/// Where the ad is: the city, with the seller's flag in front when the ad is
/// from another country (the price is then in that country's currency). Null
/// when there is nothing to say.
String? listingPlaceLabel(MarketplaceListing listing) {
  final city = listing.cityLabel;
  if (!isForeignListing(listing)) return city;
  final flag = countryFlag(listing.country);
  if (city == null || city.isEmpty) return flag.isEmpty ? listing.country.toUpperCase() : flag;
  return flag.isEmpty ? city : '$flag $city';
}

String listingDistanceLabel(double? distanceMeters) {
  if (distanceMeters == null) return '';
  return formatDistance(distanceMeters);
}

String listingDistanceFilterLabel(double maxDistanceKm) {
  return formatKilometersIn(maxDistanceKm, UnitSettingsStore.instance.system);
}
