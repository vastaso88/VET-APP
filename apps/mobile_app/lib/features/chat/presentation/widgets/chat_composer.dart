import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../data/chat_demo_store.dart';
import '../../data/speech_to_text_remote_data_source.dart';

enum _VoiceState { idle, recording, transcribing }

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.hintText,
    required this.petName,
    this.onSend,
    this.speechToText,
  });

  final String hintText;
  final String petName;

  /// [attachmentId] is only set once the photo finished uploading and being
  /// analyzed server-side — see [ChatDemoStore.uploadAttachment].
  final void Function(String text, {String? attachmentId, Uint8List? attachmentImageBytes})? onSend;
  final SpeechToTextRemoteDataSource? speechToText;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  late final SpeechToTextRemoteDataSource _speechToText =
      widget.speechToText ?? HttpSpeechToTextRemoteDataSource();

  bool _hasText = false;
  _VoiceState _voiceState = _VoiceState.idle;

  Uint8List? _pendingImageBytes;
  String? _pendingAttachmentId;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() => _hasText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !_uploadingAttachment;

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
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(color: AppColors.text, fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: _voiceState == _VoiceState.recording
                    ? 'Sto ascoltando...'
                    : _voiceState == _VoiceState.transcribing
                        ? 'Trascrivo il messaggio...'
                        : widget.hintText,
                border: InputBorder.none,
                isCollapsed: true,
                hintStyle: const TextStyle(color: AppColors.mutedText),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _ComposerIconButton(
                icon: Icons.add_rounded,
                tooltip: 'Aggiungi una foto',
                onPressed: _uploadingAttachment ? null : _pickAndUploadImage,
              ),
              const Spacer(),
              if (_voiceState == _VoiceState.transcribing)
                const Padding(
                  padding: EdgeInsets.all(9),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                _ComposerIconButton(
                  icon: _voiceState == _VoiceState.recording
                      ? Icons.stop_circle_rounded
                      : Icons.mic_none_rounded,
                  tooltip: _voiceState == _VoiceState.recording
                      ? 'Ferma e trascrivi'
                      : 'Messaggio vocale',
                  color: _voiceState == _VoiceState.recording ? AppColors.danger : null,
                  onPressed: _toggleRecording,
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
    if (message.isEmpty) return;
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

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serve il permesso per usare il microfono.')),
      );
      return;
    }

    await _recorder.start(const RecordConfig(), path: 'chat-voice-message.webm');
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.recording);
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _voiceState = _VoiceState.transcribing);

    if (path == null) {
      setState(() => _voiceState = _VoiceState.idle);
      return;
    }

    try {
      // On web `stop()` returns a `blob:` URL for the recording; http can
      // fetch it directly (the blob lives in this same page's origin).
      final response = await http.get(Uri.parse(path));
      final result = await _speechToText.transcribe(
        audioBytes: response.bodyBytes,
        fileName: 'chat-voice-message.webm',
      );
      if (!mounted) return;
      result.fold(
        onSuccess: (text) {
          final transcribed = text.trim();
          if (transcribed.isEmpty) return;
          final current = _controller.text;
          final merged = current.trim().isEmpty ? transcribed : '$current $transcribed';
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
        const SnackBar(content: Text('Non sono riuscito a leggere la registrazione. Riprova.')),
      );
    } finally {
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            isUploading ? 'Sto guardando la foto...' : 'Foto pronta da inviare',
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: 'Rimuovi foto',
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
