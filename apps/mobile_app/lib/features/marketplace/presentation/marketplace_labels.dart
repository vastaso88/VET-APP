import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../location/presentation/distance_label.dart';
import '../domain/marketplace_listing.dart';

String listingCategoryLabel(ListingCategory category) {
  switch (category) {
    case ListingCategory.kennelsCarriers:
      return 'Cucce, lettini e trasportini';
    case ListingCategory.leashesCollars:
      return 'Guinzagli, collari e pettorine';
    case ListingCategory.toys:
      return 'Giochi';
    case ListingCategory.clothing:
      return 'Abbigliamento';
    case ListingCategory.feeding:
      return 'Ciotole e alimentazione';
    case ListingCategory.hygieneGrooming:
      return 'Igiene e toelettatura';
    case ListingCategory.aquariumsTerrariums:
      return 'Acquari e terrari';
    case ListingCategory.cagesAviaries:
      return 'Gabbie e voliere';
    case ListingCategory.other:
      return 'Altro';
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
      return 'Nuovo';
    case ListingCondition.likeNew:
      return 'Come nuovo';
    case ListingCondition.good:
      return 'Buono';
    case ListingCondition.worn:
      return 'Usato';
  }
}

String listingSpeciesLabel(ListingSpecies species) {
  switch (species) {
    case ListingSpecies.allSpecies:
      return 'Tutte le specie';
    case ListingSpecies.dog:
      return 'Cane';
    case ListingSpecies.cat:
      return 'Gatto';
    case ListingSpecies.smallMammal:
      return 'Piccoli mammiferi';
    case ListingSpecies.bird:
      return 'Uccello';
    case ListingSpecies.reptileAmphibian:
      return 'Rettili e anfibi';
    case ListingSpecies.fish:
      return 'Pesce';
    case ListingSpecies.other:
      return 'Altro';
  }
}

final _priceFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String listingPriceLabel(int? priceCents) {
  if (priceCents == null) return 'In regalo';
  return _priceFormat.format(priceCents / 100);
}

String listingDistanceLabel(double? distanceMeters) {
  if (distanceMeters == null) return '';
  return formatDistance(distanceMeters);
}

String listingDistanceFilterLabel(double? maxDistanceKm) {
  if (maxDistanceKm == null) return 'Ovunque';
  return '${maxDistanceKm.round()} km';
}
