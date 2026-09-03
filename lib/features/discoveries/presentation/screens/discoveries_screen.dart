import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../map/data/location_service.dart';
import '../../data/discovery_service.dart';
import '../../domain/discovery.dart';
import '../widgets/discovery_card.dart';

class DiscoveriesScreen extends StatefulWidget {
  const DiscoveriesScreen({super.key});

  @override
  State<DiscoveriesScreen> createState() => _DiscoveriesScreenState();
}

class _DiscoveriesScreenState extends State<DiscoveriesScreen> {
  Position? position;
  bool locating = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final value = await LocationService.getCurrentPosition();
      if (mounted) setState(() => position = value);
    } catch (_) {
      // A lista ainda funciona por data se o usuário não liberar localização.
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Lugares e Eventos',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'Atualizar localização',
              onPressed: locating ? null : _loadLocation,
              icon: locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
            IconButton(
              tooltip: 'Área comercial',
              onPressed: () => context.push('/business'),
              icon: const Icon(Icons.storefront_rounded),
            ),
          ],
        ),
        body: StreamBuilder<List<Discovery>>(
          stream: DiscoveryService().watchPublished(
            latitude: position?.latitude,
            longitude: position?.longitude,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data!;
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Nenhuma descoberta publicada ainda.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Lugares e eventos próximos aparecerão aqui.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadLocation,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (_, i) => DiscoveryCard(
                  discovery: items[i],
                  onTap: () => context.push('/discovery/${items[i].id}'),
                  onCreate: () => context.push(
                    '/activity/create?source=${items[i].id}',
                  ),
                ),
              ),
            );
          },
        ),
      );
}
