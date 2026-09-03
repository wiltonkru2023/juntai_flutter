import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/models/activity.dart';
import '../../../home/presentation/widgets/activity_card.dart';
import '../../data/discovery_service.dart';
import '../../domain/discovery.dart';
import '../widgets/post_metric_tracker.dart';

class DiscoveryDetailsScreen extends StatelessWidget {
  const DiscoveryDetailsScreen({super.key, required this.discoveryId});
  final String discoveryId;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('discoveries')
              .doc(discoveryId)
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Descoberta não encontrada.'));
            }
            final d = Discovery.fromFirestore(snapshot.data!);
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            if (d.status != 'published' && d.businessId != currentUid) {
              return const Center(
                child: Text('Esta publicação não está mais disponível.'),
              );
            }
            return CustomScrollView(slivers: [
              SliverAppBar(
                  expandedHeight: (d.coverUrl ?? '').isEmpty ? 120 : 280,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                      background: (d.coverUrl ?? '').isEmpty
                          ? const ColoredBox(color: AppColors.primaryLight)
                          : Image.network(d.coverUrl!, fit: BoxFit.cover))),
              SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList.list(children: [
                    PostMetricTracker(postId: discoveryId, event: 'open'),
                    InkWell(
                        onTap: () => context.push('/business/${d.businessId}'),
                        child: Row(children: [
                          Expanded(
                              child: Text(d.businessName,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900))),
                          if (d.businessVerified)
                            const Icon(Icons.verified_rounded,
                                color: AppColors.blue),
                          const Icon(Icons.chevron_right_rounded),
                        ])),
                    Text(d.businessCategory,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    Text(d.title,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(d.description,
                        style: const TextStyle(fontSize: 16, height: 1.4)),
                    const SizedBox(height: 12),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_rounded,
                            color: AppColors.primary),
                        title: Text(d.address)),
                    _BusinessActions(discovery: d),
                    if ((d.groupBenefit ?? '').isNotEmpty)
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.redeem_rounded,
                                  color: AppColors.primary),
                              title: const Text('Benefício para grupos'),
                              subtitle: Text(d.groupBenefit!))),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                        onPressed: () => context
                            .push('/activity/create?source=$discoveryId'),
                        icon: const Icon(Icons.group_add_rounded),
                        label: Text(d.ctaLabel)),
                    StreamBuilder<bool>(
                        stream: DiscoveryService().watchInterested(discoveryId),
                        builder: (_, interested) => OutlinedButton.icon(
                            onPressed: () => DiscoveryService().setInterested(
                                discoveryId, interested.data != true),
                            icon: Icon(interested.data == true
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded),
                            label: Text(interested.data == true
                                ? 'Quero ir ✓'
                                : 'Quero ir'))),
                    const SizedBox(height: 24),
                    const Text('Grupos indo',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    _RelatedGroups(discoveryId: discoveryId),
                  ])),
            ]);
          }));
}

class _BusinessActions extends StatelessWidget {
  const _BusinessActions({required this.discovery});
  final Discovery discovery;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final follow = FirebaseFirestore.instance
        .collection('business_profiles')
        .doc(discovery.businessId)
        .collection('followers')
        .doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: follow.snapshots(),
        builder: (context, snapshot) =>
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () => snapshot.data?.exists == true
                      ? follow.delete()
                      : follow.set({
                          'userId': uid,
                          'createdAt': FieldValue.serverTimestamp()
                        }),
                  icon: Icon(snapshot.data?.exists == true
                      ? Icons.check_rounded
                      : Icons.add_rounded),
                  label: Text(
                      snapshot.data?.exists == true ? 'Seguindo' : 'Seguir')),
              OutlinedButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${discovery.latitude},${discovery.longitude}'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Como chegar')),
              if ((discovery.websiteUrl ?? '').isNotEmpty)
                OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse(discovery.websiteUrl!),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Site')),
            ]));
  }
}

class _RelatedGroups extends StatelessWidget {
  const _RelatedGroups({required this.discoveryId});
  final String discoveryId;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('activities')
              .where('sourceDiscoveryId', isEqualTo: discoveryId)
              .snapshots(),
          builder: (context, snapshot) {
            final groups = (snapshot.data?.docs ?? [])
                .map(Activity.fromFirestore)
                .where((a) =>
                    !a.isPrivate &&
                    a.status == 'active' &&
                    a.startsAt.isAfter(DateTime.now()))
                .toList();
            if (groups.isEmpty) {
              return const Text(
                  'Seja a primeira pessoa a criar um grupo para ir.',
                  style: TextStyle(color: AppColors.textSecondary));
            }
            return Column(children: [
              for (final group in groups)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                        height: 196,
                        child: ActivityCard(
                            activity: group,
                            onJoin: () =>
                                context.push('/activity/${group.id}'))))
            ]);
          });
}
