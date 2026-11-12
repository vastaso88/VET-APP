/// The one place in the app that decides how a postal address is written.
///
/// Every country writes the same facts in its own order: "Via Roma 12, 20100
/// Milano", "12 Main St, Springfield, IL 62704", "Musterstraße 12, 10115
/// Berlin". This is the twin of `packages/core/domain/geo/address_format.py`
/// on the backend and is tested against the same cases
/// (test/location/address_format_test.dart).
library;

class AddressParts {
  const AddressParts({
    this.street,
    this.houseNumber,
    this.postcode,
    this.city,
    this.state,
  });

  /// From the `address` object of a Nominatim result (`addressdetails=1`).
  /// The state is the 2-3 letter code of the `ISO3166-2-lvl4` field
  /// ("US-IL" gives "IL") when there is one, which only the United States
  /// and Australia print.
  factory AddressParts.fromNominatim(Map<String, dynamic> address) {
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;
    return AddressParts(
      street: text(
        address['road'] ?? address['pedestrian'] ?? address['footway'],
      ),
      houseNumber: text(address['house_number']),
      postcode: text(address['postcode']),
      city: text(
        address['city'] ??
            address['town'] ??
            address['village'] ??
            address['municipality'] ??
            address['hamlet'],
      ),
      state: text(address['ISO3166-2-lvl4']) ?? text(address['state']),
    );
  }

  final String? street;
  final String? houseNumber;
  final String? postcode;
  final String? city;
  final String? state;
}

enum _StreetOrder { streetThenNumber, numberThenStreet }

enum _LocalityStyle {
  postcodeCity,
  cityPostcode,
  cityStatePostcode,
  cityStatePostcodeNoComma,
}

const _styles = <String, (_StreetOrder, _LocalityStyle)>{
  'IT': (_StreetOrder.streetThenNumber, _LocalityStyle.postcodeCity),
  'DE': (_StreetOrder.streetThenNumber, _LocalityStyle.postcodeCity),
  'ES': (_StreetOrder.streetThenNumber, _LocalityStyle.postcodeCity),
  'FR': (_StreetOrder.numberThenStreet, _LocalityStyle.postcodeCity),
  'GB': (_StreetOrder.numberThenStreet, _LocalityStyle.cityPostcode),
  'US': (_StreetOrder.numberThenStreet, _LocalityStyle.cityStatePostcode),
  'AU': (
    _StreetOrder.numberThenStreet,
    _LocalityStyle.cityStatePostcodeNoComma,
  ),
};

String _clean(String? value) =>
    (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

String _stateCode(String? state) {
  var text = _clean(state);
  if (text.contains('-')) {
    text = text.substring(text.lastIndexOf('-') + 1);
  }
  // A full name ("Illinois") is not abbreviated here: shown as given.
  return RegExp(r'^[A-Za-z]{2,3}$').hasMatch(text) ? text.toUpperCase() : text;
}

String _join(Iterable<String> items, String separator) =>
    items.where((item) => item.isNotEmpty).join(separator);

/// One-line address in the country's order; parts that are missing are left
/// out, and a completely empty address gives an empty string. [countryCode]
/// is ISO 3166-1 alpha-2; an unknown or null country gets the European
/// order (street number, postcode city).
String formatAddress(AddressParts parts, String? countryCode) {
  final style =
      _styles[(countryCode ?? '').toUpperCase()] ??
      (_StreetOrder.streetThenNumber, _LocalityStyle.postcodeCity);
  final street = _clean(parts.street);
  final number = _clean(parts.houseNumber);
  final city = _clean(parts.city);
  final postcode = _clean(parts.postcode);
  final state = _stateCode(parts.state);

  final streetLine = style.$1 == _StreetOrder.numberThenStreet
      ? _join([number, street], ' ')
      : _join([street, number], ' ');

  final locality = switch (style.$2) {
    _LocalityStyle.postcodeCity => _join([postcode, city], ' '),
    _LocalityStyle.cityPostcode => _join([city, postcode], ' '),
    _LocalityStyle.cityStatePostcode => _join([
      city,
      _join([state, postcode], ' '),
    ], ', '),
    _LocalityStyle.cityStatePostcodeNoComma => _join([
      city,
      state,
      postcode,
    ], ' '),
  };

  return _join([streetLine, locality], ', ');
}
