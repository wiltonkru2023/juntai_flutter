import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/activity_artwork.dart';
import '../../../../shared/models/activity.dart';
import '../../../activities/presentation/widgets/activity_info_row.dart';
import '../../../activities/presentation/widgets/participants_avatar_row.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.onJoin,
  });

  final Activity activity;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/activity/${activity.id}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.border.withValues(alpha: .7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 132,
              child: _Artwork(activity: activity),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          '${activity.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ActivityInfoRow(
                    icon: Icons.location_on_outlined,
                    text: activity.address,
                  ),
                  ActivityInfoRow(
                    icon: Icons.calendar_month_outlined,
                    text:
                        '${DateFormat('dd/MM').format(activity.startsAt)} • '
                        '${DateFormat('HH:mm').format(activity.startsAt)}',
                  ),
                  ActivityInfoRow(
                    icon: Icons.groups_outlined,
                    text:
                        '${activity.participantCount} / '
                        '${activity.maxParticipants} participantes',
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ParticipantAvatarRow(
                          names: activity.participantNames,
                        ),
                      ),
                      FilledButton(
                        onPressed:
                            activity.isFull ? null : onJoin,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          activity.isFull
                              ? 'Lotado'
                              : activity.isPrivate
                                  ? 'Solicitar'
                                  : 'Participar',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final cover = activity.coverUrl?.trim() ?? '';

    if (cover.isEmpty) {
      return ActivityArtwork(
        category: activity.category,
        height: 176,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        cover,
        width: 132,
        height: 176,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ActivityArtwork(
          category: activity.category,
          height: 176,
        ),
      ),
    );
  }
}
