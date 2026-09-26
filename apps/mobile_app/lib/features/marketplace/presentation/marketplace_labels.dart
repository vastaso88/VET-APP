import 'package:intl/intl.dart';

import '../../location/presentation/distance_label.dart';
import '../domain/marketplace_listing.dart';

String listingCategoryLabel(ListingCategory category) {
  switch (category) {
    case ListingCategory.food:
      return 'Cibo';
    case ListingCategory.accessories:
      return 'Accessori';
    case ListingCategory.healthWellness:
      return 'Salute e benessere';
    case ListingCategory.transportCarriers:
      return 'Trasportini';
    case ListingCategory.toys:
      return 'Giochi';
    case ListingCategory.grooming:
      return 'Toelettatura';
    case ListingCategory.other:
      return 'Altro';
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
      return 'Usurato';
  }
}

final _priceFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

String listingPriceLabel(int? priceCents) {
  if (priceCents == null) return 'Gratis';
  return _priceFormat.format(priceCents / 100);
}

String listingDistanceLabel(double? distanceMeters) {
  if (distanceMeters == null) return '';
  return formatDistance(distanceMeters);
}
