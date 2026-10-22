import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/account_language_store.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';

class _Account implements AccountLanguageStore {
  String? remote;
  final writes = <String>[];
  Completer<String?>? pending;
  bool offline = false;

  @override
  Future<String?> read() async {
    if (offline) throw StateError('offline');
    return pending == null ? remote : await pending!.future;
  }

  @override
  Future<void> write(String languageCode, String variantId) async {
    if (offline) throw StateError('offline');
    writes.add(languageCode);
    remote = variantId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = LanguageStore.instance;
  late _Account account;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store.resetForTest();
    account = _Account();
    store.accountStore = account;
  });
  tearDown(store.resetForTest);

  test('unsupported device language falls back to Italian', () async {
    LanguageStore.deviceLocale = () => const Locale('ja');
    await store.ensureLoaded();
    expect(store.locale.languageCode, 'it');
  });

  test('Spanish device language is detected on first launch', () async {
    LanguageStore.deviceLocale = () => const Locale('es', 'MX');
    await store.ensureLoaded();
    expect(store.locale.languageCode, 'es');
  });

  test('account wins over a device preference from a previous session',
      () async {
    SharedPreferences.setMockInitialValues({'vet_app.language_variant': 'it'});
    account.remote = 'es';
    await store.ensureLoaded();
    await store.syncAfterAuthentication();
    expect(store.variant.id, 'es');
    expect(
        (await SharedPreferences.getInstance())
            .getString('vet_app.language_variant'),
        'es');
  });

  test('explicit pre-login choice wins and updates the account', () async {
    account.remote = 'it';
    await store.choose(languageVariantById('es')!);
    account.remote = 'en';
    await store.syncAfterAuthentication();
    expect(store.variant.id, 'es');
    expect(account.writes.last, 'es');
  });

  test('old accounts inherit the saved device choice', () async {
    SharedPreferences.setMockInitialValues(
        {'vet_app.language_variant': 'en-GB'});
    await store.ensureLoaded();
    await store.syncAfterAuthentication();
    expect(account.writes, ['en']);
  });

  test('a late account response cannot undo a new explicit choice', () async {
    account.pending = Completer<String?>();
    final sync = store.syncAfterAuthentication();
    await store.choose(languageVariantById('es')!);
    account.pending!.complete('it');
    await sync;
    expect(store.variant.id, 'es');
  });

  test('offline saving still persists locally', () async {
    account.offline = true;
    await store.choose(languageVariantById('es')!);
    await store.syncAfterAuthentication();
    expect(store.variant.id, 'es');
    expect(
        (await SharedPreferences.getInstance())
            .getString('vet_app.language_variant'),
        'es');
  });
}
