import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../design_system/app_text_scaler.dart';
import '../design_system/responsive.dart';
import '../features/language/data/language_store.dart';
import '../l10n/l10n.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'config/app_bootstrap_state.dart';

class VetApp extends StatefulWidget {
  const VetApp({
    super.key,
    required this.bootstrapState,
  });

  final AppBootstrapState bootstrapState;

  @override
  State<VetApp> createState() => _VetAppState();
}

class _VetAppState extends State<VetApp> {
  AppBootstrapState get bootstrapState => widget.bootstrapState;

  @override
  void initState() {
    super.initState();
    LanguageStore.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageStore.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  /// New [Locale] for the MaterialApp, then a rebuild of every element: code
  /// without a BuildContext reads strings through `appL10n`, so pages already
  /// on the navigator stack must be rebuilt to pick the new language up.
  void _onLanguageChanged() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element element) {
        element.markNeedsBuild();
        element.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: AppRouter.navigatorKey,
      scaffoldMessengerKey: AppRouter.scaffoldMessengerKey,
      locale: LanguageStore.instance.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        final rawBody = child ?? const SizedBox.shrink();

        // App text is sized via AppTextStyles' fixed fontSizes, tuned against
        // `referenceScreenWidth`, so it follows the screen width (see
        // design_system/responsive.dart). The text size the owner chose in the
        // phone's settings is kept, not replaced: the two multiply, up to
        // maxTextScaleFactor.
        final mediaQuery = MediaQuery.of(context);
        final widthFactor = (mediaQuery.size.width / referenceScreenWidth).clamp(0.85, 1.35);
        final body = MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: AppTextScaler(system: mediaQuery.textScaler, appFactor: widthFactor),
          ),
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
