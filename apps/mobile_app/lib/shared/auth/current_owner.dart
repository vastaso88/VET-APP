import 'current_user.dart';

/// Fallback owner id for guest sessions (not signed in) - matches
/// packages/infrastructure/persistence/demo_seed.py's "demo-user" so
/// guest-created and server-seeded data line up in demo mode.
const _guestOwnerId = 'demo-user';

/// The id to attribute new content to (a marketplace listing, a report, a
/// dog walk). Uses the real signed-in user when there is one, and falls
/// back to the shared guest id otherwise - the app is usable without
/// signing in (see the "Ospite" home greeting).
String resolveCurrentOwnerId() => CurrentUser.get()?.id ?? _guestOwnerId;
