import 'dart:async';

import 'package:flutter/material.dart';

import '../formatters/date_input_formatter.dart';

/// A hand-typed `gg/mm/aaaa` field (digits format themselves, "/" is inserted
/// by [DateInputFormatter]) with two behaviours that make a proposed value easy
/// to replace:
///
/// * The first tap on a field that holds the value proposed by the form empties
///   it, so the owner types the date from scratch instead of fighting the old
///   digits.
/// * Leaving the field without typing anything puts the proposed value back.
///
/// A value the owner typed or picked from the calendar is theirs: tapping the
/// field again leaves it alone. The calendar button (see [onPick]) keeps working
/// as before.
class TypedDateField extends StatefulWidget {
  const TypedDateField({
    required this.controller,
    required this.decoration,
    required this.onPick,
    required this.pickIcon,
    this.validator,
    this.style,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  /// Opens the calendar and writes the picked date into [controller].
  final FutureOr<void> Function() onPick;

  /// Icon of the calendar button shown at the end of the field.
  final Widget pickIcon;

  @override
  State<TypedDateField> createState() => _TypedDateFieldState();
}

class _TypedDateFieldState extends State<TypedDateField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  /// The proposed value taken away on focus, to give back if nothing is typed.
  String? _proposed;

  /// True once the owner typed or picked a date: from then on it is not a
  /// proposal any more and focusing the field no longer clears it.
  bool _ownerChoseValue = false;

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final controller = widget.controller;
    if (_focus.hasFocus) {
      if (!_ownerChoseValue && controller.text.isNotEmpty) {
        _proposed = controller.text;
        controller.clear();
      }
      return;
    }
    final proposed = _proposed;
    if (proposed != null && controller.text.isEmpty) {
      controller.text = proposed;
    }
    _proposed = null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      inputFormatters: const [DateInputFormatter()],
      validator: widget.validator,
      style: widget.style,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(onPressed: _pick, icon: widget.pickIcon),
      ),
      onChanged: (value) {
        _ownerChoseValue = true;
        _proposed = null;
        widget.onChanged?.call(value);
      },
    );
  }

  /// Runs the calendar and records whether it changed the date, so a chosen
  /// date is treated as the owner's, not as a proposal.
  Future<void> _pick() async {
    final baseline = _proposed ?? widget.controller.text;
    await widget.onPick();
    if (widget.controller.text != baseline) {
      _ownerChoseValue = true;
      _proposed = null;
    }
  }
}
