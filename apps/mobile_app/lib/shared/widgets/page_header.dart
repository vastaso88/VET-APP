import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/atoms/outline_icon_button.dart';
import '../../design_system/tokens/app_spacing.dart';
import '../../design_system/tokens/app_text_styles.dart';
import '../../l10n/l10n.dart';

/// The one header of the app's pages: the arrow in an outlined circle, the title
/// big next to it, at most a couple of round commands on the right. Either the
/// `appBar` of a Scaffold or the first thing of a page that scrolls as a whole
/// ([padding] none there). The title is never shortened for lack of room: when it
/// does not fit beside the arrow it goes below, across the full width, and no word
/// of it is broken.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
    this.showBack,
    this.onBack,
    this.root = false,
    this.padding = defaultPadding,
  });

  final String title;
  final String? subtitle;

  /// The face of the animal the page is about, before the title.
  final Widget? badge;

  /// Round commands, 48 px each ([OutlineIconButton]).
  final List<Widget> actions;

  /// Null (the default): the arrow is there when the page can be left.
  final bool? showBack;

  /// What the arrow does; by default it goes back.
  final VoidCallback? onBack;

  /// A page of the bar at the bottom: a bigger title, at the same height on all.
  final bool root;

  final EdgeInsetsGeometry padding;

  /// Room over the header, the same on the pages that scroll as a whole.
  static const top = AppSpacing.sm;

  static const defaultPadding = EdgeInsets.fromLTRB(
    AppSpacing.page,
    top,
    AppSpacing.page,
    AppSpacing.md,
  );

  static const _command = 48.0;

  /// A title is big enough already: with very large text it grows less than the
  /// rest, as the phone itself does.
  static const _maxTitleScale = 1.6;

  /// The most a Scaffold may give it: it only takes what it needs.
  @override
  Size get preferredSize => const Size.fromHeight(600);

  @override
  Widget build(BuildContext context) {
    final back = showBack ??
        (onBack != null || (ModalRoute.of(context)?.impliesAppBarDismissal ?? false));
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark icons in the phone's status bar, as over every light page.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding,
          // The title is measured: again when the app's own font arrives.
          child: ListenableBuilder(
            listenable: PaintingBinding.instance.systemFonts,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) => _build(context, constraints.maxWidth, back),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build(BuildContext context, double width, bool back) {
    final style =
        root ? AppTextStyles.display.copyWith(fontSize: 28) : AppTextStyles.heading;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxTitleScale);
    var beside = width - actions.length * _command;
    if (back) beside -= _command + AppSpacing.sm;
    if (badge != null) beside -= _command + AppSpacing.sm;
    final inRow = _fits(context, style, scaler, beside);

    final hasRow = inRow || back || badge != null || actions.isNotEmpty;
    final titleText = Semantics(
      header: true,
      // As an AppBar does: the reader says the page when it opens.
      namesRoute: switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.macOS => null,
        _ => true,
      },
      child: Text(
        title,
        style: style,
        textScaler: inRow ? scaler : _wordFits(context, style, scaler, width),
        // What people write (a listing, an event) has no limit of its own.
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasRow)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _command),
            child: Row(
              children: [
                if (back) ...[
                  OutlineIconButton(
                    tooltip: context.l10n.commonBack,
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    icon: Icons.arrow_back_rounded,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (badge != null) ...[badge!, const SizedBox(width: AppSpacing.sm)],
                if (inRow) Expanded(child: titleText) else const Spacer(),
                ...actions,
              ],
            ),
          ),
        if (!inRow) ...[
          if (hasRow) const SizedBox(height: AppSpacing.sm),
          titleText,
        ],
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle!, style: AppTextStyles.bodySmall),
        ],
      ],
    );
  }

  double _widestWord(BuildContext context, TextStyle style, TextScaler scaler) => title
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => TextPainter.computeWidth(
            text: TextSpan(text: word, style: DefaultTextStyle.of(context).style.merge(style)),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          ))
      .fold<double>(0, math.max);

  /// The text grows as far as its longest word stays whole; it is never made
  /// smaller than its own size (or than the phone asks, if it asks for less).
  TextScaler _wordFits(BuildContext context, TextStyle style, TextScaler scaler, double width) {
    final widest = _widestWord(context, style, scaler);
    if (widest <= width) return scaler;
    final size = style.fontSize!;
    final asked = scaler.scale(size) / size;
    return TextScaler.linear(math.max(math.min(1, asked), asked * width / widest * 0.99));
  }

  /// On two lines at most, no word broken.
  bool _fits(BuildContext context, TextStyle style, TextScaler scaler, double width) {
    if (width <= 0) return false;
    if (_widestWord(context, style, scaler) > width) return false;
    final painter = TextPainter(
      text: TextSpan(text: title, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 2,
    )..layout(maxWidth: width);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}
