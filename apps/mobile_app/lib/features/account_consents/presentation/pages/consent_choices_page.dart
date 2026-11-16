import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/crash/crash_reporting.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../data/account_consents_remote_data_source.dart';
import '../../domain/account_consent_models.dart';
import '../../domain/consent_availability.dart';

/// "Cosa vuoi attivare?": the optional consents, asked once, right after the
/// account is created and before the tutorial. Every switch starts off, the
/// text under it is the catalogue's (the same as in Settings, one decision
/// stored once). "Salva le scelte" records only what was switched on, "Non ora"
/// records nothing and the page does not come back on its own.
///
/// It pops by itself, showing nothing, when there is no switch to offer (a
/// minor in a build with no error reports) or the texts cannot be read.
class ConsentChoicesPage extends StatefulWidget {
  const ConsentChoicesPage({
    super.key,
    required this.isAdult,
    this.dataSource,
    this.diagnosticsAvailable,
  });

  /// Marketing e-mail is offered to adults only.
  final bool isAdult;
  final AccountConsentsRemoteDataSource? dataSource;

  /// Overridable for tests; by default whether this build sends error reports.
  final bool? diagnosticsAvailable;

  @override
  State<ConsentChoicesPage> createState() => _ConsentChoicesPageState();
}

class _ConsentChoicesPageState extends State<ConsentChoicesPage> {
  late final AccountConsentsRemoteDataSource _dataSource =
      widget.dataSource ?? HttpAccountConsentsRemoteDataSource();

  AccountConsentsSnapshot? _snapshot;
  final Set<String> _on = {};
  bool _saving = false;

  /// The switches offered, in order, with the label of each.
  List<String> get _keys => [
        if (widget.diagnosticsAvailable ?? CrashReporting.instance.isAvailable)
          AccountConsentKeys.diagnostics,
        if (analyticsToolExists) AccountConsentKeys.analytics,
        if (widget.isAdult) AccountConsentKeys.marketingEmail,
      ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_keys.isEmpty) {
      // Nothing to offer: step aside once the page has been built.
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
      return;
    }
    final result = await _dataSource.fetch();
    if (!mounted) return;
    result.fold(
      onSuccess: (snapshot) => setState(() => _snapshot = snapshot),
      onFailure: (_) => _leave(),
    );
  }

  void _leave() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  String _label(String key) {
    final l10n = context.l10n;
    return switch (key) {
      AccountConsentKeys.diagnostics => l10n.settingsConsentDiagnostics,
      AccountConsentKeys.analytics => l10n.settingsConsentAnalytics,
      _ => l10n.settingsConsentMarketingEmail,
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    for (final key in _keys.where(_on.contains)) {
      final result = await _dataSource.setConsent(consentKey: key, granted: true);
      if (!mounted) return;
      final failure = result.fold(onSuccess: (_) => null, onFailure: (error) => error);
      if (failure != null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        return;
      }
      if (key == AccountConsentKeys.diagnostics) {
        unawaited(CrashReporting.instance.applyConsent(true));
      }
    }
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = _snapshot;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: snapshot == null
            ? const Center(child: PetLoader())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(l10n.consentChoicesTitle, style: AppTextStyles.heading),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.consentChoicesSubtitle, style: AppTextStyles.body),
                  const SizedBox(height: AppSpacing.lg),
                  for (final key in _keys)
                    _ChoiceTile(
                      key: ValueKey('consent-choice-$key'),
                      title: _label(key),
                      text: snapshot.catalog[key]?.text ?? '',
                      value: _on.contains(key),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                value ? _on.add(key) : _on.remove(key);
                              }),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  // Same weight on purpose: nothing pushes towards "yes".
                  OutlinedButton(
                    key: const ValueKey('consent-choices-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(l10n.consentChoicesSave),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    key: const ValueKey('consent-choices-not-now'),
                    onPressed: _saving ? null : _leave,
                    child: Text(l10n.consentChoicesNotNow),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.title,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String text;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: AppTextStyles.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(text, style: AppTextStyles.bodySmall),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
