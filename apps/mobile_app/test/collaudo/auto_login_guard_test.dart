import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/collaudo/auto_login_guard.dart';

const _ref = 'abcdefghijklmnopqrst';

String? _refusal({
  String url = 'https://$_ref.supabase.co',
  String ref = _ref,
  String email = 'col-est-home@example.com',
  String password = 'x',
  String environment = 'development',
  bool signedIn = false,
}) =>
    CollaudoAutoLoginGuard.refusal(
      supabaseUrl: url,
      twinRef: ref,
      email: email,
      password: password,
      environment: environment,
      alreadySignedIn: signedIn,
    );

void main() {
  test('the twin with a synthetic account signs in', () {
    expect(_refusal(), isNull);
  });

  test('production and retired projects are refused', () {
    expect(_refusal(url: 'https://ywbuzgwbkrmkukkpysbz.supabase.co'), isNotNull);
    expect(_refusal(ref: 'ywbuzgwbkrmkukkpysbz'), isNotNull);
    expect(_refusal(url: 'https://noulpaaonqjvprfddipn.supabase.co'), isNotNull);
  });

  test('any project other than the fixed twin is refused', () {
    expect(_refusal(url: 'https://zzzzzzzzzzzzzzzzzzzz.supabase.co'), isNotNull);
    expect(_refusal(url: 'http://$_ref.supabase.co'), isNotNull);
    expect(_refusal(ref: ''), isNotNull);
  });

  test('real accounts, production builds and open sessions are refused', () {
    expect(_refusal(email: 'someone@gmail.com'), isNotNull);
    expect(_refusal(password: ''), isNotNull);
    expect(_refusal(environment: 'production'), isNotNull);
    expect(_refusal(signedIn: true), isNotNull);
  });
}
