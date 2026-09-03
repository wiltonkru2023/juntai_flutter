import 'dart:convert';

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
    final bytes = await file.readAsBytes();

    if (bytes.isEmpty) {
      throw const ApiException(
        message: 'A imagem selecionada está vazia.',
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

    final extension = _extension(file.name);
    final mimeType = _mimeType(extension);

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

  String _extension(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic')) return 'heic';
    if (lower.endsWith('.heif')) return 'heif';

    return 'jpg';
  }

  String _mimeType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}
