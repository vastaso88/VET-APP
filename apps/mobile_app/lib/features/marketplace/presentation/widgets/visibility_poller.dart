import 'dart:async';

import 'package:flutter/widgets.dart';

/// Runs [onPoll] every [interval], but only while the page that owns it can be
/// seen: no other page above it (a page that is covered stays mounted, so its
/// own timer would keep asking the server for nothing) and the app in the
/// foreground. When the page becomes visible again, or the app comes back, it
/// polls at once instead of waiting for the next tick, so what was missed shows
/// up as soon as the owner is back.
///
/// Usage in a `State`: build it once, call [attach] from `didChangeDependencies`
/// with `ModalRoute.of(context)`, and [dispose] it in `dispose`. The first
/// [attach] polls at once (the page's first read).
///
/// Visibility comes from the route's `secondaryAnimation` (it runs while a page
/// is pushed over this one or removed from it), so no `RouteObserver` has to be
/// registered on the app. A dialog above the page is not a page: the timer keeps
/// running but each tick checks `isCurrent` and skips the poll.
class VisibilityPoller with WidgetsBindingObserver {
  VisibilityPoller({required this.interval, required this.onPoll});

  final Duration interval;
  final void Function() onPoll;

  Timer? _timer;
  ModalRoute<dynamic>? _route;
  bool _observing = false;
  bool _foreground = true;
  bool _disposed = false;

  /// True while the timer runs: foreground and no page above.
  @visibleForTesting
  bool get isRunning => _timer != null;

  void attach(ModalRoute<dynamic>? route) {
    if (_disposed) return;
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
      final state = WidgetsBinding.instance.lifecycleState;
      _foreground = state == null || state == AppLifecycleState.resumed;
    }
    if (!identical(route, _route)) {
      _route?.secondaryAnimation?.removeStatusListener(_onAnimationStatus);
      _route = route;
      route?.secondaryAnimation?.addStatusListener(_onAnimationStatus);
    }
    _sync();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _route?.secondaryAnimation?.removeStatusListener(_onAnimationStatus);
    _route = null;
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _onAnimationStatus(AnimationStatus status) => _sync();

  /// No page above, not even one that is sliding in or out.
  bool get _uncovered {
    final status = _route?.secondaryAnimation?.status;
    return status == null || status == AnimationStatus.dismissed;
  }

  /// Can this page be seen right now?
  bool get _canPoll {
    final route = _route;
    return _foreground && _uncovered && (route == null || route.isCurrent);
  }

  void _sync() {
    if (_disposed) return;
    final shouldRun = _foreground && _uncovered;
    if (shouldRun && _timer == null) {
      _timer = Timer.periodic(interval, (_) {
        if (_canPoll) onPoll();
      });
      if (_canPoll) onPoll();
    } else if (!shouldRun && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
}
