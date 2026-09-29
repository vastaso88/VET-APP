import 'dart:async';

/// What a tap on one of the home-screen widget's pills asks the app to open.
enum HomeWidgetActionKind {
  startWalk,
  newReminder,

  /// Open the page of the walk already in progress for the pet.
  openWalk,

  /// Fallbacks for the pause/resume pill when the app had to be opened
  /// (normally the pill talks to the live isolate without any navigation).
  pauseWalk,
  resumeWalk,
}

class HomeWidgetAction {
  const HomeWidgetAction(this.kind, this.petId);

  final HomeWidgetActionKind kind;
  final String petId;

  /// Parses `homewidget://<start_walk|new_reminder|open_walk|pause_walk|resume_walk>?petId=...`
  /// (built in DogWalksWidgetProvider.kt). Null for anything else.
  static HomeWidgetAction? tryParse(Uri? uri) {
    if (uri == null) return null;
    final petId = uri.queryParameters['petId'];
    if (petId == null || petId.isEmpty) return null;
    switch (uri.host) {
      case 'start_walk':
        return HomeWidgetAction(HomeWidgetActionKind.startWalk, petId);
      case 'new_reminder':
        return HomeWidgetAction(HomeWidgetActionKind.newReminder, petId);
      case 'open_walk':
        return HomeWidgetAction(HomeWidgetActionKind.openWalk, petId);
      case 'pause_walk':
        return HomeWidgetAction(HomeWidgetActionKind.pauseWalk, petId);
      case 'resume_walk':
        return HomeWidgetAction(HomeWidgetActionKind.resumeWalk, petId);
    }
    return null;
  }
}

/// "Pending deep link" holder for the widget's pill taps.
///
/// A tap can arrive at any moment - while the splash is still restoring the
/// session and preloading (cold start), before the owner is signed in, or
/// with the app already running. Instead of trying to navigate right away
/// (and racing the splash's `pushReplacementNamed`, which swallows anything
/// pushed on top of it), the action is parked here and only consumed once the
/// home shell is mounted - which by construction means authenticated, past the
/// splash and past the paywall gate. Latest tap wins; an action nobody could
/// consume within [maxAge] (e.g. the owner never got past the login) is
/// dropped rather than fired at some later, unrelated login.
class HomeWidgetActionStore {
  HomeWidgetActionStore({
    DateTime Function()? clock,
    this.maxAge = const Duration(minutes: 2),
  }) : _clock = clock ?? DateTime.now;

  static final HomeWidgetActionStore instance = HomeWidgetActionStore();

  final DateTime Function() _clock;
  final Duration maxAge;

  Future<void> Function(HomeWidgetAction action)? _handler;
  HomeWidgetAction? _pending;
  DateTime? _pendingAt;
  bool _shellReady = false;

  bool get hasPending => _pending != null;

  /// Installs the function that actually opens the target page (navigation
  /// lives in walk_home_widget.dart so this store stays framework-free).
  void attachHandler(Future<void> Function(HomeWidgetAction action) handler) {
    _handler = handler;
    unawaited(_drain());
  }

  /// Parks [action]; consumed at once if the shell is already up.
  void submit(HomeWidgetAction action) {
    _pending = action;
    _pendingAt = _clock();
    unawaited(_drain());
  }

  /// The home shell is mounted (and so signed in and past the splash).
  void shellReady() {
    _shellReady = true;
    unawaited(_drain());
  }

  void shellGone() {
    _shellReady = false;
  }

  Future<void> _drain() async {
    final action = _pending;
    final handler = _handler;
    if (action == null || handler == null || !_shellReady) return;

    final at = _pendingAt;
    _pending = null;
    _pendingAt = null;
    if (at != null && _clock().difference(at) > maxAge) return;

    try {
      await handler(action);
    } catch (_) {
      // Best-effort: a widget shortcut that fails to open just leaves the
      // owner on the home.
    }
  }
}
