import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'api_service.dart';

class ImageUploadResult {
  const ImageUploadResult({
    required this.url,
    required this.fileId,
  });

  final String url;
  final String fileId;
}

class ImageUploadService {
  ImageUploadService._();

  static final ImageUploadService instance = ImageUploadService._();

  final ImagePicker _picker = ImagePicker();

  Future<ImageUploadResult?> pickFromGallery({
    required String purpose,
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 82,
  }) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      requestFullMetadata: false,
    );

    if (file == null) return null;

    return upload(
      file,
      purpose: purpose,
    );
  }

  Future<ImageUploadResult?> pickFromCamera({
    required String purpose,
    double maxWidth = 1600,
    double maxHeight = 1600,
    int imageQuality = 82,
  }) async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      requestFullMetadata: false,
    );

    if (file == null) return null;

    return upload(
      file,
      purpose: purpose,
    );
  }

  Future<ImageUploadResult> upload(
    XFile file, {
    required String purpose,
  }) async {
    final originalBytes = await file.readAsBytes();
    final bytes = await FlutterImageCompress.compressWithList(
      originalBytes,
      minWidth: 1600,
      minHeight: 1600,
      quality: 82,
      format: CompressFormat.jpeg,
    );

    if (bytes.isEmpty) {
      throw const ApiException(
        message: 'A imagem selecionada está vazia.',
        code: 'invalid-image',
      );
    }

    if (!_looksLikeJpeg(bytes)) {
      throw const ApiException(
        message: 'Não foi possível preparar essa imagem. Tente outra foto.',
        code: 'invalid-image',
      );
    }

    if (bytes.length > 4 * 1024 * 1024) {
      throw const ApiException(
        message:
            'A imagem ficou grande demais. Escolha outra foto ou reduza o tamanho.',
        code: 'image-too-large',
      );
    }

    const extension = 'jpg';
    const mimeType = 'image/jpeg';

    final result = await ApiService.instance.post(
      '/upload-image',
      body: {
        'purpose': purpose,
        'fileName':
            '${purpose}_${DateTime.now().millisecondsSinceEpoch}.$extension',
        'mimeType': mimeType,
        'base64': base64Encode(bytes),
      },
    );

    final url = (result['url'] ?? '').toString().trim();

    if (url.isEmpty) {
      throw const ApiException(
        message: 'O servidor não retornou a URL da imagem.',
        code: 'invalid-image-response',
      );
    }

    return ImageUploadResult(
      url: url,
      fileId: (result['fileId'] ?? '').toString(),
    );
  }

  bool _looksLikeJpeg(Uint8List bytes) {
    if (bytes.length < 4) return false;

    return bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[bytes.length - 2] == 0xFF &&
        bytes[bytes.length - 1] == 0xD9;
  }
}
