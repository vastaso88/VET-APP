import 'package:flutter/services.dart';

import '../../l10n/regional_defaults.dart';

/// Where the day, month and year go in a typed date, and which character
/// separates them: read from a numeric pattern such as `dd/MM/yyyy`,
/// `MM/dd/yyyy` or `dd.MM.yyyy` (see `appNumericDatePattern`).
class DateInputLayout {
  const DateInputLayout._(this.order, this.separator);

  /// 'd', 'M', 'y' in the order they are typed.
  final List<String> order;
  final String separator;

  /// The layout of [pattern]; null = the chosen variant's country.
  factory DateInputLayout.of([String? pattern]) {
    final value = pattern ?? appNumericDatePattern();
    final order = [
      for (final field in value.split(RegExp(r'[^A-Za-z]+')))
        if (field.isNotEmpty) field[0],
    ];
    final separator = RegExp(r'[^A-Za-z]').firstMatch(value)?.group(0) ?? '/';
    return DateInputLayout._(order.length == 3 ? order : const ['d', 'M', 'y'], separator);
  }

  /// Digits taken by the field at [index] (the year, always last, has four).
  int digitsOf(int index) => order[index] == 'y' ? 4 : 2;
}

/// Formats a hand-typed date while the user types digits, in the order and
/// with the separator of the chosen country (`gg/mm/aaaa`, `mm/dd/yyyy`,
/// `tt.mm.jjjj`).
///
/// Only digits are kept (max 8), and the separator is inserted after the day
/// and the month, so typing `05052021` shows `05/05/2021`. Backspace over a
/// separator removes the digit before it instead of putting the separator
/// straight back.
///
/// Use with `keyboardType: TextInputType.number` and a hint from
/// `appDateInputText`. [pattern] fixes the layout (tests); by default it
/// follows the current language variant, even if that changes at runtime.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter({this.pattern});

  final String? pattern;

  static const int maxDigits = 8;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final isDeletion = newValue.text.length < oldValue.text.length;
    var digits = _digitsOnly(newValue.text);

    if (isDeletion && digits == _digitsOnly(oldValue.text)) {
      // Only a separator was removed: drop the digit just before the caret so
      // the backspace has a visible effect.
      final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
      final digitsBeforeCaret = _digitsOnly(newValue.text.substring(0, caret)).length;
      if (digitsBeforeCaret > 0) {
        digits = digits.substring(0, digitsBeforeCaret - 1) + digits.substring(digitsBeforeCaret);
      }
    }

    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    final formatted = format(digits, pattern: pattern);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Builds `gg/mm/aaaa` (or the layout of [pattern]) from a string of digits.
  /// A separator follows a completed day or month so the next part can be
  /// typed straight away.
  static String format(String digits, {String? pattern}) {
    final layout = DateInputLayout.of(pattern);
    final firstBreak = layout.digitsOf(0);
    final secondBreak = firstBreak + layout.digitsOf(1);
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == firstBreak || i == secondBreak) buffer.write(layout.separator);
      buffer.write(digits[i]);
    }
    if (digits.length == firstBreak || digits.length == secondBreak) {
      buffer.write(layout.separator);
    }
    return buffer.toString();
  }

  static String _digitsOnly(String text) => text.replaceAll(RegExp(r'\D'), '');
}

/// Parses a complete typed date (`gg/mm/aaaa`, `mm/dd/yyyy`, `gg.mm.aaaa`:
/// the layout of [pattern], by default the chosen country's) into a real
/// calendar date, or returns null if the text is incomplete or describes a
/// date that doesn't exist (e.g. 31/02/2021 — `DateTime` would otherwise
/// silently roll that into March).
DateTime? parseStrictDate(String text, {String? pattern}) {
  final layout = DateInputLayout.of(pattern);
  final separator = RegExp.escape(layout.separator);
  final fields = [for (var i = 0; i < 3; i++) '(\\d{${layout.digitsOf(i)}})'].join(separator);
  final match = RegExp('^$fields\$').firstMatch(text.trim());
  if (match == null) return null;

  var day = 0, month = 0, year = 0;
  for (var i = 0; i < 3; i++) {
    final value = int.parse(match.group(i + 1)!);
    switch (layout.order[i]) {
      case 'd':
        day = value;
      case 'M':
        month = value;
      default:
        year = value;
    }
  }
  if (month < 1 || month > 12) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Formats [date] as the field shows it (`gg/mm/aaaa`, `mm/dd/yyyy`, ...),
/// the inverse of [parseStrictDate].
String formatDateForInput(DateTime date, {String? pattern}) {
  final layout = DateInputLayout.of(pattern);
  return layout.order
      .map((field) => switch (field) {
            'd' => date.day.toString().padLeft(2, '0'),
            'M' => date.month.toString().padLeft(2, '0'),
            _ => date.year.toString().padLeft(4, '0'),
          })
      .join(layout.separator);
}
