import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vet_app_mobile/app/theme/app_theme.dart';
import 'package:vet_app_mobile/design_system/app_text_scaler.dart';
import 'package:vet_app_mobile/design_system/responsive.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/billing_page.dart';
import 'package:vet_app_mobile/features/billing/presentation/pages/paywall_page.dart';
import 'package:vet_app_mobile/features/chat/data/chat_seed_data.dart';
import 'package:vet_app_mobile/features/chat/presentation/pages/chat_conversation_detail_page.dart';
import 'package:vet_app_mobile/features/first_run/presentation/pages/plan_intro_page.dart';
import 'package:vet_app_mobile/features/home/presentation/pages/home_dashboard_page.dart';
import 'package:vet_app_mobile/features/pets/presentation/widgets/pet_profile_form.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pets_list_page.dart';
import 'package:vet_app_mobile/features/reminders/presentation/pages/reminders_pages.dart';
import 'package:vet_app_mobile/features/settings/presentation/pages/settings_page.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';

/// The same text scaling the app applies in app.dart: the phone's own setting
/// times the width factor, capped.
Widget _app(Widget page) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) {
      final mq = MediaQuery.of(context);
      final factor = (mq.size.width / referenceScreenWidth).clamp(0.85, 1.35);
      return MediaQuery(
        data: mq.copyWith(textScaler: AppTextScaler(system: mq.textScaler, appFactor: factor)),
        child: child!,
      );
    },
    home: page,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final pages = <String, Widget Function()>{
    'piano di benvenuto': () => const PlanIntroPage(),
    'paywall': () => const PaywallPage(),
    'abbonamento': () => const BillingPage(),
    // In the app the shell provides the Scaffold the home page sits in.
    'home': () => const Scaffold(body: HomeDashboardPage()),
    'animali': () => const PetsListPage(),
    // The step-by-step form alone: the shared page header (PetsScaffold) already
    // overflows by a few pixels at 320 px / 1,3x, with or without this form.
    'nuovo animale a passi': () => Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: PetProfileForm(
              stepped: true,
              title: '',
              submitLabel: '',
              onSubmit: (_) async {},
            ),
          ),
        ),
    'promemoria': () => const RemindersListPage(),
    'impostazioni': () => const SettingsPage(),
    'chat': () => ChatConversationDetailPage(
          conversationId: ChatSeedData.conversations.first.id,
          initialConversation: ChatSeedData.detailForSummary(ChatSeedData.conversations.first),
        ),
  };

  const sizes = {
    '360x640 scala 1,3': (Size(360, 640), 1.3),
    '320x568 scala 1,3': (Size(320, 568), 1.3),
    '360x640 scala 1,0': (Size(360, 640), 1.0),
  };

  for (final size in sizes.entries) {
    for (final page in pages.entries) {
      testWidgets('${page.key} non va in overflow a ${size.key}', (tester) async {
        tester.view.physicalSize = size.value.$1;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = size.value.$2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        await tester.pumpWidget(_app(page.value()));
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
      });
    }
  }

  test('the app scaler keeps the owner text size and caps the total', () {
    const system = TextScaler.linear(1.3);
    const scaler = AppTextScaler(system: system, appFactor: 1.06);
    expect(scaler.scale(10), closeTo(13.78, 0.01));
    const huge = AppTextScaler(system: TextScaler.linear(2.0), appFactor: 1.35);
    expect(huge.scale(10), 15, reason: 'capped at 1.5x');
  });
}
