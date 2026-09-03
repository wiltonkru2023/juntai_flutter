import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onImage,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onRecordCancel,
    required this.recording,
    required this.recordingSeconds,
    required this.viewOnceAudio,
    required this.onViewOnceChanged,
    this.sending = false,
    this.uploadingImage = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onImage;
  final Future<bool> Function() onRecordStart;
  final Future<void> Function() onRecordStop;
  final Future<void> Function() onRecordCancel;
  final bool recording;
  final bool sending;
  final bool uploadingImage;
  final bool viewOnceAudio;
  final int recordingSeconds;
  final ValueChanged<bool> onViewOnceChanged;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool showEmoji = false;
  bool gestureActive = false;
  bool cancelled = false;
  bool released = false;
  bool locked = false;

  int? pointer;
  Offset? origin;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }

    if (!widget.recording && oldWidget.recording) {
      locked = false;
      gestureActive = false;
      cancelled = false;
      released = false;
      pointer = null;
      origin = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _down(PointerDownEvent event) async {
    if (widget.controller.text.trim().isNotEmpty ||
        widget.sending ||
        widget.uploadingImage ||
        gestureActive ||
        locked) {
      return;
    }

    pointer = event.pointer;
    origin = event.position;
    cancelled = false;
    released = false;
    locked = false;
    gestureActive = true;

    if (mounted) {
      setState(() => showEmoji = false);
    }

    final started = await widget.onRecordStart();
    if (!started) {
      _reset();
      return;
    }

    // O usuario pode soltar o dedo enquanto a permissao/gravadocao inicia.
    if (released) {
      if (locked) {
        gestureActive = false;
        released = false;
        if (mounted) setState(() {});
        return;
      }

      if (cancelled) {
        await widget.onRecordCancel();
      } else {
        await widget.onRecordStop();
      }
      _reset();
    }
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != pointer || origin == null || cancelled) return;

    final dx = event.position.dx - origin!.dx;
    final dy = event.position.dy - origin!.dy;

    if (dx <= -90) {
      cancelled = true;
      locked = false;
      if (mounted) setState(() {});
      return;
    }

    if (dy <= -90 && !locked) {
      locked = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _finish(PointerEvent event) async {
    if (event.pointer != pointer || !gestureActive) return;

    released = true;
    pointer = null;
    origin = null;

    // Se o recorder ainda esta iniciando, _down conclui a acao depois.
    if (!widget.recording) return;

    if (locked) {
      gestureActive = false;
      released = false;
      if (mounted) setState(() {});
      return;
    }

    if (cancelled) {
      await widget.onRecordCancel();
    } else {
      await widget.onRecordStop();
    }

    _reset();
  }

  Future<void> _sendLocked() async {
    if (!locked || !widget.recording || widget.sending) return;
    await widget.onRecordStop();
    _reset();
  }

  Future<void> _cancelLocked() async {
    if (!locked || !widget.recording) return;
    await widget.onRecordCancel();
    _reset();
  }

  void _reset() {
    pointer = null;
    origin = null;
    gestureActive = false;
    released = false;
    cancelled = false;
    locked = false;
    if (mounted) setState(() {});
  }

  String get time {
    final minutes = widget.recordingSeconds ~/ 60;
    final seconds = widget.recordingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final recordingUi = widget.recording || gestureActive || locked;

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: recordingUi,
                      child: Opacity(
                        opacity: recordingUi ? 0 : 1,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: widget.uploadingImage
                                          ? null
                                          : () => setState(
                                                () => showEmoji = !showEmoji,
                                              ),
                                      icon: Icon(
                                        showEmoji
                                            ? Icons.keyboard_rounded
                                            : Icons.emoji_emotions_outlined,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: widget.controller,
                                        enabled: !widget.uploadingImage,
                                        minLines: 1,
                                        maxLines: 4,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                          hintText: 'Escrever mensagem...',
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: widget.uploadingImage
                                          ? null
                                          : widget.onImage,
                                      icon:
                                          const Icon(Icons.attach_file_rounded),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SizedBox(width: 48, height: 48),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (recordingUi)
                    Positioned.fill(
                      right: 56,
                      child: Row(
                        children: [
                          if (locked)
                            IconButton(
                              tooltip: 'Excluir gravacao',
                              onPressed: _cancelLocked,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                            )
                          else ...[
                            const Icon(
                              Icons.circle,
                              size: 12,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                          ],
                          SizedBox(
                            width: 54,
                            child: Text(
                              time,
                              style: const TextStyle(
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontWeight: FontWeight.w800,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              locked
                                  ? 'Gravacao travada'
                                  : cancelled
                                      ? 'Solte para excluir'
                                      : 'â† cancelar   â†‘ travar',
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    locked ? FontWeight.w700 : FontWeight.w500,
                                color: cancelled
                                    ? AppColors.error
                                    : locked
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: widget.viewOnceAudio
                                ? 'Ouvir uma vez'
                                : 'Ativar ouvir uma vez',
                            onPressed: () => widget.onViewOnceChanged(
                              !widget.viewOnceAudio,
                            ),
                            icon: Icon(
                              Icons.looks_one_rounded,
                              color: widget.viewOnceAudio
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: 48,
                    height: 48,
                    child: locked && !gestureActive
                        ? Material(
                            color: AppColors.primary,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Enviar audio',
                              onPressed: widget.sending ? null : _sendLocked,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: hasText ? null : _down,
                            onPointerMove: _move,
                            onPointerUp: _finish,
                            onPointerCancel: _finish,
                            child: Material(
                              color: recordingUi
                                  ? AppColors.error
                                  : AppColors.primary,
                              shape: const CircleBorder(),
                              child: Center(
                                child: Icon(
                                  hasText
                                      ? Icons.send_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (hasText)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      width: 48,
                      height: 48,
                      child: IconButton(
                        onPressed: widget.sending ? null : widget.onSend,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.uploadingImage)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Enviando foto...'),
            ),
          if (showEmoji && !recordingUi)
            SizedBox(
              height: 285,
              child: EmojiPicker(
                textEditingController: widget.controller,
                config: const Config(
                  height: 285,
                  locale: Locale('pt'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
