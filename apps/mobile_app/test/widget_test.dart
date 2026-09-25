import 'package:flutter_test/flutter_test.dart';

import 'package:vet_app_mobile/app/app.dart';
import 'package:vet_app_mobile/app/config/app_bootstrap_state.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';

void main() {
  testWidgets('Vet app boots into dashboard preview without auth on web preview', (WidgetTester tester) async {
    await tester.pumpWidget(
      const VetApp(
        bootstrapState: AppBootstrapState(
          runtimeConfig: AppRuntimeConfig(
            environment: AppEnvironment.development,
            appName: 'Vet App',
            apiBaseUrl: 'http://127.0.0.1:8000',
            supabaseUrl: '',
            supabaseAnonKey: '',
            logLevel: 'INFO',
            enableTelemetry: false,
          ),
          supabaseEnabled: false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Prossime attività'), findsOneWidget);
    expect(find.text('Curiosità per i tuoi animali'), findsOneWidget);
    expect(find.textContaining('Verifica sessione'), findsNothing);
    expect(find.textContaining('Bentornato.'), findsNothing);
  });
}
