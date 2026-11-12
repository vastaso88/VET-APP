import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../account/presentation/widgets/account_page_scaffold.dart';
import '../../data/age_store.dart';
import '../widgets/birth_date_form.dart';

/// Asks an account that never declared a date of birth for it. Pops with the
/// new [AgeStatus] once saved, or with null on "later". [reason] says why it
/// is asked now (signing in, entering the Mercatino, choosing a plan).
class BirthDatePromptPage extends StatefulWidget {
  const BirthDatePromptPage({super.key, required this.reason, this.allowLater = true});

  final String reason;
  final bool allowLater;

  @override
  State<BirthDatePromptPage> createState() => _BirthDatePromptPageState();
}

class _BirthDatePromptPageState extends State<BirthDatePromptPage> {
  bool _busy = false;
  String? _error;

  Future<void> _save(DateTime date) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await AgeStore.instance.declare(date);
    if (!mounted) return;
    result.fold(
      onSuccess: (status) => Navigator.of(context).pop(status),
      onFailure: (error) {
        // "Already declared" means another device got there first: take what
        // the backend holds.
        if (error.code == 'age_already_declared') {
          AgeStore.instance.refresh().then((status) {
            if (mounted) Navigator.of(context).pop(status);
          });
          return;
        }
        setState(() {
          _busy = false;
          _error = error.message;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: widget.allowLater,
      child: AccountPageScaffold(
        title: l10n.ageStepTitle,
        showBack: widget.allowLater,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.reason, style: AppTextStyles.body.copyWith(color: AppColors.text)),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.ageStepBody, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.xl),
            BirthDateForm(onSubmit: _save, busy: _busy, errorText: _error),
            if (widget.allowLater) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.ageStepLater),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
