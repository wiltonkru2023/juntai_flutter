import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import 'app_network_image.dart';
import '../extensions/string_extensions.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar(
      {super.key,
      required this.name,
      this.size = 44,
      this.photoUrl,
      this.background});
  final String name;
  final double size;
  final String? photoUrl;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final photo = photoUrl?.trim() ?? '';

    if (photo.isNotEmpty) {
      return ClipOval(
        child: AppNetworkImage(
          url: photo,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(size),
          errorIconSize: size * .45,
          backgroundColor: background ?? AppColors.primaryLight,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background ?? AppColors.primaryLight,
      foregroundColor: AppColors.primary,
      child: Text(
        name.initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * .32),
      ),
    );
  }
}
