import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../shared/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onAudioConsumed,
    this.onOptions,
    this.showDeliveryStatus = false,
  });

  final ChatMessage message;
  final Future<void> Function()? onAudioConsumed;
  final VoidCallback? onOptions;
  final bool showDeliveryStatus;

  @override
  Widget build(BuildContext context) {
    if (message.type == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            message.text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    final deliveryLabel = message.seenBy.length > 1
        ? 'Visualizada'
        : message.deliveredTo.length > 1
            ? 'Entregue'
            : 'Enviada';

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOptions,
      onLongPress: onOptions,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 8),
        decoration: BoxDecoration(
          color: message.mine ? AppColors.primaryLight : Colors.white,
          border: Border.all(
            color: message.mine
                ? AppColors.primary.withValues(alpha: .12)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.deletedForEveryone)
              const _DeletedMessage()
            else ...[
              if (message.type == 'image') _ChatImage(url: message.mediaUrl),
              if (message.type == 'audio')
                _AudioMessagePlayer(
                  message: message,
                  onConsumed: onAudioConsumed,
                ),
              if (message.type == 'image') const SizedBox(height: 8),
              if (message.type != 'audio' && message.text.isNotEmpty)
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 15, height: 1.35),
                ),
            ],
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.editedAt != null &&
                    !message.deletedForEveryone) ...[
                  const Text(
                    'editada',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:'
                  '${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (message.mine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    message.seenBy.length > 1 || message.deliveredTo.length > 1
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    size: 16,
                    color: message.seenBy.length > 1
                        ? AppColors.blue
                        : AppColors.textSecondary,
                  ),
                  if (showDeliveryStatus) ...[
                    const SizedBox(width: 4),
                    Text(
                      deliveryLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: message.seenBy.length > 1
                            ? AppColors.blue
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (message.mine) {
      return Padding(
        padding: const EdgeInsets.only(left: 60, bottom: 14),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 36, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(name: message.senderName, size: 38),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedMessage extends StatelessWidget {
  const _DeletedMessage();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.block_rounded,
          size: 18,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Mensagem apagada',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';

    if (value.isEmpty) {
      return Container(
        width: 230,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.primary,
            size: 46,
          ),
        ),
      );
    }

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        value,
        width: 230,
        height: 170,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            width: 230,
            height: 170,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (_, __, ___) {
          return Container(
            width: 230,
            height: 170,
            color: AppColors.primaryLight,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.primary,
              size: 46,
            ),
          );
        },
      ),
    );

    return InkWell(
      onTap: () {
        showDialog<void>(
          context: context,
          barrierColor: Colors.black87,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          value,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: preview,
    );
  }
}

class _AudioMessagePlayer extends StatefulWidget {
  const _AudioMessagePlayer({
    required this.message,
    this.onConsumed,
  });

  final ChatMessage message;
  final Future<void> Function()? onConsumed;

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<void>? _completeSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _tempPath;
  bool _preparing = false;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.message.audioDurationMs);

    _positionSubscription = _player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    });

    _durationSubscription = _player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) async {
      if (mounted) setState(() => _position = Duration.zero);

      if (!_consumed && widget.message.viewOnce && widget.onConsumed != null) {
        _consumed = true;
        try {
          await widget.onConsumed!();
        } catch (_) {
          _consumed = false;
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();

    final path = _tempPath;
    if (path != null) {
      File(path).delete().catchError((_) => File(path));
    }

    super.dispose();
  }

  String _format(Duration value) {
    final total = value.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _hasUrl => (widget.message.audioUrl ?? '').trim().isNotEmpty;
  bool get _hasLegacyBase64 =>
      (widget.message.audioBase64 ?? '').trim().isNotEmpty;

  Future<String?> _prepareLegacyFile() async {
    if (_tempPath != null && File(_tempPath!).existsSync()) return _tempPath;

    final encoded = widget.message.audioBase64;
    if (encoded == null || encoded.isEmpty) return null;

    setState(() => _preparing = true);

    try {
      final bytes = base64Decode(encoded);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/juntai_audio_${widget.message.id}.m4a';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      _tempPath = path;
      return path;
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _toggle() async {
    if (_player.state == PlayerState.playing) {
      await _player.pause();
      if (mounted) setState(() {});
      return;
    }

    if (_position > Duration.zero && _player.state == PlayerState.paused) {
      await _player.resume();
      if (mounted) setState(() {});
      return;
    }

    if (_hasUrl) {
      await _player.play(UrlSource(widget.message.audioUrl!.trim()));
    } else {
      final path = await _prepareLegacyFile();
      if (path == null) return;
      await _player.play(DeviceFileSource(path));
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasUrl && !_hasLegacyBase64) {
      if (widget.message.viewOnce) {
        return const SizedBox(
          width: 235,
          child: Row(
            children: [
              Icon(
                Icons.visibility_off_rounded,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                'Áudio já ouvido',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }

      return const SizedBox(
        width: 235,
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text(
              'Áudio indisponível',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final playing = _player.state == PlayerState.playing;
    final totalMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds
        : widget.message.audioDurationMs;
    final currentMs =
        _position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 1);
    final progress = totalMs <= 0 ? 0.0 : currentMs / totalMs;

    return SizedBox(
      width: 235,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _preparing ? null : _toggle,
              icon: _preparing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: AppColors.border,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      _position > Duration.zero
                          ? _format(_position)
                          : _format(_duration),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (widget.message.viewOnce) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.looks_one_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.mic_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
