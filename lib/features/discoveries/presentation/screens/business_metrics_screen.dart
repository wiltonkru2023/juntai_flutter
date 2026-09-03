import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/discovery.dart';

class BusinessMetricsScreen extends StatelessWidget {
  const BusinessMetricsScreen({super.key, required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Métricas',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('discoveries')
              .where('businessId', isEqualTo: businessId)
              .snapshots(),
          builder: (_, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());

            final posts =
                snapshot.data!.docs.map(Discovery.fromFirestore).toList();
            int sum(int Function(Discovery) getter) =>
                posts.fold(0, (value, item) => value + getter(item));

            final views = sum((p) => p.views);
            final opens = sum((p) => p.opens);
            final participants = sum((p) => p.participantsGenerated);
            final groups = sum((p) => p.groupsCreated);
            final want = sum((p) => p.wantToGoClicks);
            final shares = sum((p) => p.shareCount);
            final coupons = sum((p) => p.couponValidations);
            final conversion = views <= 0 ? 0.0 : (participants / views) * 100;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Card('Visualizações', views),
                    _Card('Aberturas', opens),
                    _Card('Quero ir', want),
                    _Card('Grupos criados', groups),
                    _Card('Pessoas geradas', participants),
                    _Card('Compartilhamentos', shares),
                    _Card('Cupons validados', coupons),
                    _Card('Conversão',
                        '${conversion.toStringAsFixed(1).replaceAll('.', ',')}%'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Por publicação',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                for (final post in posts)
                  Card(
                    child: ListTile(
                      title: Text(post.title),
                      subtitle: Text(
                        '${post.views} visualizações • ${post.opens} aberturas\n'
                        '${post.groupsCreated} grupos • ${post.participantsGenerated} participantes • '
                        '${post.wantToGoClicks} quero ir',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card(this.label, this.value);
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text('$value',
                style:
                    const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            Text(
              label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
