import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../discoveries/data/discovery_service.dart';
import '../../../discoveries/domain/discovery.dart';

class UrgentOpenSlotsSection extends StatelessWidget {
  const UrgentOpenSlotsSection({super.key, this.position});
  final Position? position;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Discovery>>(
        stream: DiscoveryService().watchPublished(
          limit: 80,
          latitude: position?.latitude,
          longitude: position?.longitude,
        ),
        builder: (_, snapshot) {
          final now = DateTime.now();
          final items = (snapshot.data ?? const <Discovery>[]).where((d) {
            if (!d.isOpenSlots || d.isFull || d.remainingSlots <= 0) {
              return false;
            }
            final start = d.eventStartsAt;
            if (start == null || !start.isAfter(now)) return false;
            return start.difference(now) <= const Duration(hours: 8);
          }).toList()
            ..sort((a, b) {
              final byTime = a.eventStartsAt!.compareTo(b.eventStartsAt!);
              if (byTime != 0) return byTime;
              return (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999);
            });

          if (items.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.flash_on_rounded,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Precisando de gente agora',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final item in items.take(5))
                  Card(
                    child: ListTile(
                      onTap: () => context.push('/discovery/${item.id}'),
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_rounded),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'Faltam ${item.remainingSlots} • '
                        '${_when(item.eventStartsAt!)}'
                        '${item.distanceKm != null ? ' • ${item.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  static String _when(DateTime date) {
    final diff = date.difference(DateTime.now());
    if (diff.inMinutes < 60) {
      return 'começa em ${diff.inMinutes} min';
    }
    if (diff.inHours < 8) return 'começa em ${diff.inHours}h';
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
