import 'dart:async';

import 'package:flutter/material.dart';

import 'warm_start_store.dart';

/// One page left open inside a shell tab, described well enough to open it
/// again after Android killed the app: what it is ([kind]) and its arguments.
class RestorableRouteEntry {
  const RestorableRouteEntry({required this.tab, required this.kind, this.args = const {}});

  factory RestorableRouteEntry.fromJson(Map<String, dynamic> json) => RestorableRouteEntry(
        tab: (json['tab'] as num).toInt(),
        kind: json['kind'] as String,
        args: Map<String, dynamic>.from((json['args'] as Map?) ?? const {}),
      );

  final int tab;
  final String kind;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => {'tab': tab, 'kind': kind, 'args': args};
}

/// Tells the pages below a shell tab's Navigator which tab they live in.
class ShellTabScope extends InheritedWidget {
  const ShellTabScope({required this.index, required super.child, super.key});

  final int index;

  static int? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellTabScope>()?.index;

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) => index != oldWidget.index;
}

/// The pages currently open in the shell's tabs, saved as the app runs so that
/// a launch after the process was killed can open them again (see
/// [RouteReplayer]). Pages join through [RestorationMarker]; the saved copy is
/// refreshed shortly after any change and at once when the app goes to the
/// background.
class RouteRestoration {
  RouteRestoration({
    WarmStartStore store = const WarmStartStore(),
    this.debounce = const Duration(milliseconds: 250),
  }) : _store = store;

  static final RouteRestoration instance = RouteRestoration();

  final WarmStartStore _store;
  final Duration debounce;
  final List<_Live> _live = [];
  Timer? _timer;
  bool _persistEnabled = false;
  AppLifecycleListener? _lifecycle;

  /// True once this run has opened (or tried to open) the saved pages; the
  /// shell may be rebuilt later in the same run and must not do it twice.
  bool planConsumed = false;

  /// Registers an open page; the result goes back to [leave]. [args] is read
  /// whenever the stack is saved, so it always reflects the page's current state.
  Object enter({
    required int tab,
    required String kind,
    required Map<String, dynamic> Function() args,
  }) {
    final live = _Live(tab, kind, args);
    _live.add(live);
    touch();
    return live;
  }

  void leave(Object token) {
    _live.remove(token);
    touch();
  }

  /// Something a saved argument depends on changed (e.g. the open card).
  void touch() {
    if (!_persistEnabled) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(persistNow()));
  }

  List<RestorableRouteEntry> snapshot() => [
        for (final live in _live)
          RestorableRouteEntry(tab: live.tab, kind: live.kind, args: _safeArgs(live)),
      ];

  static Map<String, dynamic> _safeArgs(_Live live) {
    try {
      return live.args();
    } catch (_) {
      return const {};
    }
  }

  Future<void> persistNow() {
    _timer?.cancel();
    return _store.saveStack([for (final entry in snapshot()) entry.toJson()]);
  }

  /// What the previous run left open. Read once, before [enablePersistence].
  Future<List<RestorableRouteEntry>> loadPlan() async {
    final rows = await _store.loadStack();
    final plan = <RestorableRouteEntry>[];
    for (final row in rows) {
      try {
        plan.add(RestorableRouteEntry.fromJson(row));
      } catch (_) {
        // Unreadable entry: skipped.
      }
    }
    return plan;
  }

  /// From now on the stack is saved. Only after the old plan was read, so the
  /// still-empty live list never overwrites it.
  void enablePersistence({bool watchLifecycle = true}) {
    _persistEnabled = true;
    if (watchLifecycle) {
      _lifecycle ??= AppLifecycleListener(
        onInactive: () => unawaited(persistNow()),
        onHide: () => unawaited(persistNow()),
        onPause: () => unawaited(persistNow()),
      );
    }
    touch();
  }

  /// Sign-out: nothing to come back to.
  Future<void> forget() async {
    _timer?.cancel();
    _persistEnabled = false;
    _live.clear();
    await _store.clear();
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}

class _Live {
  _Live(this.tab, this.kind, this.args);

  final int tab;
  final String kind;
  final Map<String, dynamic> Function() args;
}

/// Wrap a page in this (inside its `build`) to have it remembered while open.
/// Outside a shell tab it does nothing. [args] is evaluated when the stack is
/// saved; call [RouteRestoration.touch] when what it returns changes.
class RestorationMarker extends StatefulWidget {
  const RestorationMarker({
    required this.kind,
    required this.child,
    this.args = _noArgs,
    this.restoration,
    super.key,
  });

  static Map<String, dynamic> _noArgs() => const {};

  final String kind;
  final Map<String, dynamic> Function() args;
  final Widget child;

  /// Overridable for tests.
  final RouteRestoration? restoration;

  @override
  State<RestorationMarker> createState() => _RestorationMarkerState();
}

class _RestorationMarkerState extends State<RestorationMarker> {
  Object? _token;
  late final RouteRestoration _restoration = widget.restoration ?? RouteRestoration.instance;

  @override
  void initState() {
    super.initState();
    final tab = ShellTabScope.maybeOf(context);
    if (tab != null) {
      _token = _restoration.enter(
        tab: tab,
        kind: widget.kind,
        args: () => widget.args(),
      );
    }
  }

  @override
  void dispose() {
    final token = _token;
    if (token != null) _restoration.leave(token);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef RestoredPageBuilder = FutureOr<Widget?> Function(Map<String, dynamic> args);

/// Which page each saved [RestorableRouteEntry.kind] opens, and the way to
/// push the simple ones (no arguments) so that they are remembered.
class RestorablePages {
  RestorablePages();

  static final RestorablePages instance = RestorablePages();

  final Map<String, RestoredPageBuilder> _builders = {};
  final Map<String, Widget Function()> _simple = {};

  /// A page that registers itself with a [RestorationMarker] inside its own
  /// build; [builder] only has to recreate it from its arguments (null: can't,
  /// skip it).
  void register(String kind, RestoredPageBuilder builder) => _builders[kind] = builder;

  /// A page with no arguments: the registry wraps it in a marker itself, both
  /// when restoring and in [route].
  void registerSimple(String kind, Widget Function() page) {
    _simple[kind] = page;
    _builders[kind] = (_) => RestorationMarker(kind: kind, child: page());
  }

  bool knows(String kind) => _builders.containsKey(kind);

  FutureOr<Widget?> build(String kind, Map<String, dynamic> args) {
    final builder = _builders[kind];
    if (builder == null) return null;
    return builder(args);
  }

  /// The route to push for a registered simple page.
  Route<T> route<T>(String kind) {
    final page = _simple[kind];
    assert(page != null, 'No simple page registered for "$kind"');
    return MaterialPageRoute<T>(
      builder: (_) => RestorationMarker(kind: kind, child: page!()),
    );
  }
}

/// A restored page appears at once, as if it had always been there.
class RestoredRoute extends MaterialPageRoute<void> {
  RestoredRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;
}

/// Opens again the pages saved by the previous run, tab by tab, bottom to top.
class RouteReplayer {
  const RouteReplayer({required this.pages});

  final RestorablePages pages;

  /// Stops quietly when [isAlive] turns false, when a tab's navigator is gone,
  /// or when the owner already navigated that tab elsewhere (the top page is no
  /// longer the one restored last). An entry that cannot be rebuilt (deleted
  /// pet...) drops itself and every page above it in the same tab.
  Future<void> replay({
    required List<RestorableRouteEntry> plan,
    required NavigatorState? Function(int tab) navigatorFor,
    required bool Function() isAlive,
  }) async {
    final lastRoute = <int, Route<void>>{};
    final blocked = <int>{};
    for (final entry in plan) {
      if (!isAlive()) return;
      if (blocked.contains(entry.tab)) continue;
      Widget? page;
      try {
        page = await pages.build(entry.kind, entry.args);
      } catch (_) {
        page = null;
      }
      if (!isAlive()) return;
      final navigator = navigatorFor(entry.tab);
      final previous = lastRoute[entry.tab];
      if (page == null || navigator == null || (previous != null && !previous.isCurrent)) {
        blocked.add(entry.tab);
        continue;
      }
      final restored = page;
      // The first page of a tab only goes on an untouched tab.
      if (previous == null && navigator.canPop()) {
        blocked.add(entry.tab);
        continue;
      }
      final route = RestoredRoute(builder: (_) => restored);
      lastRoute[entry.tab] = route;
      unawaited(navigator.push(route));
      // Let the page build (and register itself) before the next one goes on top.
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
