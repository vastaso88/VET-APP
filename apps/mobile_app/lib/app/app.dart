import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../design_system/responsive.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'config/app_bootstrap_state.dart';

class VetApp extends StatelessWidget {
  const VetApp({
    super.key,
    required this.bootstrapState,
  });

  final AppBootstrapState bootstrapState;

  @override
  Widget build(BuildContext context) {
    final initialRoute = !bootstrapState.supabaseEnabled && kIsWeb
        ? AppRouter.previewDashboard
        : AppRouter.splash;

    return MaterialApp(
      title: 'VET APP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      initialRoute: initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        final rawBody = child ?? const SizedBox.shrink();

        // All app text is sized via AppTextStyles' fixed fontSizes, tuned
        // against `referenceScreenWidth`. Scaling the ambient TextScaler by
        // the real screen width keeps that same proportion on narrower or
        // wider phones instead of leaving font sizes fixed regardless of
        // screen size (see design_system/responsive.dart).
        final mediaQuery = MediaQuery.of(context);
        final scale = (mediaQuery.size.width / referenceScreenWidth).clamp(0.85, 1.35);
        final body = MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.linear(scale)),
          child: rawBody,
        );

        if (bootstrapState.supabaseEnabled) {
          return body;
        }

        return Banner(
          message: kIsWeb ? 'WEB PREVIEW' : 'PREVIEW',
          location: BannerLocation.topEnd,
          child: body,
        );
      },
    );
  }
}
