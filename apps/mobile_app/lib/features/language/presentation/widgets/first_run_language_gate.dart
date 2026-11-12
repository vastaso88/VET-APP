import 'package:flutter/material.dart';

import '../../data/language_store.dart';
import '../pages/language_picker_page.dart';

/// Wraps the first screen of the signed-out flow. While only one translation
/// exists (today) it is transparent; once a second one is added it shows the
/// language page once, before registration, then reveals [child].
class FirstRunLanguageGate extends StatefulWidget {
  const FirstRunLanguageGate({super.key, required this.child});

  final Widget child;

  @override
  State<FirstRunLanguageGate> createState() => _FirstRunLanguageGateState();
}

class _FirstRunLanguageGateState extends State<FirstRunLanguageGate> {
  late bool _needsChoice = LanguageStore.instance.needsFirstRunChoice;

  @override
  Widget build(BuildContext context) {
    if (!_needsChoice) return widget.child;
    return LanguagePickerPage(onChosen: () {
      if (mounted) setState(() => _needsChoice = false);
    });
  }
}
