import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../l10n/regional_defaults.dart';

/// State of a [PhoneNumberField]: the digits typed and the country whose
/// prefix applies. The value out is always E.164 ("+393331234567") or null
/// when the field is empty — a phone number is optional everywhere.
class PhoneInputController extends ChangeNotifier {
  /// [initialStored] is a number as saved ("+393331234567", or older free
  /// text); [defaultCountry] the prefix to start from (default: the variant's
  /// own country).
  PhoneInputController({String? initialStored, String? defaultCountry})
      : _country = (defaultCountry ?? appCountryCode()).toUpperCase() {
    final stored = initialStored?.trim() ?? '';
    if (stored.isNotEmpty) {
      final parts = splitPhoneNumber(stored);
      if (parts.countryCode != null) _country = parts.countryCode!;
      text.text = parts.national;
    }
    text.addListener(_followInternationalPrefix);
  }

  final TextEditingController text = TextEditingController();
  String _country;

  String get country => _country;

  set country(String code) {
    if (code == _country) return;
    _country = code;
    notifyListeners();
  }

  /// The number in international form, or null when empty or not valid.
  String? get e164 => normalizePhoneNumber(text.text, _country);

  bool get isEmpty => text.text.trim().isEmpty;

  /// Empty is fine (optional); anything typed must be a plausible number.
  bool get isValid => isEmpty || e164 != null;

  /// Typing "+44…" switches the prefix button to the United Kingdom.
  void _followInternationalPrefix() {
    final typed = text.text.trim();
    if (!typed.startsWith('+')) return;
    final format = regionalFormatForInternationalNumber(typed);
    if (format != null) country = format.countryCode;
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

/// Optional phone number with a country-prefix picker. Every country is
/// shown with its flag, dial code and name, so the choice is recognisable at
/// a glance even when the name is in a language the owner reads poorly.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.label,
    this.helperText,
    this.enabled = true,
  });

  final PhoneInputController controller;
  final String label;
  final String? helperText;
  final bool enabled;

  OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        borderSide: BorderSide(color: color, width: width),
      );

  Future<void> _pickCountry(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _CountrySheet(selected: controller.country),
    );
    if (chosen != null) controller.country = chosen;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final format = regionalFormatFor(controller.country);
        final dial = format == null ? '' : '+${format.dialCode}';
        final countryName = appCountryName(controller.country) ?? controller.country;
        final hint =
            format == null ? '' : format.phoneHint.replaceFirst('+${format.dialCode} ', '');

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              label: context.l10n.phonePickerSemantics(countryName, format?.dialCode ?? ''),
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.medium),
                onTap: enabled ? () => _pickCountry(context) : null,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(countryFlagEmoji(controller.country),
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppSpacing.xs),
                      Text(dial, style: AppTextStyles.body.copyWith(color: AppColors.text)),
                      const Icon(Icons.arrow_drop_down_rounded, color: AppColors.mutedText),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: controller.text,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().\-/]'))],
                validator: (_) =>
                    controller.isValid ? null : context.l10n.accountProfilePhoneInvalid,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  helperText: helperText,
                  helperMaxLines: 4,
                  filled: true,
                  fillColor: AppColors.background,
                  border: _border(AppColors.border),
                  enabledBorder: _border(AppColors.border),
                  focusedBorder: _border(AppColors.primary, width: 1.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CountrySheet extends StatelessWidget {
  const _CountrySheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final countries = phoneCountriesForPicker();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text(
                context.l10n.phonePickerTitle,
                style: AppTextStyles.title.copyWith(fontSize: 17),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final format in countries)
                    ListTile(
                      selected: format.countryCode == selected,
                      selectedColor: AppColors.primary,
                      leading: Text(
                        countryFlagEmoji(format.countryCode),
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(appCountryName(format.countryCode) ?? format.countryCode),
                      trailing: Text(
                        '+${format.dialCode}',
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => Navigator.of(context).pop(format.countryCode),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
