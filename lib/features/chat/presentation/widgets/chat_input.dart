import 'dart:async';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ChatInput extends StatefulWidget {
  const ChatInput(
      {super.key,
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
      this.uploadingImage = false});
  final TextEditingController controller;
  final VoidCallback onSend, onImage;
  final Future<bool> Function() onRecordStart;
  final Future<void> Function() onRecordStop, onRecordCancel;
  final bool recording, sending, uploadingImage, viewOnceAudio;
  final int recordingSeconds;
  final ValueChanged<bool> onViewOnceChanged;
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  bool showEmoji = false,
      gestureActive = false,
      cancelled = false,
      released = false;
  int? pointer;
  Offset? origin;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant ChatInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
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
        gestureActive) return;
    pointer = event.pointer;
    origin = event.position;
    cancelled = false;
    released = false;
    gestureActive = true;
    if (mounted) setState(() => showEmoji = false);
    final started = await widget.onRecordStart();
    if (!started) {
      _reset();
      return;
    }
    if (released) {
      cancelled ? await widget.onRecordCancel() : await widget.onRecordStop();
      _reset();
    }
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != pointer || origin == null || cancelled) return;
    if (event.position.dx - origin!.dx <= -90) {
      cancelled = true;
      if (mounted) setState(() {});
    }
  }

  Future<void> _finish(PointerEvent event) async {
    if (event.pointer != pointer || !gestureActive) return;
    released = true;
    pointer = null;
    origin = null;
    if (!widget.recording) return;
    cancelled ? await widget.onRecordCancel() : await widget.onRecordStop();
    _reset();
  }

  void _reset() {
    pointer = null;
    origin = null;
    gestureActive = false;
    released = false;
    cancelled = false;
    if (mounted) setState(() {});
  }

  String get time {
    final m = widget.recordingSeconds ~/ 60, s = widget.recordingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final rec = widget.recording || gestureActive;
    return Container(
        color: Colors.white,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: 72,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Stack(children: [
                    Positioned.fill(
                        child: IgnorePointer(
                            ignoring: rec,
                            child: Opacity(
                                opacity: rec ? 0 : 1,
                                child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                          child: Container(
                                              decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: AppColors.border),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          28)),
                                              child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    IconButton(
                                                        onPressed: widget
                                                                .uploadingImage
                                                            ? null
                                                            : () => setState(
                                                                () => showEmoji =
                                                                    !showEmoji),
                                                        icon: Icon(showEmoji
                                                            ? Icons
                                                                .keyboard_rounded
                                                            : Icons
                                                                .emoji_emotions_outlined)),
                                                    Expanded(
                                                        child: TextField(
                                                            controller: widget
                                                                .controller,
                                                            enabled: !widget
                                                                .uploadingImage,
                                                            minLines: 1,
                                                            maxLines: 4,
                                                            decoration: const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                enabledBorder:
                                                                    InputBorder
                                                                        .none,
                                                                focusedBorder:
                                                                    InputBorder
                                                                        .none,
                                                                filled: false,
                                                                hintText:
                                                                    'Escrever mensagem...',
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            13)))),
                                                    IconButton(
                                                        onPressed: widget
                                                                .uploadingImage
                                                            ? null
                                                            : widget.onImage,
                                                        icon: const Icon(Icons
                                                            .attach_file_rounded)),
                                                  ]))),
                                      const SizedBox(width: 8),
                                      const SizedBox(width: 48, height: 48),
                                    ])))),
                    if (rec)
                      Positioned.fill(
                          child: Row(children: [
                        const Icon(Icons.circle,
                            size: 12, color: AppColors.error),
                        const SizedBox(width: 8),
                        SizedBox(
                            width: 58,
                            child: Text(time,
                                style: const TextStyle(
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.error))),
                        Expanded(
                            child: Text(
                                cancelled
                                    ? 'Solte para excluir'
                                    : '← Arraste para excluir',
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: cancelled
                                        ? AppColors.error
                                        : AppColors.textSecondary))),
                        IconButton(
                            tooltip: widget.viewOnceAudio
                                ? 'Visualização única ativa'
                                : 'Ativar visualização única',
                            onPressed: () =>
                                widget.onViewOnceChanged(!widget.viewOnceAudio),
                            icon: Icon(Icons.looks_one_rounded,
                                color: widget.viewOnceAudio
                                    ? AppColors.primary
                                    : AppColors.textSecondary)),
                        const SizedBox(width: 48),
                      ])),
                    Positioned(
                        right: 0,
                        bottom: 0,
                        width: 48,
                        height: 48,
                        child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: hasText ? null : _down,
                            onPointerMove: _move,
                            onPointerUp: _finish,
                            onPointerCancel: _finish,
                            child: Material(
                                color:
                                    rec ? AppColors.error : AppColors.primary,
                                shape: const CircleBorder(),
                                child: Center(
                                    child: Icon(
                                        hasText
                                            ? Icons.send_rounded
                                            : Icons.mic_rounded,
                                        color: Colors.white))))),
                    if (hasText)
                      Positioned(
                          right: 0,
                          bottom: 0,
                          width: 48,
                          height: 48,
                          child: IconButton(
                              onPressed: widget.sending ? null : widget.onSend,
                              icon: const Icon(Icons.send_rounded,
                                  color: Colors.white))),
                  ]))),
          if (widget.uploadingImage)
            const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Enviando foto...')),
          if (showEmoji && !rec)
            SizedBox(
                height: 285,
                child: EmojiPicker(
                    textEditingController: widget.controller,
                    config: const Config(height: 285, locale: Locale('pt')))),
        ]));
  }
}
