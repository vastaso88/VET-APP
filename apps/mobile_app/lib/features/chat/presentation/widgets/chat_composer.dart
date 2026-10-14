import 'dart:async';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/pet_loader.dart';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../settings/data/layout_settings_store.dart';
import '../../data/chat_demo_store.dart';
import '../../data/chat_remote_data_source.dart' show chatMaxMessageLength;
import '../../data/speech_to_text_remote_data_source.dart';

enum _VoiceState { idle, recording, transcribing }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.petName,
    this.onSend,
    this.speechToText,
    this.recorder,
    this.recordingPathProvider,
    this.editingText,
    this.onCancelEditing,
    this.allowEmptySend = false,
  });

  final String hintText;
  final String petName;

  /// [attachmentId] is only set once the photo finished uploading and being
  /// analyzed server-side — see [ChatDemoStore.uploadAttachment].
  final void Function(String text, {String? attachmentId, Uint8List? attachmentImageBytes})? onSend;
  final SpeechToTextRemoteDataSource? speechToText;

  /// Overridable so tests can drive the dictation flow without a microphone.
  final AudioRecorder? recorder;
  final Future<String> Function()? recordingPathProvider;

  /// The text of a sent message being edited: when it changes from null, it
  /// is put in the field and the composer shows it is editing. Sending then
  /// replaces that message (see ChatDemoStore.editMessage).
  final String? editingText;
  final VoidCallback? onCancelEditing;

  /// Lets an empty field be sent: an edited message that keeps only its
  /// photo.
  final bool allowEmptySend;

  static String get listeningText => appL10n.chatListeningText;
  static String get transcribingText => appL10n.chatTranscribingText;
  static String get editingLabel => appL10n.chatEditingLabel;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// Drives the pulsing dot and stop button while recording (build 28: it
  /// was not clear the microphone was listening).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  late final AudioRecorder _recorder = widget.recorder ?? AudioRecorder();
  late final SpeechToTextRemoteDataSource _speechToText =
      widget.speechToText ?? HttpSpeechToTextRemoteDataSource();

  bool _hasText = false;

  /// The field holds as many characters as the backend accepts: typing or
  /// pasting stops there, and a line says why.
  bool _atLimit = false;
  _VoiceState _voiceState = _VoiceState.idle;

  Uint8List? _pendingImageBytes;
  String? _pendingAttachmentId;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      final atLimit = _controller.text.length >= chatMaxMessageLength;
      if (hasText != _hasText || atLimit != _atLimit) {
        setState(() {
          _hasText = hasText;
          _atLimit = atLimit;
        });
      }
    });
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
    _elapsedTimer?.cancel();
    _pulse.dispose();
    _focusNode.dispose();
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _startRecordingFeedback() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _pulse.repeat(reverse: true);
  }

  void _stopRecordingFeedback() {
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
    final canSend = (_hasText || widget.allowEmptySend) && !_uploadingAttachment;
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
            color: Color(0x0F163A35),
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
          if (_voiceState == _VoiceState.recording) ...[
            _RecordingBanner(
              pulse: _pulse,
              elapsedSeconds: _elapsedSeconds,
              onTap: _toggleRecording,
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
                  hintText: _voiceState == _VoiceState.recording
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
              else
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.18).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: _ComposerIconButton(
                    icon: _voiceState == _VoiceState.recording
                        ? Icons.stop_circle_rounded
                        : Icons.mic_none_rounded,
                    tooltip: _voiceState == _VoiceState.recording
                        ? context.l10n.chatStopRecordingTooltip
                        : context.l10n.chatVoiceMessageTooltip,
                    color: _voiceState == _VoiceState.recording ? AppColors.danger : null,
                    onPressed: _toggleRecording,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 40,
                height: 40,
                child: FloatingActionButton(
                  heroTag: null,
                  elevation: 0,
                  backgroundColor: canSend ? AppColors.primary : AppColors.border,
                  foregroundColor: AppColors.onPrimary,
                  onPressed: canSend ? () => _sendMessage(_controller.text) : null,
                  child: const Icon(Icons.arrow_upward_rounded, size: 18),
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
    if (file == null || bytes == null) return;

    setState(() {
      _pendingImageBytes = bytes;
      _pendingAttachmentId = null;
      _uploadingAttachment = true;
    });

    final result = await ChatDemoStore.instance.uploadAttachment(
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

  Future<void> _toggleRecording() async {
    if (_voiceState == _VoiceState.recording) {
      await _stopAndTranscribe();
      return;
    }
    if (_voiceState != _VoiceState.idle) return;
    final l10n = context.l10n;

    var hasPermission = false;
    try {
      hasPermission = await _recorder.hasPermission();
    } catch (_) {
      // Treated like a refusal: the message below is shown.
    }
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatMicPermissionNeeded)),
      );
      return;
    }

    try {
      // `record` opens the file as given, and a bare name resolves against the
      // process working directory (read-only "/" on Android): the recorder
      // refused to start there. Native recordings go to a real temp file.
      final path = await (widget.recordingPathProvider ?? _defaultRecordingPath)();
      await _recorder.start(_recordConfig, path: path);
    } catch (_) {
      _showMessage(l10n.chatMicStartFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.recording);
    _startRecordingFeedback();
  }

  /// Mono 16 kHz AAC (.m4a) is plenty for speech and keeps the upload small.
  /// The web recorder picks its own container (webm), so keep its defaults.
  static const _recordConfig = kIsWeb
      ? RecordConfig()
      : RecordConfig(
          encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 64000);

  static Future<String> _defaultRecordingPath() async {
    if (kIsWeb) return 'chat-voice-message.webm';
    final directory = await getTemporaryDirectory();
    return '${directory.path}/chat-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _stopAndTranscribe() async {
    final l10n = context.l10n;
    _stopRecordingFeedback();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      if (mounted) setState(() => _voiceState = _VoiceState.idle);
      _showMessage(l10n.chatRecordingFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.transcribing);

    if (path == null) {
      setState(() => _voiceState = _VoiceState.idle);
      return;
    }

    try {
      // On web `stop()` returns a `blob:` URL for the recording; http can
      // fetch it directly (the blob lives in this same page's origin). On
      // Android/iOS it is a plain file path.
      final audioBytes =
          kIsWeb ? (await http.get(Uri.parse(path))).bodyBytes : await File(path).readAsBytes();
      final result = await _speechToText.transcribe(
        audioBytes: audioBytes,
        fileName: kIsWeb ? 'chat-voice-message.webm' : 'chat-voice-message.m4a',
      );
      if (!mounted) return;
      result.fold(
        onSuccess: (text) {
          final transcribed = text.trim();
          if (transcribed.isEmpty) return;
          final current = _controller.text;
          final joined = current.trim().isEmpty ? transcribed : '$current $transcribed';
          // Set directly, so the field's length limit has to be applied here.
          final merged = joined.length > chatMaxMessageLength
              ? joined.substring(0, chatMaxMessageLength)
              : joined;
          _controller.value = TextEditingValue(
            text: merged,
            selection: TextSelection.collapsed(offset: merged.length),
          );
        },
        onFailure: (error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatRecordingReadFailed)),
      );
    } finally {
      if (!kIsWeb) {
        // The clip is only needed for the transcription.
        try {
          await File(path).delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _voiceState = _VoiceState.idle);
    }
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

/// While recording: a pulsing dot, what is happening, how long it has been.
/// Tapping it stops the recording, like the stop button.
class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({
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
        color: AppColors.accentSoft,
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
        const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
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
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
