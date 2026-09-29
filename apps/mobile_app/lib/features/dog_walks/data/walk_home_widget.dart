import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../../app/router/app_router.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_models.dart';
import '../../reminders/presentation/pages/reminders_pages.dart';
import '../presentation/pages/active_walk_page.dart';
import 'home_widget_action_store.dart';

const _petsDataKey = 'dog_walks_widget_pets';
const _petsTotalKey = 'dog_walks_widget_total';
const _androidProviderName = 'DogWalksWidgetProvider';

/// Cap matches the 4 pet rows laid out in
/// android/app/src/main/res/layout/dog_walks_widget.xml - RemoteViews has no
/// scrollable list without a heavier RemoteViewsService adapter, so a fixed
/// row count is the pragmatic tradeoff for a home-screen glance widget. The
/// real total is saved too, so the widget can say "+N altri".
const _maxWidgetPets = 4;

/// Species are stored as the Italian label from PetDemoStore.speciesOptions.
@visibleForTesting
bool isDogSpecies(String species) => species.trim().toLowerCase() == 'cane';

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
