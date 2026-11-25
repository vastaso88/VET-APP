import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../formatters/date_input_formatter.dart';

/// A hand-typed `gg/mm/aaaa` field (digits format themselves, "/" is inserted
/// by [DateInputFormatter]). The date proposed by the form stays written when the
/// field is tapped, selected whole: typing replaces it, leaving keeps it (owner
/// decision of 25 November 2026).
///
/// A value the owner typed or picked from the calendar is theirs: tapping the
/// field again only puts the caret. The calendar button (see [onPick]) keeps
/// working as before.
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

  /// True once the owner typed or picked a date: from then on it is not a
  /// proposal any more and focusing the field no longer selects it.
  bool _ownerChoseValue = false;

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus || _ownerChoseValue) return;
    // After the tap has put the caret.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus || _ownerChoseValue) return;
      final controller = widget.controller;
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    });
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
        suffixIcon: IconButton(
          tooltip: context.l10n.commonOpenCalendar,
          onPressed: _pick,
          icon: widget.pickIcon,
        ),
      ),
      onChanged: (value) {
        _ownerChoseValue = true;
        widget.onChanged?.call(value);
      },
    );
  }

  /// Runs the calendar and records whether it changed the date, so a chosen
  /// date is treated as the owner's, not as a proposal.
  Future<void> _pick() async {
    final baseline = widget.controller.text;
    await widget.onPick();
    if (widget.controller.text != baseline) _ownerChoseValue = true;
  }
}
