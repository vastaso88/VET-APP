import 'dart:async';

import 'package:flutter/widgets.dart' show Route;

import '../../features/account/presentation/pages/profile_edit_page.dart';
import '../../features/billing/presentation/pages/billing_page.dart';
import '../../features/chat/data/chat_demo_store.dart';
import '../../features/dog_walks/data/active_walk_controller.dart';
import '../../features/dog_walks/presentation/pages/active_walk_page.dart';
import '../../features/chat/presentation/pages/chat_conversation_detail_page.dart';
import '../../features/events/presentation/pages/events_page.dart';
import '../../features/local_events/presentation/pages/local_events_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_page.dart';
import '../../features/medical_records/data/medical_records_repository.dart';
import '../../features/medical_records/domain/record_category.dart';
import '../../features/medical_records/presentation/pages/record_category_page.dart';
import '../../features/nearby_places/presentation/pages/data_sources_page.dart';
import '../../features/pet_news/presentation/pages/news_feed_page.dart';
import '../../features/pets/data/pet_demo_store.dart';
import '../../features/pets/domain/pet_models.dart';
import '../../features/pets/presentation/pages/gallery_folders_page.dart';
import '../../features/pets/presentation/pages/pet_detail_page.dart';
import '../../features/pets/presentation/pages/pet_gallery_page.dart';
import 'route_restoration.dart';

bool _defaultsRegistered = false;

/// The route to push for a simple page that can be restored (`news_feed`,
/// `billing`...): opens it and has it remembered. Registers the defaults first
/// if the app's bootstrap did not (widget tests).
Route<T> restorableRoute<T>(String kind) {
  if (!_defaultsRegistered) registerRestorablePages();
  return RestorablePages.instance.route<T>(kind);
}

/// How long restoring waits for the server before giving up on a page that
/// needs its data (a chat conversation is not kept on the phone).
const restoreDataTimeout = Duration(seconds: 6);

/// Registers every page that can be opened again after the app was killed in
/// the background. Pages that register themselves through a
/// [RestorationMarker] only need their rebuild recipe here; simple pages (no
/// arguments) are wrapped by the registry.
///
/// Deliberately not restored: forms and anything with a result or secret
/// (account deletion, email/password change, new pet, record upload, pickers).
void registerRestorablePages([RestorablePages? pages]) {
  final registry = pages ?? RestorablePages.instance;
  if (pages == null) _defaultsRegistered = true;

  // Attività tab.
  registry
    ..registerSimple('news_feed', () => const NewsFeedPage())
    ..registerSimple('local_events', () => const LocalEventsPage())
    ..registerSimple('events', () => const EventsPage())
    ..registerSimple('gallery_folders', () => const GalleryFoldersPage())
    ..registerSimple('marketplace', () => const MarketplacePage());

  // Impostazioni tab.
  registry
    ..registerSimple('billing', () => const BillingPage())
    ..registerSimple('data_sources', () => const DataSourcesPage())
    ..registerSimple('profile_edit', () => const ProfileEditPage());

  // Animali tab.
  registry
    ..register('pet_detail', (args) async {
      final pet = await _petById(args['petId']);
      if (pet == null) return null;
      return PetDetailPage(pet: pet, initialTab: (args['tab'] as num?)?.toInt() ?? 0);
    })
    ..register('pet_gallery', (args) async {
      final pet = await _petById(args['petId']);
      return pet == null ? null : PetGalleryPage(pet: pet);
    })
    ..register('record_category', (args) async {
      final pet = await _petById(args['petId']);
      if (pet == null) return null;
      return RecordCategoryPage(
        pet: pet,
        category: RecordCategory.fromKey(args['category']),
        repository: MedicalRecordsRepository(),
      );
    })
    // Only while that pet's walk is running (recovered after a restart first).
    ..register('active_walk', (args) async {
      final pet = await _petById(args['petId']);
      final controller = ActiveWalkController.instance;
      if (pet == null || !controller.isActive || controller.walk?.petId != pet.id) return null;
      return ActiveWalkPage(pet: pet);
    })
    ..register('chat_conversation', (args) async {
      final id = args['conversationId'];
      if (id is! String || id.isEmpty) return null;
      final store = ChatDemoStore.instance;
      if (store.conversationById(id) == null) {
        try {
          await store.ensureHydrated().timeout(restoreDataTimeout);
        } catch (_) {
          return null;
        }
      }
      // A conversation the server does not know (never sent) is not recreated:
      // opening it would invent an empty one.
      final conversation = store.conversationById(id);
      if (conversation == null) return null;
      return ChatConversationDetailPage(
        conversationId: conversation.id,
        initialConversation: conversation,
      );
    });
}

/// The pet from this phone's copy first (instant), then from the server.
Future<PetProfile?> _petById(Object? id) async {
  if (id is! String || id.isEmpty) return null;
  final store = PetDemoStore.instance;
  var pet = store.byId(id);
  if (pet != null) return pet;
  await store.restoreFromCache();
  pet = store.byId(id);
  if (pet != null) return pet;
  try {
    await store.ensureHydrated().timeout(restoreDataTimeout);
  } catch (_) {
    return null;
  }
  return store.byId(id);
}
