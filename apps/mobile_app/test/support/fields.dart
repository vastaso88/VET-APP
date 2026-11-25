import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/shared/widgets/app_field.dart';

/// The text field the app writes [label] above (AppField).
Finder fieldNamed(String label) => find.descendant(
      of: find.widgetWithText(AppField, label),
      matching: find.byType(TextFormField),
    );

/// The field that opens a choice, under its [label].
Finder pickerNamed(String label) => find.descendant(
      of: find.widgetWithText(AppField, label),
      matching: find.byType(PickerField),
    );
