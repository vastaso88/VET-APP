import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import '../../features/auth/data/auth_repository_factory.dart';
import '../../shared/config/app_runtime_config_loader.dart';
import '../router/app_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final _authRepository = const AuthRepositoryFactory().create();
  final _runtimeConfig = const AppRuntimeConfigLoader().load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreSessionAndRoute();
      }
    });
  }

  Future<void> _restoreSessionAndRoute() async {
    if (kIsWeb && !_runtimeConfig.hasSupabaseCredentials) {
      Navigator.of(context).pushReplacementNamed(AppRouter.previewDashboard);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final result = await _authRepository.restoreSession();
    if (!mounted) return;

    final destination = result.fold(
      onSuccess: (context) => context.isSignedIn && context.onboardingCompleted
          ? AppRouter.homeShell
          : AppRouter.onboardingWelcome,
      onFailure: (_) => AppRouter.onboardingWelcome,
    );

    Navigator.of(context).pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4F9F6),
              Color(0xFFE7F1EC),
              Color(0xFFD8E9E1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SplashLogo(),
              const SizedBox(height: AppSpacing.xl),
              Text('VET APP', style: AppTextStyles.heading),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Verifica sessione e preparo il tuo spazio pet.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26163A35),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: const Icon(
        Icons.pets_rounded,
        color: AppColors.onPrimary,
        size: 40,
      ),
    );
  }
}
