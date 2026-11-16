import 'dart:async';

import 'package:vet_app_mobile/features/pet_news/data/pet_news_repository.dart';

/// Runs before every test file: a failed news request is retried at once in
/// tests, so no 2-second timer outlives a widget tree.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  BackendPetNewsRepository.retryPause = Duration.zero;
  await testMain();
}
