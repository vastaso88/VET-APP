import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../shared/auth/current_owner.dart';
import '../domain/walk_session.dart';
import 'dog_walks_repository.dart';

/// The finished walks of one pet as the "Passeggiate" tab shows them, with
/// the rule agreed for the whole app: every tap answers at once. Starring a
/// walk or deleting it changes [walks] on the spot, the repository write
/// runs behind it, and only if that write is refused the edit is undone with
/// a message. A reload never empties the list - the previous walks stay on
/// screen until the fresh ones arrive (owner report, 2026-10-05: actions
/// that took seconds with no feedback looked broken).
class WalkHistoryController extends ChangeNotifier {
  WalkHistoryController({
    required this.petId,
    required DogWalksRepository repository,
    String Function()? ownerIdResolver,
    void Function(String message)? onMessage,
  })  : _repository = repository,
        _ownerIdResolver = ownerIdResolver ?? resolveCurrentOwnerId,
        _onMessage = onMessage ?? _showSnackBar {
    DogWalksRepository.changes.addListener(refresh);
  }

  final String petId;
  final DogWalksRepository _repository;
  final String Function() _ownerIdResolver;
  final void Function(String message) _onMessage;

  List<WalkSession>? _walks;
  int _loadToken = 0;
  Future<void>? _loading;
  bool _disposed = false;

  /// Newest first; null only until the very first load completes.
  List<WalkSession>? get walks => _walks;

  /// Resolves when the load in flight (or the last one) has finished.
  Future<void> get settled => _loading ?? Future<void>.value();

  /// Reloads in the background. Only the newest reload may publish its
  /// result, so an older, slower one can never undo what a later action or
  /// reload already showed.
  Future<void> refresh() {
    final token = ++_loadToken;
    return _loading = _load().then((walks) {
      if (_disposed || token != _loadToken) return;
      _walks = walks;
      notifyListeners();
    });
  }

  Future<List<WalkSession>> _load() async {
    final ownerId = _ownerIdResolver();
    final all = await _repository.loadWalks(ownerId);
    final completed =
        all.where((walk) => walk.petId == petId && walk.status == WalkStatus.completed).toList();

    // One-time cleanup (owner request, 2026-09-30) for zero-distance walks
    // saved before the fix that stops them being saved at all
    // (walk_completion_flow.dart). Hidden right away and deleted behind the
    // scenes - nothing here waits on the remote.
    for (final walk in completed.where((walk) => walk.distanceMeters <= 0)) {
      unawaited(_repository.deleteWalk(ownerId, walk.id));
    }

    return completed.where((walk) => walk.distanceMeters > 0).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> setFavorite(WalkSession walk, bool isFavorite) async {
    final updated = walk.copyWith(isFavorite: isFavorite);
    _replace(updated);

    final stored = await _repository.saveWalk(updated, notifyFailure: false);
    if (stored) return;

    _replace(walk);
    _repository.restoreWalk(walk);
    _onMessage(
      isFavorite
          ? 'Non sono riuscito a salvare la preferita: riprova.'
          : 'Non sono riuscito a togliere la preferita: riprova.',
    );
  }

  Future<void> delete(WalkSession walk) async {
    _remove(walk.id);

    final deleted = await _repository.deleteWalk(
      _ownerIdResolver(),
      walk.id,
      notifyFailure: false,
    );
    if (deleted) return;

    _replace(walk);
    _repository.restoreWalk(walk);
    _onMessage('Non sono riuscito a eliminare la passeggiata: riprova.');
  }

  void _replace(WalkSession walk) {
    final current = _walks;
    if (current == null) return;
    final index = current.indexWhere((item) => item.id == walk.id);
    final next = List<WalkSession>.of(current);
    if (index == -1) {
      next.add(walk);
      next.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } else {
      next[index] = walk;
    }
    _publish(next);
  }

  void _remove(String walkId) {
    final current = _walks;
    if (current == null) return;
    _publish(current.where((walk) => walk.id != walkId).toList());
  }

  /// Invalidates any reload still in flight (it started before this edit and
  /// would bring the old state back) and shows [walks] now.
  void _publish(List<WalkSession> walks) {
    _loadToken++;
    _walks = walks;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    DogWalksRepository.changes.removeListener(refresh);
    super.dispose();
  }

  static void _showSnackBar(String message) {
    AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }
}
