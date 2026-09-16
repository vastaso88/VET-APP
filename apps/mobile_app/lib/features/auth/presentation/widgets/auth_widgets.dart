import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

const _kAuthContentMaxWidth = 520.0;

enum AuthBannerStatus {
  info,
  loading,
  success,
  error,
}

/// A single warm card holding title, subtitle and page-specific content.
/// Every auth screen (hub, login, register, reset) shares this shell so the
/// primary action is always the first and only button the user sees.
class AuthScreenScaffold extends StatelessWidget {
  const AuthScreenScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF5F9F7),
              Color(0xFFE7F2EE),
              Color(0xFFD7EAE2),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kAuthContentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BrandRow(
                      onBack: Navigator.of(context).canPop()
                          ? () => Navigator.of(context).pop()
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A163A35),
                            blurRadius: 28,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.display.copyWith(fontSize: 28)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(subtitle, style: AppTextStyles.body),
                          const SizedBox(height: AppSpacing.xl),
                          child,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthStateBanner extends StatelessWidget {
  const AuthStateBanner({
    super.key,
    required this.status,
    required this.title,
    required this.message,
  });

  final AuthBannerStatus status;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      AuthBannerStatus.info => (
          background: const Color(0xFFE1F0EA),
          foreground: const Color(0xFF315E55),
          icon: Icons.info_rounded,
        ),
      AuthBannerStatus.loading => (
          background: const Color(0xFFF6E9D9),
          foreground: const Color(0xFF8B5B3E),
          icon: Icons.hourglass_top_rounded,
        ),
      AuthBannerStatus.success => (
          background: const Color(0xFFDDEDE8),
          foreground: const Color(0xFF2D6B60),
          icon: Icons.check_circle_rounded,
        ),
      AuthBannerStatus.error => (
          background: const Color(0xFFF6DDE0),
          foreground: const Color(0xFF8A3F4A),
          icon: Icons.error_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(colors.icon, color: colors.foreground, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.foreground.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthInputField extends StatelessWidget {
  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final List<String>? autofillHints;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
        onPressed: onTap,
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, size: 8, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'VET APP',
                style: AppTextStyles.caption.copyWith(color: AppColors.onPrimary, letterSpacing: 0.4),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (onBack != null)
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Indietro'),
          ),
      ],
    );
  }
}
