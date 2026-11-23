import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/types/result.dart';
import '../../domain/auth_error_messages.dart';

/// Least time between two sends of the confirmation e-mail. Short enough not to annoy,
/// long enough that a nervous double tap (or a loop) cannot burn the project's hourly limit.
const kResendConfirmationWait = Duration(seconds: 60);

/// «Invia di nuovo l'e-mail»: asks for the sign-up confirmation again, with a minimum wait
/// between two sends. [startWaiting] when an e-mail has just gone out (right after sign-up).
class ResendConfirmationButton extends StatefulWidget {
  const ResendConfirmationButton({
    super.key,
    required this.email,
    required this.resend,
    this.startWaiting = false,
    this.wait = kResendConfirmationWait,
  });

  final String email;
  final Future<Result<void>> Function(String email) resend;
  final bool startWaiting;
  final Duration wait;

  @override
  State<ResendConfirmationButton> createState() => _ResendConfirmationButtonState();
}

class _ResendConfirmationButtonState extends State<ResendConfirmationButton> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWaiting) _startWaiting();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startWaiting() {
    _timer?.cancel();
    setState(() => _secondsLeft = widget.wait.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_sending || _secondsLeft > 0) return;
    setState(() {
      _sending = true;
      _feedback = null;
    });
    final result = await widget.resend(widget.email);
    if (!mounted) return;
    result.fold(
      onSuccess: (_) {
        setState(() {
          _sending = false;
          _feedbackIsError = false;
          _feedback = context.l10n.authResendSent;
        });
      },
      onFailure: (error) {
        setState(() {
          _sending = false;
          _feedbackIsError = true;
          _feedback = localizedAuthMessage(error);
        });
      },
    );
    // Wait after every attempt, a failed one included: the limit is the server's.
    _startWaiting();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final waiting = _secondsLeft > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _sending || waiting ? null : _send,
          child: Text(waiting ? l10n.authResendWait('$_secondsLeft') : l10n.authResendButton),
        ),
        if (_feedback != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _feedback!,
              key: const Key('resend_feedback'),
              style: TextStyle(
                color: _feedbackIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}
