import 'package:flutter/services.dart';

/// Formats a hand-typed date as `gg/mm/aaaa` while the user types digits.
///
/// Only digits are kept (max 8), and "/" is inserted after day and month, so
/// typing `05052021` shows `05/05/2021`. Backspace over a "/" removes the digit
/// before it instead of putting the separator straight back.
///
/// Use with `keyboardType: TextInputType.number` and a `hintText` of `gg/mm/aaaa`.
class DateInputFormatter extends TextInputFormatter {
  const DateInputFormatter();

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

    final formatted = format(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Builds `gg/mm/aaaa` from a string of digits. A "/" follows a completed day
  /// or month so the next part can be typed straight away.
  static String format(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(digits[i]);
    }
    if (digits.length == 2 || digits.length == 4) buffer.write('/');
    return buffer.toString();
  }

  static String _digitsOnly(String text) => text.replaceAll(RegExp(r'\D'), '');
}

/// Parses a complete `gg/mm/aaaa` string into a real calendar date, or
/// returns null if the text is incomplete or describes a date that doesn't
/// exist (e.g. 31/02/2021 — `DateTime` would otherwise silently roll that
/// into March).
DateTime? parseStrictDate(String text) {
  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  if (month < 1 || month > 12) return null;

  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Formats [date] as `gg/mm/aaaa`, the inverse of [parseStrictDate].
String formatDateForInput(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year.toString().padLeft(4, '0')}';
