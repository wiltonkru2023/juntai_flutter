import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded));
}
