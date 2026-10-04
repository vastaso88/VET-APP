import 'package:flutter/material.dart';

import '../../../shared/types/result.dart';
import '../../account_consents/data/account_consents_remote_data_source.dart';
import '../data/radar_contributions_repository.dart';

const _rulesConsentKey = 'contribution_rules';

/// The contribution rules, used only when the backend text cannot be
/// loaded. Same wording as the backend's consent catalog.
const _fallbackRules = 'Segnala solo ciò che hai verificato di persona. Per le attività scrivi '
    'solo il nome dell’insegna, senza telefoni, indirizzi privati o dati di altre persone. Le '
    'segnalazioni restano in attesa finché altri utenti non le confermano. Segnalazioni false '
    'o ripetute possono portare alla sospensione dell’account. Segnalazioni e voti sono '
    'pubblicati senza il tuo nome.';

/// Runs community actions (report, vote, rate) from any screen: asks for
/// the contribution rules the first time, shows the outcome, and tells
/// the radar page to reload.
class RadarContributions {
  RadarContributions({
    RadarContributionsRepository? repository,
    AccountConsentsRemoteDataSource? consents,
    required this.onChanged,
  })  : repository = repository ?? RadarContributionsRepository(),
        _consents = consents ?? HttpAccountConsentsRemoteDataSource();

  final RadarContributionsRepository repository;
  final AccountConsentsRemoteDataSource _consents;

  /// Called after a contribution went through, so lists and map refresh.
  final VoidCallback onChanged;

  /// Same backend, different listener: lets a page plug in its own reload.
  RadarContributions reloading(VoidCallback onChanged) =>
      RadarContributions(repository: repository, consents: _consents, onChanged: onChanged);

  /// Runs [action]; if the backend answers that the rules were never
  /// accepted, shows them and retries once after acceptance. Returns
  /// whether the action succeeded.
  Future<bool> run<T>(
    BuildContext context,
    Future<Result<T>> Function() action, {
    required String Function(T value) successMessage,
  }) async {
    var result = await action();
    final needsRules = result.fold(
      onSuccess: (_) => false,
      onFailure: (error) => error.code == RadarContributionsRepository.rulesRequiredCode,
    );
    if (needsRules) {
      if (!context.mounted || !await _acceptRules(context)) {
        return false;
      }
      result = await action();
    }
    if (!context.mounted) {
      return result.isSuccess;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    return result.fold(
      onSuccess: (value) {
        messenger?.showSnackBar(SnackBar(content: Text(successMessage(value))));
        onChanged();
        return true;
      },
      onFailure: (error) {
        messenger?.showSnackBar(SnackBar(content: Text(error.message)));
        return false;
      },
    );
  }

  Future<bool> _acceptRules(BuildContext context) async {
    final snapshot = await _consents.fetch();
    final rules = snapshot.fold(
      onSuccess: (value) => value.catalog[_rulesConsentKey]?.text,
      onFailure: (_) => null,
    );
    if (!context.mounted) {
      return false;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _RulesDialog(rules: rules ?? _fallbackRules),
    );
    if (accepted != true) {
      return false;
    }
    final saved = await _consents.setConsent(consentKey: _rulesConsentKey, granted: true);
    return saved.isSuccess;
  }
}

class _RulesDialog extends StatefulWidget {
  const _RulesDialog({required this.rules});

  final String rules;

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prima di segnalare o votare'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.rules),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (value) => setState(() => _checked = value ?? false),
              title: const Text('Ho letto le regole e segnalo o voto in buona fede.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annulla')),
        FilledButton(
          onPressed: _checked ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Accetto'),
        ),
      ],
    );
  }
}
