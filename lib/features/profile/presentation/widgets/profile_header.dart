import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../shared/models/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.user, this.onEdit});
  final UserProfile user;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          AppAvatar(name: user.name, size: 104, photoUrl: user.photoUrl),
          if (onEdit != null)
            Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 18))))
        ]),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          Text(user.city,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 7),
          Text(user.bio, style: const TextStyle(color: AppColors.textSecondary))
        ]))
      ]);
}
