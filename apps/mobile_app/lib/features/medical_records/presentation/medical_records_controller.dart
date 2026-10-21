import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/medical_records_repository.dart';
import '../data/pet_conditions_repository.dart';
import '../domain/pet_condition.dart';

/// What a screen of the cartella clinica shows: the records and, when
/// [conditionsPetId] is given, that pet's illnesses.
///
/// It reloads by itself whenever any record or illness is saved, changed or
/// deleted (the repositories' `changes` notifiers), keeps showing the previous
/// data while it does, and only the newest read is ever applied, so a slow
/// older read cannot bring back what was just changed. Screens listen to it
/// instead of each holding a one-shot `Future` loaded in `initState`, which
/// is what left lists and counters stale until the page was reopened.
class MedicalRecordsController extends ChangeNotifier {
  MedicalRecordsController({
    required this.repository,
    this.conditionsPetId,
    PetConditionsRepository? conditionsRepository,
  }) : _conditionsRepository = conditionsPetId == null
            ? null
            : (conditionsRepository ?? PetConditionsRepository()) {
    MedicalRecordsRepository.changes.addListener(_onRecordsChanged);
    if (_conditionsRepository != null) {
      PetConditionsRepository.changes.addListener(_onConditionsChanged);
    }
    unawaited(reload());
  }

  final MedicalRecordsRepository repository;
  final String? conditionsPetId;
  final PetConditionsRepository? _conditionsRepository;

  List<MedicalRecordEntry>? _records;
  bool _recordsFailed = false;
  List<PetConditionEntry>? _conditions;
  bool _disposed = false;
  int _recordsToken = 0;
  int _conditionsToken = 0;

  /// Null until the first read ends (or after a failed one: see [recordsFailed]).
  List<MedicalRecordEntry>? get records => _records;
  bool get recordsFailed => _recordsFailed;

  /// Null while loading or when the illnesses cannot be read, so a tile shows
  /// no number rather than a wrong zero.
  List<PetConditionEntry>? get conditions => _conditions;

  Future<void> reload() => Future.wait([_loadRecords(), _loadConditions()]);

  /// "Riprova": back to the loader until the read ends.
  Future<void> retry() {
    _records = null;
    _recordsFailed = false;
    _notify();
    return reload();
  }

  void _onRecordsChanged() => unawaited(_loadRecords());

  void _onConditionsChanged() => unawaited(_loadConditions());

  Future<void> _loadRecords() async {
    final token = ++_recordsToken;
    List<MedicalRecordEntry>? loaded;
    try {
      loaded = await repository.loadRecords();
    } catch (_) {
      loaded = null;
    }
    if (_disposed || token != _recordsToken) return;
    _records = loaded;
    _recordsFailed = loaded == null;
    notifyListeners();
  }

  Future<void> _loadConditions() async {
    final repo = _conditionsRepository;
    final petId = conditionsPetId;
    if (repo == null || petId == null) return;
    final token = ++_conditionsToken;
    List<PetConditionEntry>? loaded;
    try {
      loaded = await repo.loadForPet(petId);
    } catch (_) {
      loaded = null;
    }
    if (_disposed || token != _conditionsToken) return;
    _conditions = loaded;
    notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    MedicalRecordsRepository.changes.removeListener(_onRecordsChanged);
    if (_conditionsRepository != null) {
      PetConditionsRepository.changes.removeListener(_onConditionsChanged);
    }
    super.dispose();
  }
}
