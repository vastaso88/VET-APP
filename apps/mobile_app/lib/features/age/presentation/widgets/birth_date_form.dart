import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../../shared/widgets/app_field.dart';

/// The one question of the age step: a date of birth, typed or picked, and a
/// button. Neutral on purpose: nothing here hints at a limit. What happens
/// next is the caller's: [onSubmit] gets a real, past calendar date.
class BirthDateForm extends StatefulWidget {
  const BirthDateForm({
    super.key,
    required this.onSubmit,
    this.busy = false,
    this.errorText,
  });

  final ValueChanged<DateTime> onSubmit;
  final bool busy;

  /// A failure of the last attempt (shown under the field).
  final String? errorText;

  @override
  State<BirthDateForm> createState() => _BirthDateFormState();
}

class _BirthDateFormState extends State<BirthDateForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseStrictDate(_controller.text) ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) _controller.text = formatDateForInput(picked);
  }

  void _submit() {
    if (widget.busy || !_formKey.currentState!.validate()) return;
    widget.onSubmit(parseStrictDate(_controller.text)!);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            label: l10n.petsFormBirthDateLabel,
            child: TypedDateField(
              controller: _controller,
              onPick: _pick,
              pickIcon: Icon(Icons.calendar_month_rounded, color: AppColors.secondaryStrong),
              decoration: InputDecoration(
                hintText: appDateInputText(l10n.petsFormBirthDateHint),
                errorText: widget.errorText,
              ),
              validator: (value) {
                final raw = (value ?? '').trim();
                if (raw.isEmpty) return l10n.petsFormBirthDateRequired;
                final parsed = parseStrictDate(raw);
                if (parsed == null) return appDateInputText(l10n.petsFormBirthDateInvalid);
                if (parsed.isAfter(DateTime.now())) return l10n.petsFormBirthDateFuture;
                if (parsed.year < 1900) return appDateInputText(l10n.petsFormBirthDateInvalid);
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.ageStepCorrectionNote,
            style: AppTextStyles.caption.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: widget.busy ? null : _submit,
            child: widget.busy ? const PetLoader.small() : Text(l10n.commonContinue),
          ),
        ],
      ),
    );
  }
}
