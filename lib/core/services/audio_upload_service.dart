import 'dart:convert';
import 'dart:io';

import 'api_service.dart';

class AudioUploadResult {
  const AudioUploadResult({
    required this.url,
    required this.fileId,
  });

  final String url;
  final String fileId;
}

class AudioUploadService {
  AudioUploadService._();

  static final AudioUploadService instance = AudioUploadService._();

  Future<AudioUploadResult> uploadFile(
    File file, {
    required String purpose,
    String mimeType = 'audio/mp4',
  }) async {
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const ApiException(
        message: 'O áudio gravado está vazio.',
        code: 'invalid-audio',
      );
    }

    if (bytes.length > 4 * 1024 * 1024) {
      throw const ApiException(
        message: 'O áudio ficou grande demais. Grave uma mensagem menor.',
        code: 'audio-too-large',
      );
    }

    final result = await ApiService.instance.post(
      '/upload-audio',
      body: {
        'purpose': purpose,
        'fileName': '${purpose}_${DateTime.now().millisecondsSinceEpoch}.m4a',
        'mimeType': mimeType,
        'base64': base64Encode(bytes),
      },
    );

    final url = (result['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw const ApiException(
        message: 'O servidor não retornou a URL do áudio.',
        code: 'invalid-audio-response',
      );
    }

    return AudioUploadResult(
      url: url,
      fileId: (result['fileId'] ?? '').toString(),
    );
  }
}
