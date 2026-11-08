import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../account/presentation/widgets/account_page_scaffold.dart';
import '../../data/age_store.dart';
import '../../domain/age_status.dart';
import '../age_flow.dart';
import 'birth_date_form.dart';

/// Puts the Mercatino behind the age rules: only a declared adult gets in.
/// No date declared yet -> the date is asked here (it is mandatory for the
/// Mercatino); a declared minor -> a plain explanation (the Mercatino opens by
/// itself on the 18th birthday); a closed account -> its own page. The backend
/// refuses the same cases (403), so this is only the friendly side.
class MarketplaceAgeGate extends StatefulWidget {
  const MarketplaceAgeGate({super.key, required this.child});

  final Widget child;

  @override
  State<MarketplaceAgeGate> createState() => _MarketplaceAgeGateState();
}

class _MarketplaceAgeGateState extends State<MarketplaceAgeGate> {
  final _store = AgeStore.instance;
  bool _checking = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_check());
  }

  Future<void> _check() async {
    await _store.refresh();
    if (!mounted) return;
    setState(() => _checking = false);
    _closeIfNeeded();
  }

  void _closeIfNeeded() {
    if (_store.status.band == AgeBand.underMinimum) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showClosedAccount(context);
      });
    }
  }

  Future<void> _declare(DateTime date) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _store.declare(date);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) => setState(() => _saving = false),
      onFailure: (error) => setState(() {
        _saving = false;
        _error = error.message;
      }),
    );
    _closeIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: PetLoader()),
      );
    }
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        switch (_store.status.band) {
          case AgeBand.adult:
            return widget.child;
          case AgeBand.unknown:
            return AccountPageScaffold(
              title: l10n.ageStepTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.ageReasonMarketplace,
                    style: AppTextStyles.body.copyWith(color: AppColors.text),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.ageStepBody, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.xl),
                  BirthDateForm(onSubmit: _declare, busy: _saving, errorText: _error),
                ],
              ),
            );
          case AgeBand.minor:
            return AccountPageScaffold(
              title: l10n.ageMarketplaceTitle,
              child: Text(
                l10n.ageMarketplaceBody,
                style: AppTextStyles.body.copyWith(color: AppColors.text),
              ),
            );
          case AgeBand.underMinimum:
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: PetLoader()),
            );
        }
      },
    );
  }
}
