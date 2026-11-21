import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/crash/crash_reporting.dart';
import '../../../age/data/age_store.dart';
import '../../../age/domain/age_status.dart';
import '../../data/account_consents_remote_data_source.dart';
import '../../domain/account_consent_models.dart';
import '../../domain/consent_availability.dart';
import 'consent_activation.dart';

/// Whether a stored decision still counts: it was taken under the version of the
/// text that is current. After a change of the text the switch shows «Da
/// confermare» and the function stays off until it is confirmed again.
bool consentDecisionIsCurrent(ConsentDecision? decision, ConsentCatalogEntry? entry) =>
    decision != null && (entry == null || decision.version == entry.version);

/// True when there is a decision but under an older text: «Da confermare».
bool consentNeedsReconfirm(ConsentDecision? decision, ConsentCatalogEntry? entry) =>
    decision != null && !consentDecisionIsCurrent(decision, entry);

/// The optional account consents as switches, for the places outside Settings
/// (the Profile page): "Email di marketing: novità e consigli di Quokka" (adults
/// only, never pre-set), "Invia rapporti sugli errori" (only in a build that
/// sends them) and "Analisi d'uso" (only when there is a tool). Same words and
/// same stored decision as in Settings; turning one ON first shows its text and
/// asks «Attiva» / «Non ora»; turning one OFF is one tap.
class AccountConsentsGroup extends StatefulWidget {
  const AccountConsentsGroup({
    super.key,
    this.dataSource,
    this.band,
    this.diagnosticsAvailable,
  });

  final AccountConsentsRemoteDataSource? dataSource;

  /// The owner's age band; by default the account's (see [AgeStore]).
  final AgeBand? band;

  /// Overridable for tests; by default whether this build sends error reports.
  final bool? diagnosticsAvailable;

  @override
  State<AccountConsentsGroup> createState() => _AccountConsentsGroupState();
}

class _AccountConsentsGroupState extends State<AccountConsentsGroup> {
  late final AccountConsentsRemoteDataSource _dataSource =
      widget.dataSource ?? HttpAccountConsentsRemoteDataSource();

  AccountConsentsSnapshot? _snapshot;
  bool _failed = false;
  final Set<String> _saving = {};

  List<String> get _keys => [
        if (widget.diagnosticsAvailable ?? CrashReporting.instance.isAvailable)
          AccountConsentKeys.diagnostics,
        if (analyticsToolExists) AccountConsentKeys.analytics,
        if (marketingConsentOffered(widget.band ?? AgeStore.instance.status.band))
          AccountConsentKeys.marketingEmail,
      ];

  @override
  void initState() {
    super.initState();
    if (_keys.isNotEmpty) unawaited(_load());
  }

  Future<void> _load() async {
    final result = await _dataSource.fetch();
    if (!mounted) return;
    result.fold(
      onSuccess: (snapshot) => setState(() {
        _snapshot = snapshot;
        _failed = false;
      }),
      onFailure: (_) => setState(() => _failed = true),
    );
  }

  String _label(String key) {
    final l10n = context.l10n;
    return switch (key) {
      AccountConsentKeys.diagnostics => l10n.settingsConsentDiagnostics,
      AccountConsentKeys.analytics => l10n.settingsConsentAnalytics,
      _ => l10n.settingsConsentMarketingEmail,
    };
  }

  Future<void> _change(String key, bool value) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    if (value) {
      final ok = await askToActivateConsent(
        context,
        title: _label(key),
        summary: snapshot.catalog[key]?.text ?? '',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _saving.add(key));
    final result = await _dataSource.setConsent(consentKey: key, granted: value);
    if (!mounted) return;
    result.fold(
      onSuccess: (saved) {
        setState(() {
          _snapshot = saved;
          _saving.remove(key);
        });
        if (key == AccountConsentKeys.diagnostics) {
          unawaited(CrashReporting.instance.applyConsent(value));
        }
      },
      onFailure: (error) {
        setState(() => _saving.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keys;
    final snapshot = _snapshot;
    if (keys.isEmpty || _failed || snapshot == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('account-consents-group'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsSectionPermissions, style: AppTextStyles.title),
        const SizedBox(height: AppSpacing.xs),
        for (final key in keys)
          SwitchListTile(
            key: ValueKey('account-consent-$key'),
            contentPadding: EdgeInsets.zero,
            title: Text(_label(key)),
            subtitle: consentNeedsReconfirm(snapshot.decisions[key], snapshot.catalog[key])
                ? Text(
                    l10n.settingsConsentToConfirm,
                    style: AppTextStyles.caption.copyWith(color: AppColors.warning),
                  )
                : null,
            value: consentDecisionIsCurrent(snapshot.decisions[key], snapshot.catalog[key]) &&
                (snapshot.decisions[key]?.granted ?? false),
            onChanged: _saving.contains(key) ? null : (value) => unawaited(_change(key, value)),
          ),
      ],
    );
  }
}
