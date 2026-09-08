import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorIconSize = 42,
    this.backgroundColor,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final double errorIconSize;
  final Color? backgroundColor;

  static String optimizedUrl(
    String raw, {
    int? width,
    int quality = 82,
  }) {
    final value = raw.trim();
    if (value.isEmpty) return value;

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;

    final host = uri.host.toLowerCase();
    final looksLikeImageKit =
        host.contains('imagekit.io') || uri.path.contains('/ik-');

    if (!looksLikeImageKit) return value;

    final transformations = <String>[
      'f-jpg',
      'q-$quality',
      if (width != null && width > 0) 'w-$width',
    ].join(',');

    final params = Map<String, String>.from(uri.queryParameters);
    params['tr'] = transformations;

    return uri.replace(queryParameters: params).toString();
  }

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    final radius = borderRadius ?? BorderRadius.circular(16);
    final bg = backgroundColor ?? AppColors.primaryLight;

    Widget placeholder({bool loading = false}) => Container(
          width: width,
          height: height,
          color: bg,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.primary,
                  size: errorIconSize,
                ),
        );

    if (value.isEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: placeholder(),
      );
    }

    final optimized = optimizedUrl(value, width: width?.round());

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        optimized,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder(loading: true);
        },
        errorBuilder: (_, __, ___) => Image.network(
          value,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder(),
        ),
      ),
    );
  }
}
