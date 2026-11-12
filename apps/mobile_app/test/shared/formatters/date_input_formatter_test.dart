import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/shared/formatters/date_input_formatter.dart';

/// Simulates the user typing [text] at the end of [before] (replacing nothing).
TextEditingValue _typed(String before, String typedChar) {
  const formatter = DateInputFormatter();
  final oldValue = TextEditingValue(
    text: before,
    selection: TextSelection.collapsed(offset: before.length),
  );
  final raw = before + typedChar;
  return formatter.formatEditUpdate(
    oldValue,
    TextEditingValue(text: raw, selection: TextSelection.collapsed(offset: raw.length)),
  );
}

/// Simulates a backspace at [caret] in [before] (caret is the position before deleting).
TextEditingValue _backspace(String before, int caret) {
  const formatter = DateInputFormatter();
  final oldValue = TextEditingValue(
    text: before,
    selection: TextSelection.collapsed(offset: caret),
  );
  final raw = before.substring(0, caret - 1) + before.substring(caret);
  return formatter.formatEditUpdate(
    oldValue,
    TextEditingValue(text: raw, selection: TextSelection.collapsed(offset: caret - 1)),
  );
}

void main() {
  group('DateInputFormatter typing', () {
    test('typing 05052021 yields 05/05/2021', () {
      var value = const TextEditingValue();
      for (final digit in '05052021'.split('')) {
        value = _typed(value.text, digit);
      }
      expect(value.text, '05/05/2021');
      expect(value.selection.baseOffset, 10);
    });

    test('inserts a slash after the day and after the month', () {
      expect(_typed('0', '5').text, '05/');
      expect(_typed('05/0', '5').text, '05/05/');
      expect(_typed('05/05/20', '2').text, '05/05/202');
    });

    test('never exceeds 10 characters', () {
      final value = _typed('05/05/2021', '9');
      expect(value.text, '05/05/2021');
      expect(value.text.length, 10);
    });

    test('ignores non-digit characters', () {
      expect(_typed('05', 'a').text, '05/');
      expect(_typed('05/0', '-').text, '05/0');
    });
  });

  group('DateInputFormatter backspace', () {
    test('backspace on a trailing slash removes the digit before it', () {
      final value = _backspace('05/', 3);
      expect(value.text, '0');
    });

    test('backspace on a trailing slash after the month removes the month digit', () {
      final value = _backspace('05/05/', 6);
      expect(value.text, '05/0');
    });

    test('backspace on a plain digit deletes it and keeps the format', () {
      final value = _backspace('05/05/2021', 10);
      expect(value.text, '05/05/202');
    });

    test('backspace from a full date walks back one digit at a time', () {
      var value = const TextEditingValue(text: '05/05/2021', selection: TextSelection.collapsed(offset: 10));
      value = _backspace(value.text, 10);
      expect(value.text, '05/05/202');
      value = _backspace(value.text, value.text.length);
      expect(value.text, '05/05/20');
      value = _backspace(value.text, value.text.length);
      expect(value.text, '05/05/2');
    });
  });

  group('DateInputFormatter.format', () {
    test('formats partial and complete digit strings', () {
      expect(DateInputFormatter.format(''), '');
      expect(DateInputFormatter.format('0'), '0');
      expect(DateInputFormatter.format('05'), '05/');
      expect(DateInputFormatter.format('0505'), '05/05/');
      expect(DateInputFormatter.format('05052021'), '05/05/2021');
    });
  });

  group('parseStrictDate', () {
    test('parses a complete, valid date', () {
      final date = parseStrictDate('05/05/2021');
      expect(date, DateTime(2021, 5, 5));
    });

    test('rejects an incomplete date', () {
      expect(parseStrictDate('05/05'), isNull);
      expect(parseStrictDate(''), isNull);
    });

    test('rejects a day that does not exist, instead of rolling over', () {
      // DateTime(2021, 2, 31) would otherwise silently become 3 March 2021.
      expect(parseStrictDate('31/02/2021'), isNull);
    });

    test('rejects an out-of-range month', () {
      expect(parseStrictDate('05/13/2021'), isNull);
      expect(parseStrictDate('05/00/2021'), isNull);
    });

    test('accepts a leap-year 29 February', () {
      expect(parseStrictDate('29/02/2024'), DateTime(2024, 2, 29));
    });

    test('rejects 29 February on a non-leap year', () {
      expect(parseStrictDate('29/02/2023'), isNull);
    });
  });

  group('formatDateForInput', () {
    test('pads day and month to two digits', () {
      expect(formatDateForInput(DateTime(2021, 5, 5)), '05/05/2021');
    });

    test('round-trips through parseStrictDate', () {
      final date = DateTime(1999, 12, 31);
      expect(parseStrictDate(formatDateForInput(date)), date);
    });
  });
}
