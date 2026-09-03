import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/discovery_service.dart';
import '../../domain/discovery.dart';
import '../widgets/discovery_card.dart';

class DiscoveriesScreen extends StatelessWidget {
  const DiscoveriesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Lugares e Eventos',
                style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                  tooltip: 'Área comercial',
                  onPressed: () => context.push('/business'),
                  icon: const Icon(Icons.storefront_rounded))
            ]),
        body: StreamBuilder<List<Discovery>>(
            stream: DiscoveryService().watchPublished(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty)
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.explore_outlined,
                              size: 56, color: AppColors.primary),
                          SizedBox(height: 12),
                          Text('Nenhuma descoberta publicada ainda.',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          SizedBox(height: 5),
                          Text('Lugares e eventos próximos aparecerão aqui.',
                              textAlign: TextAlign.center)
                        ])));
              return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => DiscoveryCard(
                      discovery: items[i],
                      onTap: () => context.push('/discovery/${items[i].id}'),
                      onCreate: () => context
                          .push('/activity/create?source=${items[i].id}')));
            }),
      );
}
