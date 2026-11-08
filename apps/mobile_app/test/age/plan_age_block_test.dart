import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/age/presentation/age_flow.dart';
import 'package:vet_app_mobile/features/billing/data/subscription_remote_data_source.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';

Future<String?> _selectPlanCode(int status, String body) async {
  final source = HttpSubscriptionRemoteDataSource(
    client: MockClient((request) async => http.Response(body, status)),
  );
  final result = await source.selectPlan(PlanTier.plus);
  return result.fold(onSuccess: (_) => null, onFailure: (error) => error.code);
}

void main() {
  test('the two age refusals of select-plan keep their code', () async {
    expect(await _selectPlanCode(403, '{"code":"age_required"}'), 'age_required');
    expect(await _selectPlanCode(403, '{"code":"guardian_required"}'), 'guardian_required');
  });

  test('any other refusal stays a generic http error', () async {
    expect(
      await _selectPlanCode(403, '{"code":"plan_limit_reached"}'),
      'subscription_select_plan_http_403',
    );
    expect(await _selectPlanCode(403, 'not json'), 'subscription_select_plan_http_403');
    expect(
        await _selectPlanCode(500, '{"code":"age_required"}'), 'subscription_select_plan_http_500');
  });

  test('only the two age codes count as an age block', () async {
    final age = await _selectPlanCode(403, '{"code":"age_required"}');
    expect(age, isNotNull);
    final source = HttpSubscriptionRemoteDataSource(
      client: MockClient((request) async => http.Response('{"code":"guardian_required"}', 403)),
    );
    final error = (await source.selectPlan(PlanTier.pro)).fold(
      onSuccess: (_) => null,
      onFailure: (error) => error,
    );
    expect(isAgePlanBlock(error!), isTrue);
  });
}
