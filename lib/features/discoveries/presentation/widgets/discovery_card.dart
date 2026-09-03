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

  String get typeLabel => switch (discovery.type) {
        'event' => 'EVENTO',
        'open_slots' => 'VAGAS ABERTAS',
        'promotion' => 'PROMOÇÃO',
        'schedule' => 'HORÁRIOS',
        _ => 'EXPERIÊNCIA',
      };

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
                  height: 155,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          discovery.businessName.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (discovery.businessVerified)
                          const Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: AppColors.blue,
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(typeLabel,
                              style: const TextStyle(fontSize: 10)),
                        ),
                        if (discovery.sponsored)
                          const Text(
                            'Patrocinado',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
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
                          fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      discovery.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (discovery.isOpenSlots && discovery.maxParticipants > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _Capacity(discovery: discovery),
                      ),
                    if (discovery.juntaiPrice != null ||
                        discovery.price != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Wrap(
                          spacing: 10,
                          children: [
                            if (discovery.price != null)
                              Text(
                                'R\$ ${discovery.price!.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(
                                  decoration: discovery.juntaiPrice != null
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (discovery.juntaiPrice != null)
                              Text(
                                'Juntaí R\$ ${discovery.juntaiPrice!.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                          ],
                        ),
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
                            Icon(
                              discovery.benefitUnlocked
                                  ? Icons.redeem_rounded
                                  : Icons.groups_rounded,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                discovery.benefitUnlocked
                                    ? 'Desbloqueado: ${discovery.groupBenefit}'
                                    : discovery.groupBenefit!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: discovery.isFull ? null : onCreate,
                        child: Text(
                          discovery.isFull
                              ? 'Grupo completo'
                              : discovery.ctaLabel,
                        ),
                      ),
                    ),
                    if (discovery.activitiesCreated > 0 ||
                        discovery.participantsGenerated > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          '${discovery.activitiesCreated} encontros • '
                          '${discovery.participantsGenerated} pessoas geradas',
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

class _Capacity extends StatelessWidget {
  const _Capacity({required this.discovery});
  final Discovery discovery;

  @override
  Widget build(BuildContext context) {
    final max = discovery.maxParticipants;
    final current = discovery.claimedParticipants.clamp(0, max);
    final progress = max <= 0 ? 0.0 : current / max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: 6),
        Text(
          '$current/$max confirmados • '
          '${discovery.remainingSlots == 0 ? 'Grupo completo' : 'faltam ${discovery.remainingSlots}'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
