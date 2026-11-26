import 'package:flutter/widgets.dart';

import '../../design_system/tokens/app_colors.dart';

/// Keeps [AppColors] on the palette of the phone's light or dark setting.
///
/// Widgets read their colours through AppColors, without a BuildContext, so
/// the palette is chosen here from the same value MaterialApp uses for
/// `ThemeMode.system`. When the phone switches while the app is open, every
/// element below is rebuilt at once: no page keeps a colour of the other theme.
class PhonePalette extends StatefulWidget {
  const PhonePalette({super.key, required this.builder});

  /// Builds the app (its MaterialApp) on the palette in use.
  final WidgetBuilder builder;

  @override
  State<PhonePalette> createState() => _PhonePaletteState();
}

class _PhonePaletteState extends State<PhonePalette> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _usePhoneBrightness();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Whether the palette changed.
  bool _usePhoneBrightness() {
    final palette = AppColors.paletteFor(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    if (identical(palette, AppColors.palette)) return false;
    AppColors.use(palette);
    return true;
  }

  @override
  void didChangePlatformBrightness() {
    if (!_usePhoneBrightness() || !mounted) return;
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
