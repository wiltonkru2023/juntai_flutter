import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ActivityInfoRow extends StatelessWidget {
  const ActivityInfoRow({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis))
      ]));
}
