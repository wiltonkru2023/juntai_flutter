import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/discovery.dart';
import 'post_metric_tracker.dart';

class DiscoveryCard extends StatelessWidget {
  const DiscoveryCard({
    super.key,
    required this.discovery,
    required this.onTap,
    required this.onCreate,
  });

  final Discovery discovery;
  final VoidCallback onTap;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 14,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostMetricTracker(postId: discovery.id, event: 'impression'),
              if ((discovery.coverUrl ?? '').isNotEmpty)
                Image.network(
                  discovery.coverUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            discovery.businessName.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (discovery.businessVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.blue,
                          ),
                        if (discovery.sponsored)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Patrocinado',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            discovery.businessCategory,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (discovery.distanceKm != null)
                          Text(
                            discovery.distanceKm! < 1
                                ? '${(discovery.distanceKm! * 1000).round()} m'
                                : '${discovery.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      discovery.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      discovery.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((discovery.groupBenefit ?? '').isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.groups_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                discovery.groupBenefit!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onCreate,
                        child: Text(discovery.ctaLabel),
                      ),
                    ),
                    if (discovery.activitiesCreated > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          '${discovery.activitiesCreated} encontros criados • '
                          '${discovery.participantsGenerated} participantes gerados',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
