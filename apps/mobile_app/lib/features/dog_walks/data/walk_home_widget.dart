import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../../app/router/app_router.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_models.dart';
import '../../reminders/presentation/pages/reminders_pages.dart';
import '../domain/walk_eligibility.dart';
import '../domain/walk_session.dart';
import '../presentation/pages/active_walk_page.dart';
import 'active_walk_controller.dart';
import 'home_widget_action_store.dart';

export '../domain/walk_eligibility.dart' show isDogSpecies;

const _petsDataKey = 'dog_walks_widget_pets';
const _petsTotalKey = 'dog_walks_widget_total';
const _activeWalkKey = 'dog_walks_widget_active_walk';
const _androidProviderName = 'DogWalksWidgetProvider';
const _activeWalkRouteName = 'active_walk_from_widget';

/// Native side: WalkWidgetBridge in MainActivity.kt. The widget's
/// pause/resume pill invokes `pause` / `resume` (argument: pet id) here, so
/// the walk is paused inside the live isolate without bringing the app to
/// the foreground.
const _controlChannel = MethodChannel('vetapp/home_widget_control');

/// Minimum gap between two widget refreshes caused by GPS-fix notifications.
/// The clock itself ticks natively (Chronometer), so this only bounds how
/// stale the distance can get; start / pause / resume / stop bypass it.
const activeWalkWidgetThrottle = Duration(seconds: 7);

/// Cap matches the 4 pet rows laid out in
/// android/app/src/main/res/layout/dog_walks_widget.xml - RemoteViews has no
/// scrollable list without a heavier RemoteViewsService adapter, so a fixed
/// row count is the pragmatic tradeoff for a home-screen glance widget. The
/// real total is saved too, so the widget can say "+N altri".
const _maxWidgetPets = 4;

// isDogSpecies lives in walk_eligibility.dart now (shared with the pet detail
// page's Passeggiate tab); re-exported so existing imports of it from here
// keep working.

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Pushes the owner's pets into the VetApp home-screen widget's
/// storage and asks Android to redraw it. Call whenever the pets list may
/// have changed (see pets_list_page.dart) - a no-op off Android, and
/// best-effort like the rest of this feature's persistence (a widget that
/// misses one refresh just shows slightly stale pets, not worth surfacing
/// as an error to the owner).
Future<void> syncPetsToHomeWidget(List<PetProfile> pets) async {
  if (!_isAndroid) return;

  final payload = jsonEncode([
    for (final pet in pets.take(_maxWidgetPets))
      {
        'id': pet.id,
        'name': pet.name,
        'emoji': pet.avatarEmoji,
        'species': pet.species,
        // The "Passeggiata" button is only shown for dogs.
        'isDog': isDogSpecies(pet.species),
        // Pet identity colour as a full-opacity ARGB int (avatar circle).
        'color': pet.identityColor.toARGB32() | 0xFF000000,
      },
  ]);

  try {
    await HomeWidget.saveWidgetData<String>(_petsDataKey, payload);
    await HomeWidget.saveWidgetData<String>(_petsTotalKey, '${pets.length}');
    await HomeWidget.updateWidget(androidName: _androidProviderName);
  } catch (_) {
    // Best-effort - see doc comment above.
  }
}


/// What the widget shows for the walk in progress; serialized under
/// `dog_walks_widget_active_walk` and read by DogWalksWidgetProvider.kt.
@immutable
class ActiveWalkWidgetSnapshot {
  const ActiveWalkWidgetSnapshot({
    required this.petId,
    required this.isPaused,
    required this.distanceMeters,
    required this.activeSeconds,
    required this.updatedAtMs,
  });

  /// Null when there is no walk in progress (nothing to show).
  static ActiveWalkWidgetSnapshot? fromWalk(WalkSession? walk, DateTime now) {
    if (walk == null || walk.status != WalkStatus.inProgress) return null;
    return ActiveWalkWidgetSnapshot(
      petId: walk.petId,
      isPaused: walk.isPaused,
      distanceMeters: walk.distanceMeters,
      activeSeconds: walkActiveDurationSeconds(walk, now: now),
      updatedAtMs: now.millisecondsSinceEpoch,
    );
  }

  final String petId;
  final bool isPaused;
  final double distanceMeters;
  final int activeSeconds;
  final int updatedAtMs;

  /// Changes here must reach the widget at once (walk start, pause, resume);
  /// distance / time drift is what the throttle is for.
  String get structureKey => '$petId|$isPaused';

  Map<String, Object> toJson() => {
        'petId': petId,
        'paused': isPaused,
        'distanceLabel': formatWidgetDistance(distanceMeters),
        'activeSeconds': activeSeconds,
        'updatedAtMs': updatedAtMs,
      };
}

/// "1,3 km" - Italian decimal comma, one decimal.
@visibleForTesting
String formatWidgetDistance(double meters) {
  final km = meters <= 0 ? 0.0 : meters / 1000;
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Mirrors an [ActiveWalkController] into the widget, throttled: the first
/// notification of a walk and every start / pause / resume / stop go out
/// immediately, plain distance updates at most once per [throttle] (a
/// trailing publish is scheduled so the last value is never lost).
@visibleForTesting
class ActiveWalkWidgetPublisher {
  ActiveWalkWidgetPublisher({
    required ActiveWalkController controller,
    required this.publish,
    this.throttle = activeWalkWidgetThrottle,
    DateTime Function()? clock,
  })  : _controller = controller,
        _clock = clock ?? DateTime.now;

  final ActiveWalkController _controller;

  /// Receives the snapshot to show, or null to go back to the normal layout.
  final Future<void> Function(ActiveWalkWidgetSnapshot? snapshot) publish;
  final Duration throttle;
  final DateTime Function() _clock;

  bool _attached = false;
  String? _lastKey; // structureKey of the last publish, '' when cleared
  DateTime? _lastPublishAt;
  Timer? _trailing;

  void attach() {
    if (_attached) return;
    _attached = true;
    _controller.addListener(_onChange);
    _onChange();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _controller.removeListener(_onChange);
    _trailing?.cancel();
    _trailing = null;
  }

  void _onChange() {
    final now = _clock();
    final snapshot = ActiveWalkWidgetSnapshot.fromWalk(_controller.walk, now);
    final key = snapshot?.structureKey ?? '';

    // Nothing shown and nothing to hide: don't wake the widget. The very
    // first call (_lastKey == null) still clears whatever a previous run
    // left behind.
    if (snapshot == null && _lastKey == '') return;

    if (key != _lastKey) {
      _publishNow(snapshot, now);
      return;
    }

    final last = _lastPublishAt;
    if (last == null || now.difference(last) >= throttle) {
      _publishNow(snapshot, now);
      return;
    }
    _trailing ??= Timer(throttle - now.difference(last), () {
      _trailing = null;
      if (!_attached) return;
      final at = _clock();
      _publishNow(ActiveWalkWidgetSnapshot.fromWalk(_controller.walk, at), at);
    });
  }

  void _publishNow(ActiveWalkWidgetSnapshot? snapshot, DateTime now) {
    _trailing?.cancel();
    _trailing = null;
    _lastKey = snapshot?.structureKey ?? '';
    _lastPublishAt = now;
    unawaited(publish(snapshot));
  }
}

Future<void> _publishActiveWalkToWidget(
  ActiveWalkWidgetSnapshot? snapshot,
) async {
  try {
    if (snapshot == null) {
      await HomeWidget.saveWidgetData<String?>(_activeWalkKey, null);
    } else {
      await HomeWidget.saveWidgetData<String>(
        _activeWalkKey,
        jsonEncode(snapshot.toJson()),
      );
    }
    await HomeWidget.updateWidget(androidName: _androidProviderName);
  } catch (_) {
    // Best-effort, like the pets sync above.
  }
}

/// Runs the widget's pause/resume pill inside this isolate.
Future<bool> _handleControlCall(MethodCall call) async {
  final controller = ActiveWalkController.instance;
  final petId = call.arguments;
  if (petId is! String || controller.walk?.petId != petId) return false;
  switch (call.method) {
    case 'pause':
      await controller.pause();
      return true;
    case 'resume':
      await controller.resume();
      return true;
  }
  return false;
}

ActiveWalkWidgetPublisher? _activeWalkPublisher;

/// Wires up the widget's per-pet buttons ("Passeggiata" -> new walk, "Nuovo
/// promemoria" -> reminder form). Taps are only *recorded* here, in
/// [HomeWidgetActionStore]; the home shell consumes them once it's mounted
/// (see home_shell_page.dart), so a tap during the 4s+ splash / session
/// restore / preload is neither lost nor swallowed by the splash's
/// pushReplacement.
///
/// Two entry points, one each per way the app can be started by a tap:
/// - cold start: `initiallyLaunchedFromHomeWidget` is read exactly once here;
/// - app already running (MainActivity is singleTop, so the click arrives as
///   onNewIntent): the `widgetClicked` stream.
/// Call once from bootstrap.dart after `runApp`.
void initWalkHomeWidgetLaunchHandling() {
  if (!_isAndroid) return;

  _controlChannel.setMethodCallHandler(_handleControlCall);
  _activeWalkPublisher ??= ActiveWalkWidgetPublisher(
    controller: ActiveWalkController.instance,
    publish: _publishActiveWalkToWidget,
  )..attach();

  final store = HomeWidgetActionStore.instance..attachHandler(_openWidgetAction);
  void record(Uri? uri) {
    final action = HomeWidgetAction.tryParse(uri);
    if (action != null) store.submit(action);
  }

  unawaited(HomeWidget.initiallyLaunchedFromHomeWidget().then(record));
  HomeWidget.widgetClicked.listen(record);
}

/// Opens the page for [action] on the root navigator (above the home shell).
Future<void> _openWidgetAction(HomeWidgetAction action) async {
  await PetDemoStore.instance.ensureHydrated();
  PetProfile? pet;
  for (final candidate in PetDemoStore.instance.list()) {
    if (candidate.id == action.petId) {
      pet = candidate;
      break;
    }
  }
  if (pet == null) return;
  final matchedPet = pet;

  final navigator = AppRouter.navigatorKey.currentState;
  if (navigator == null) return;

  switch (action.kind) {
    case HomeWidgetActionKind.startWalk:
      // Walks are for dogs only, whatever a stale widget still shows.
      if (!isDogSpecies(matchedPet.species)) return;
      unawaited(
        navigator.push(
          MaterialPageRoute<bool>(
            builder: (_) => ActiveWalkPage(pet: matchedPet, autoStart: true),
          ),
        ),
      );
    case HomeWidgetActionKind.openWalk:
      final controller = ActiveWalkController.instance;
      // Stale widget (walk already finished): nothing to open.
      if (!controller.isActive || controller.walk?.petId != matchedPet.id) {
        return;
      }
      // Don't stack a second copy on top of one this handler opened.
      String? topRouteName;
      navigator.popUntil((route) {
        topRouteName = route.settings.name;
        return true;
      });
      if (topRouteName == _activeWalkRouteName) return;
      unawaited(
        navigator.push(
          MaterialPageRoute<bool>(
            settings: const RouteSettings(name: _activeWalkRouteName),
            builder: (_) => ActiveWalkPage(pet: matchedPet),
          ),
        ),
      );
    case HomeWidgetActionKind.pauseWalk:
      if (ActiveWalkController.instance.walk?.petId == matchedPet.id) {
        await ActiveWalkController.instance.pause();
      }
    case HomeWidgetActionKind.resumeWalk:
      if (ActiveWalkController.instance.walk?.petId == matchedPet.id) {
        await ActiveWalkController.instance.resume();
      }
    case HomeWidgetActionKind.newReminder:
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ReminderCreatePage(petName: matchedPet.name),
          ),
        ),
      );
  }
}
