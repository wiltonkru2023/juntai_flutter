import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
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
  Widget build(BuildContext context) => CircleAvatar(
      radius: size / 2,
      backgroundColor: background ?? AppColors.primaryLight,
      foregroundColor: AppColors.primary,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? NetworkImage(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(name.initials,
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: size * .32))
          : null);
}
