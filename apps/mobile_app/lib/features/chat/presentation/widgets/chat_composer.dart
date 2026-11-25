import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/pet_loader.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../app/launch/warm_start_store.dart';
import '../../../../shared/permissions/permission_explainer.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../../data/chat_demo_store.dart';
import '../../data/chat_remote_data_source.dart' show chatMaxMessageLength;
import '../../data/system_dictation.dart';

/// [transcribing]: the microphone is closed, the last words are on their way.
enum _VoiceState { idle, listening, transcribing }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.petName,
    this.petId,
    this.onSend,
    this.dictation,
    this.editingText,
    this.onCancelEditing,
    this.allowEmptySend = false,
    this.draftKey,
    this.controller,
  });

  final String hintText;
  final String petName;

  /// The pet's profile id, when the chat has one: the photo goes to that pet, not
  /// to whichever pet the name points to.
  final String? petId;

  /// [attachmentId] is only set once the photo finished uploading and being
  /// analyzed server-side — see [ChatDemoStore.uploadAttachment].
  final void Function(String text, {String? attachmentId, Uint8List? attachmentImageBytes})? onSend;

  /// The speech recognition of the phone or of the browser. Overridable so tests can drive
  /// the dictation without a microphone.
  final Dictation? dictation;

  /// The text of a sent message being edited: when it changes from null, it
  /// is put in the field and the composer shows it is editing. Sending then
  /// replaces that message (see ChatDemoStore.editMessage).
  final String? editingText;
  final VoidCallback? onCancelEditing;

  /// Lets an empty field be sent: an edited message that keeps only its
  /// photo.
  final bool allowEmptySend;

  /// Identifies the conversation, so the text typed and not sent survives the
  /// app being killed in the background (saved on this phone, put back here).
  final String? draftKey;

  /// The text of the field, when the page writes in it too (the example
  /// questions of an empty chat); the page then disposes it.
  final TextEditingController? controller;

  static String get listeningText => appL10n.chatListeningText;
  static String get transcribingText => appL10n.chatTranscribingText;
  static String get editingLabel => appL10n.chatEditingLabel;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Drives the pulsing dot and stop button while listening (build 28: it
  /// was not clear the microphone was listening).
  late final AnimationController _pulse;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  late final Dictation _dictation = widget.dictation ?? SystemDictation.instance;
  late final AppLifecycleListener _lifecycle;

  /// No microphone button until the phone (or the browser) says it can recognise speech.
  bool _dictationAvailable = false;

  /// Between the tap on the microphone and the listening: explanation, permission.
  bool _startingDictation = false;

  bool _hasText = false;

  /// The field holds as many characters as the backend accepts: typing or
  /// pasting stops there, and a line says why.
  bool _atLimit = false;
  _VoiceState _voiceState = _VoiceState.idle;

  Uint8List? _pendingImageBytes;
  String? _pendingAttachmentId;
  bool _uploadingAttachment = false;

  Timer? _draftTimer;

  Future<void> _restoreDraft() async {
    final key = widget.draftKey;
    if (key == null) return;
    final draft = await const WarmStartStore().loadDraft(key);
    // Only into an untouched field: never over what is being typed or edited.
    if (!mounted || draft == null || _controller.text.isNotEmpty || widget.editingText != null) {
      return;
    }
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _scheduleDraftSave() {
    final key = widget.draftKey;
    // An edited sent message is not a draft.
    if (key == null || widget.editingText != null) return;
    _draftTimer?.cancel();
    final text = _controller.text;
    _draftTimer = Timer(
      const Duration(milliseconds: 400),
      () => const WarmStartStore().saveDraft(key, text),
    );
  }

  @override
  void initState() {
    super.initState();
    // Here and not on first use: without a microphone button the first use would be dispose().
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    unawaited(_restoreDraft());
    unawaited(_lookForDictation());
    // The microphone closes when the app leaves the screen.
    _lifecycle = AppLifecycleListener(onHide: () {
      if (_voiceState == _VoiceState.listening) unawaited(_dictation.stop());
    });
    _controller.addListener(_scheduleDraftSave);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    final atLimit = _controller.text.length >= chatMaxMessageLength;
    if (hasText != _hasText || atLimit != _atLimit) {
      setState(() {
        _hasText = hasText;
        _atLimit = atLimit;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editing = widget.editingText;
    if (editing != null && editing != oldWidget.editingText) {
      _controller.value = TextEditingValue(
        text: editing,
        selection: TextSelection.collapsed(offset: editing.length),
      );
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _elapsedTimer?.cancel();
    _pulse.dispose();
    _focusNode.dispose();
    _controller.removeListener(_scheduleDraftSave);
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    _lifecycle.dispose();
    if (_voiceState != _VoiceState.idle || _startingDictation) unawaited(_dictation.cancel());
    super.dispose();
  }

  Future<void> _lookForDictation() async {
    final available = await _dictation.isAvailable();
    if (mounted && available) setState(() => _dictationAvailable = true);
  }

  void _startListeningFeedback() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _pulse.repeat(reverse: true);
  }

  void _stopListeningFeedback() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _pulse
      ..stop()
      ..value = 0;
  }

  void _cancelEditing() {
    _controller.clear();
    widget.onCancelEditing?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Not while the voice is being turned into text: the words would land in the next message.
    final canSend = (_hasText || widget.allowEmptySend) &&
        !_uploadingAttachment &&
        _voiceState == _VoiceState.idle;
    final isEditing = widget.editingText != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pendingImageBytes != null) ...[
            _PendingAttachmentChip(
              imageBytes: _pendingImageBytes!,
              isUploading: _uploadingAttachment,
              onRemove: _removeAttachment,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (isEditing) ...[
            _EditingBanner(onCancel: _cancelEditing),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_voiceState == _VoiceState.listening) ...[
            _ListeningBanner(
              pulse: _pulse,
              elapsedSeconds: _elapsedSeconds,
              onTap: _toggleDictation,
            ),
            const SizedBox(height: AppSpacing.sm),
          ] else if (_voiceState == _VoiceState.transcribing) ...[
            const _TranscribingBanner(),
            const SizedBox(height: AppSpacing.sm),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: ListenableBuilder(
              listenable: LayoutSettingsStore.instance,
              builder: (context, _) => TextField(
                controller: _controller,
                focusNode: _focusNode,
                inputFormatters: [LengthLimitingTextInputFormatter(chatMaxMessageLength)],
                minLines: 1,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15 * LayoutSettingsStore.instance.settings.chatTextSize.scale,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: _voiceState == _VoiceState.listening
                      ? context.l10n.chatListeningHint
                      : _voiceState == _VoiceState.transcribing
                          ? context.l10n.chatTranscribingHint
                          : widget.hintText,
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: const TextStyle(color: AppColors.mutedText),
                ),
              ),
            ),
          ),
          if (_atLimit) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.chatInputLimitReached(chatMaxMessageLength),
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ComposerIconButton(
                icon: Icons.add_rounded,
                tooltip: context.l10n.chatAddPhotoTooltip,
                // An edited message keeps its original photo.
                onPressed: _uploadingAttachment || isEditing ? null : _pickAndUploadImage,
              ),
              const Spacer(),
              if (_voiceState == _VoiceState.transcribing)
                const Padding(
                  padding: EdgeInsets.all(9),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: PetLoader.small(),
                  ),
                )
              else if (_dictationAvailable)
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.18).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: _ComposerIconButton(
                    icon: _voiceState == _VoiceState.listening
                        ? Icons.stop_circle_rounded
                        : Icons.mic_none_rounded,
                    tooltip: _voiceState == _VoiceState.listening
                        ? context.l10n.chatStopRecordingTooltip
                        : context.l10n.chatVoiceMessageTooltip,
                    color: _voiceState == _VoiceState.listening ? AppColors.danger : null,
                    onPressed: _toggleDictation,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              // 40 px visible, 48 px to touch (padded tap target).
              IconButton.filled(
                tooltip: context.l10n.chatSendTooltip,
                onPressed: canSend ? () => _sendMessage(_controller.text) : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 40),
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  backgroundColor: canSend ? AppColors.primary : AppColors.border,
                  disabledBackgroundColor: AppColors.border,
                  foregroundColor: AppColors.onPrimary,
                  // Beige on beige was all but invisible (X05).
                  disabledForegroundColor: AppColors.secondaryText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage(String value) {
    final message = value.trim();
    if (message.isEmpty && !widget.allowEmptySend) return;
    widget.onSend?.call(
      message,
      attachmentId: _pendingAttachmentId,
      attachmentImageBytes: _pendingImageBytes,
    );
    _controller.clear();
    setState(() {
      _pendingImageBytes = null;
      _pendingAttachmentId = null;
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;

    setState(() {
      _pendingImageBytes = bytes;
      _pendingAttachmentId = null;
      _uploadingAttachment = true;
    });

    final result = await ChatDemoStore.instance.uploadAttachment(
      petId: widget.petId,
      petName: widget.petName,
      imageBytes: bytes,
      fileName: file.name,
    );
    if (!mounted) return;
    result.fold(
      onSuccess: (attachment) {
        setState(() {
          _pendingAttachmentId = attachment.id;
          _uploadingAttachment = false;
        });
      },
      onFailure: (error) {
        setState(() {
          _pendingImageBytes = null;
          _uploadingAttachment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  void _removeAttachment() {
    setState(() {
      _pendingImageBytes = null;
      _pendingAttachmentId = null;
    });
  }

  Future<void> _toggleDictation() async {
    if (_voiceState == _VoiceState.listening) {
      await _dictation.stop();
      return;
    }
    if (_voiceState != _VoiceState.idle || _startingDictation) return;
    _startingDictation = true;
    try {
      await _startDictation();
    } finally {
      _startingDictation = false;
    }
  }

  Future<void> _startDictation() async {
    final l10n = context.l10n;
    bool? allowed = false;
    try {
      allowed = await _dictation.hasPermission();
    } catch (_) {
      // Not known to be allowed: it is explained and asked.
    }
    if (!mounted) return;
    if (allowed != true) {
      // Before the system's own dialog: why the microphone, and what happens without it.
      // "Non ora" asks nothing. A browser does not say what was decided: explained once.
      final proceed = await explainPermission(
        context,
        PermissionPurpose.microphone,
        onlyFirstTime: allowed == null,
      );
      if (!proceed || !mounted) return;
    }
    final access = await _dictation.prepare();
    if (!mounted) return;
    switch (access) {
      case DictationAccess.ready:
        break;
      case DictationAccess.refused:
        _showMessage(l10n.chatMicPermissionNeeded);
        return;
      case DictationAccess.unavailable:
        // No speech recognition on this phone after all: no button, no error.
        setState(() => _dictationAvailable = false);
        return;
      case DictationAccess.failed:
        _showMessage(l10n.chatMicStartFailed);
        return;
    }
    setState(() => _voiceState = _VoiceState.listening);
    _startListeningFeedback();
    try {
      await _dictation.start(
        // The app's language, with its country when the owner picked one (en-AU).
        languageTag: AppLocaleHolder.current.toLanguageTag(),
        onClosed: () {
          if (!mounted) return;
          _stopListeningFeedback();
          setState(() => _voiceState = _VoiceState.transcribing);
        },
        onDone: _onDictated,
      );
    } catch (_) {
      if (!mounted) return;
      _stopListeningFeedback();
      setState(() => _voiceState = _VoiceState.idle);
      _showMessage(l10n.chatMicStartFailed);
    }
  }

  /// The words join what is already written; the owner reads them again and sends.
  void _onDictated(DictationResult result) {
    if (!mounted) return;
    _stopListeningFeedback();
    setState(() => _voiceState = _VoiceState.idle);
    final l10n = context.l10n;
    if (result.text.isEmpty) {
      _showMessage(switch (result.problem) {
        DictationProblem.permission => l10n.chatMicPermissionNeeded,
        DictationProblem.microphone => l10n.chatMicStartFailed,
        _ => l10n.chatErrorTranscribe,
      });
      return;
    }
    final current = _controller.text;
    final joined = current.trim().isEmpty
        ? result.text
        : '${current.trimRight()} ${result.text}';
    // Set directly, so the field's length limit has to be applied here.
    final merged = joined.length > chatMaxMessageLength
        ? joined.substring(0, chatMaxMessageLength)
        : joined;
    _controller.value = TextEditingValue(
      text: merged,
      selection: TextSelection.collapsed(offset: merged.length),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PendingAttachmentChip extends StatelessWidget {
  const _PendingAttachmentChip({
    required this.imageBytes,
    required this.isUploading,
    required this.onRemove,
  });

  final Uint8List imageBytes;
  final bool isUploading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.small),
              child: Opacity(
                opacity: isUploading ? 0.5 : 1,
                child: Image.memory(imageBytes, width: 52, height: 52, fit: BoxFit.cover),
              ),
            ),
            if (isUploading)
              const Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: PetLoader.small(),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            isUploading ? context.l10n.chatPhotoAnalyzing : context.l10n.chatPhotoReady,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: context.l10n.chatRemovePhotoTooltip,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

/// While listening: a pulsing dot, what is happening, how long it has been.
/// Tapping it stops the dictation, like the stop button.
class _ListeningBanner extends StatelessWidget {
  const _ListeningBanner({
    required this.pulse,
    required this.elapsedSeconds,
    required this.onTap,
  });

  final Animation<double> pulse;
  final int elapsedSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return Semantics(
      button: true,
      label: context.l10n.chatRecordingSemantics(
        context.l10n.chatListeningText,
        minutes,
        seconds,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0.25).animate(pulse),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.chatListeningText,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$minutes:$seconds',
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranscribingBanner extends StatelessWidget {
  const _TranscribingBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.secondarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const PetLoader.small(),
          const SizedBox(width: AppSpacing.sm),
          Text(
            context.l10n.chatTranscribingText,
            style: const TextStyle(
                color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EditingBanner extends StatelessWidget {
  const _EditingBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondaryStrong),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            context.l10n.chatEditingLabel,
            style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: onCancel,
          tooltip: context.l10n.chatCancelEditTooltip,
          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: color ?? AppColors.secondaryText, size: 22),
      // Not compact: a compact button answers to 40 px only.
      visualDensity: VisualDensity.standard,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      // 40 px visible, 48 px to touch.
      style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.padded),
    );
  }
}
