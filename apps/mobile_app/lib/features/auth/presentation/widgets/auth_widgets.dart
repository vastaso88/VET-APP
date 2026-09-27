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
      backgroundColor: AppColors.background,
      body: SafeArea(
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
          foreground: AppColors.info,
          icon: Icons.info_rounded,
        ),
      AuthBannerStatus.loading => (
          foreground: AppColors.warning,
          icon: Icons.hourglass_top_rounded,
        ),
      AuthBannerStatus.success => (
          foreground: AppColors.success,
          icon: Icons.check_circle_rounded,
        ),
      AuthBannerStatus.error => (
          foreground: AppColors.danger,
          icon: Icons.error_rounded,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.foreground.withValues(alpha: 0.12),
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

class AuthInputField extends StatefulWidget {
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
  State<AuthInputField> createState() => _AuthInputFieldState();
}

class _AuthInputFieldState extends State<AuthInputField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
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
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(_obscured ? Icons.visibility_off : Icons.visibility),
                tooltip: _obscured ? 'Mostra password' : 'Nascondi password',
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
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
    if (onBack == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded, size: 18),
        label: const Text('Indietro'),
      ),
    );
  }
}
