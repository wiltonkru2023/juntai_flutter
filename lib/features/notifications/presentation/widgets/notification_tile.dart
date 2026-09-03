import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback? onTap;

  IconData get icon => switch (notification.type) {
        'join_approved' => Icons.check_circle_rounded,
        'join_rejected' => Icons.cancel_rounded,
        'new_message' || 'private_message' => Icons.chat_bubble_rounded,
        'new_participant' => Icons.person_add_alt_1_rounded,
        'activity_reminder' => Icons.schedule_rounded,
        'activity_updated' => Icons.edit_calendar_rounded,
        'activity_cancelled' => Icons.event_busy_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: notification.read ? Colors.white : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border.withValues(alpha: .7),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(notification.body),
        trailing: notification.read
            ? null
            : const CircleAvatar(
                radius: 4,
                backgroundColor: AppColors.primary,
              ),
      ),
    );
  }
}
