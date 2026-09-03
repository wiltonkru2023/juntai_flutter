import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/discovery.dart';
import '../widgets/discovery_card.dart';

class BusinessProfileScreen extends StatelessWidget {
  const BusinessProfileScreen({super.key, required this.businessId});
  final String businessId;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('business_profiles')
            .doc(businessId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.data!.exists) {
            return const Center(
                child: Text('Perfil comercial não encontrado.'));
          }
          final d = snapshot.data!.data()!;
          final uid = FirebaseAuth.instance.currentUser!.uid;
          final follow =
              snapshot.data!.reference.collection('followers').doc(uid);
          return CustomScrollView(slivers: [
            const SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                    background: ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(Icons.storefront_rounded,
                            size: 80, color: AppColors.primary)))),
            SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(children: [
                  Row(children: [
                    Expanded(
                        child: Text((d['name'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900))),
                    if (d['verified'] == true)
                      const Icon(Icons.verified_rounded, color: AppColors.blue)
                  ]),
                  Text('${d['category'] ?? ''} • ${d['city'] ?? ''}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: follow.snapshots(),
                      builder: (_, state) => Row(children: [
                            Expanded(
                                child: FilledButton.icon(
                                    onPressed: () => state.data?.exists == true
                                        ? follow.delete()
                                        : follow.set({
                                            'userId': uid,
                                            'createdAt':
                                                FieldValue.serverTimestamp()
                                          }),
                                    icon: Icon(state.data?.exists == true
                                        ? Icons.check_rounded
                                        : Icons.add_rounded),
                                    label: Text(state.data?.exists == true
                                        ? 'Seguindo'
                                        : 'Seguir'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton.icon(
                                    onPressed: () => launchUrl(
                                        Uri.parse(
                                            'https://www.google.com/maps/search/?api=1&query=${d['latitude']},${d['longitude']}'),
                                        mode: LaunchMode.externalApplication),
                                    icon: const Icon(Icons.directions_rounded),
                                    label: const Text('Como chegar'))),
                          ])),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: snapshot.data!.reference
                          .collection('followers')
                          .snapshots(),
                      builder: (_, followers) => Text(
                          '${followers.data?.size ?? 0} seguidores',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(height: 18),
                  Text((d['description'] ?? '').toString()),
                  const SizedBox(height: 24),
                  const Text('Publicações e eventos',
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('discoveries')
                          .where('businessId', isEqualTo: businessId)
                          .snapshots(),
                      builder: (context, posts) {
                        final items = (posts.data?.docs ?? [])
                            .where((p) => p.data()['status'] == 'published')
                            .map(Discovery.fromFirestore)
                            .toList();
                        if (items.isEmpty) {
                          return const Text('Nenhuma publicação ativa.');
                        }
                        return Column(children: [
                          for (final item in items)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: DiscoveryCard(
                                    discovery: item,
                                    onTap: () =>
                                        context.push('/discovery/${item.id}'),
                                    onCreate: () => context.push(
                                        '/activity/create?source=${item.id}')))
                        ]);
                      }),
                ])),
          ]);
        },
      ));
}
