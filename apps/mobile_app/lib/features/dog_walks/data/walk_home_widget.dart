import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../../app/router/app_router.dart';
import '../../pets/data/pet_demo_store.dart';
import '../../pets/domain/pet_models.dart';
import '../presentation/pages/active_walk_page.dart';

const _petsDataKey = 'dog_walks_widget_pets';
const _androidProviderName = 'DogWalksWidgetProvider';

/// Cap matches the 4 slots laid out in
/// android/app/src/main/res/layout/dog_walks_widget.xml (a 2x2 grid fits the
/// requested 4x3-cell footprint) - RemoteViews has no scrollable grid
/// without a heavier RemoteViewsService adapter, so a fixed, generous slot
/// count is the pragmatic tradeoff for a home-screen glance widget.
const _maxWidgetPets = 4;

bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Pushes the owner's pets into the "Passeggiate" home-screen widget's
/// storage and asks Android to redraw it. Call whenever the pets list may
/// have changed (see pets_list_page.dart) - a no-op off Android, and
/// best-effort like the rest of this feature's persistence (a widget that
/// misses one refresh just shows slightly stale pets, not worth surfacing
/// as an error to the owner).
Future<void> syncPetsToHomeWidget(List<PetProfile> pets) async {
  if (!_isAndroid) return;

  final payload = jsonEncode([
    for (final pet in pets.take(_maxWidgetPets))
      {'id': pet.id, 'name': pet.name, 'emoji': pet.avatarEmoji},
  ]);

  try {
    await HomeWidget.saveWidgetData<String>(_petsDataKey, payload);
    await HomeWidget.updateWidget(androidName: _androidProviderName);
  } catch (_) {
    // Best-effort - see doc comment above.
  }
}

/// Wires up navigation for the widget's "tap a pet, start walking" action:
/// checks whether this launch of the app came from the widget (cold start),
/// then keeps listening for the same click while already running (warm
/// start - MainActivity is singleTop, so it's a click delivered to the
/// existing instance, not a new one). Call once from bootstrap.dart after
/// `runApp`.
void initWalkHomeWidgetLaunchHandling() {
  if (!_isAndroid) return;

  unawaited(
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWalkWidgetUri),
  );
  HomeWidget.widgetClicked.listen(_handleWalkWidgetUri);
}

Future<void> _handleWalkWidgetUri(Uri? uri) async {
  if (uri == null || uri.host != 'start_walk') return;
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

  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppRouter.navigatorKey.currentState?.push(
      MaterialPageRoute<bool>(
        builder: (_) => ActiveWalkPage(pet: matchedPet, autoStart: true),
      ),
    );
  });
}
