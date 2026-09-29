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

const _petsDataKey = 'dog_walks_widget_pets';
const _petsTotalKey = 'dog_walks_widget_total';
const _androidProviderName = 'DogWalksWidgetProvider';

/// Cap matches the 4 pet rows laid out in
/// android/app/src/main/res/layout/dog_walks_widget.xml - RemoteViews has no
/// scrollable list without a heavier RemoteViewsService adapter, so a fixed
/// row count is the pragmatic tradeoff for a home-screen glance widget. The
/// real total is saved too, so the widget can say "+N altri".
const _maxWidgetPets = 4;

/// Deep-link hosts of the widget's `homewidget://<host>?petId=...` clicks -
/// keep in sync with DogWalksWidgetProvider.kt.
const _startWalkHost = 'start_walk';
const _newReminderHost = 'new_reminder';

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

/// Wires up navigation for the widget's per-pet buttons ("Passeggiata" ->
/// new walk, "Nuovo promemoria" -> reminder form): checks whether this
/// launch of the app came from the widget (cold start), then keeps
/// listening for the same click while already running (warm start -
/// MainActivity is singleTop, so it's a click delivered to the existing
/// instance, not a new one). Call once from bootstrap.dart after `runApp`.
void initWalkHomeWidgetLaunchHandling() {
  if (!_isAndroid) return;

  unawaited(
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleHomeWidgetUri),
  );
  HomeWidget.widgetClicked.listen(_handleHomeWidgetUri);
}

Future<void> _handleHomeWidgetUri(Uri? uri) async {
  if (uri == null) return;
  final host = uri.host;
  if (host != _startWalkHost && host != _newReminderHost) return;
  final petId = uri.queryParameters['petId'];
  if (petId == null) return;

  await PetDemoStore.instance.ensureHydrated();
  PetProfile? pet;
  for (final candidate in PetDemoStore.instance.list()) {
    if (candidate.id == petId) {
      pet = candidate;
      break;
    }
  }
  if (pet == null) return;
  final matchedPet = pet;

  // Cold start: the splash is still routing (session restore, preload) and
  // will pushReplacement whatever is on top with the home shell, which would
  // swallow a page pushed now. Wait for it to hand over.
  if (!await _waitForHome()) return;

  final navigator = AppRouter.navigatorKey.currentState;
  if (navigator == null) return;
  if (host == _startWalkHost) {
    // Walks are for dogs only, whatever a stale widget still shows.
    if (!isDogSpecies(matchedPet.species)) return;
    unawaited(
      navigator.push(
        MaterialPageRoute<bool>(
          builder: (_) => ActiveWalkPage(pet: matchedPet, autoStart: true),
        ),
      ),
    );
  } else {
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => ReminderCreatePage(petName: matchedPet.name),
        ),
      ),
    );
  }
}

/// Resolves true once it's safe to push the widget's target page: at once on
/// a warm start (any in-app route on top), after the splash hands over on a
/// cold start. False if the owner ends up signed out / on the paywall /
/// password reset (nothing to open), or the splash never finishes (~20s).
Future<bool> _waitForHome() async {
  const blockedRoutes = {
    AppRouter.auth,
    AppRouter.paywall,
    AppRouter.setNewPassword,
  };
  for (var attempt = 0; attempt < 80; attempt++) {
    final navigator = AppRouter.navigatorKey.currentState;
    if (navigator != null) {
      String? topName;
      navigator.popUntil((route) {
        topName = route.settings.name;
        return true;
      });
      if (blockedRoutes.contains(topName)) return false;
      if (topName != null && topName != AppRouter.splash) return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return false;
}
