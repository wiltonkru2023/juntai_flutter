import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/discovery.dart';
import '../widgets/discovery_card.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  bool tracked = false;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('business_profiles')
            .doc(widget.businessId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.data!.exists) {
            return const Scaffold(
                body: Center(child: Text('Perfil comercial não encontrado.')));
          }

          final d = snapshot.data!.data()!;
          if (!tracked) {
            tracked = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ApiService.instance
                  .trackBusinessProfile(widget.businessId)
                  .catchError(
                    (_) => <String, dynamic>{},
                  );
            });
          }

          return DefaultTabController(
            length: 4,
            child: Scaffold(
              body: NestedScrollView(
                headerSliverBuilder: (_, __) => [
                  SliverAppBar(
                    expandedHeight: 230,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: (d['coverUrl'] ?? '').toString().isEmpty
                          ? const ColoredBox(
                              color: AppColors.primaryLight,
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 88,
                                color: AppColors.primary,
                              ),
                            )
                          : Image.network(d['coverUrl'].toString(),
                              fit: BoxFit.cover),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Header(businessId: widget.businessId, data: d),
                  ),
                  const SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabsDelegate(),
                  ),
                ],
                body: TabBarView(
                  children: [
                    _PostsTab(businessId: widget.businessId, eventsOnly: false),
                    _PostsTab(businessId: widget.businessId, eventsOnly: true),
                    _PhotosTab(data: d),
                    _AboutTab(data: d),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.businessId, required this.data});
  final String businessId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final followRef = FirebaseFirestore.instance
        .collection('business_profiles')
        .doc(businessId)
        .collection('followers')
        .doc(uid);
    final photo = (data['photoUrl'] ?? '').toString();
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                child: photo.isEmpty
                    ? const Icon(Icons.store_rounded, size: 34)
                    : null,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            (data['name'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (data['verified'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(
                              Icons.verified_rounded,
                              color: AppColors.blue,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '@${data['username'] ?? ''}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${data['category'] ?? ''} • ${data['city'] ?? ''} - ${data['state'] ?? ''}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if ((data['accountType'] ?? 'business') != 'business')
                      Text(
                        '${data['accountType'] == 'institution' ? 'Instituição' : 'Organizador'}'
                        '${(data['institutionType'] ?? '').toString().isEmpty ? '' : ' • ${data['institutionType']}'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: followRef.snapshots(),
            builder: (_, follow) {
              final following = follow.data?.exists == true;
              return Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await ApiService.instance.followBusiness(
                            businessId,
                            follow: !following,
                          );
                        } on ApiException catch (e) {
                          if (context.mounted) context.snack(e.message);
                        }
                      },
                      icon: Icon(
                          following ? Icons.check_rounded : Icons.add_rounded),
                      label: Text(following ? 'Seguindo' : 'Seguir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=${data['latitude']},${data['longitude']}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Como chegar'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                value: '${(data['followersCount'] as num?)?.toInt() ?? 0}',
                label: 'seguidores',
              ),
              _Stat(
                value:
                    '${(data['participantsGenerated'] as num?)?.toInt() ?? 0}',
                label: 'pessoas geradas',
              ),
              _Stat(
                value: rating > 0
                    ? rating.toStringAsFixed(1).replaceAll('.', ',')
                    : '—',
                label: 'avaliação',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(
            label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      );
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  const _TabsDelegate();
  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      const ColoredBox(
        color: Colors.white,
        child: TabBar(
          tabs: [
            Tab(text: 'Publicações'),
            Tab(text: 'Eventos'),
            Tab(text: 'Fotos'),
            Tab(text: 'Sobre'),
          ],
        ),
      );

  @override
  bool shouldRebuild(covariant _TabsDelegate oldDelegate) => false;
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({required this.businessId, required this.eventsOnly});
  final String businessId;
  final bool eventsOnly;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('discoveries')
            .where('businessId', isEqualTo: businessId)
            .snapshots(),
        builder: (_, snapshot) {
          final items = (snapshot.data?.docs ?? [])
              .where((doc) => doc.data()['status'] == 'published')
              .map(Discovery.fromFirestore)
              .where((post) =>
                  eventsOnly ? post.type == 'event' : post.type != 'event')
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (items.isEmpty) {
            return Center(
              child: Text(
                eventsOnly
                    ? 'Nenhum evento ativo.'
                    : 'Nenhuma publicação ativa.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, index) {
              final item = items[index];
              return DiscoveryCard(
                discovery: item,
                onTap: () => context.push('/discovery/${item.id}'),
                onCreate: () =>
                    context.push('/activity/create?source=${item.id}'),
              );
            },
          );
        },
      );
}

class _PhotosTab extends StatelessWidget {
  const _PhotosTab({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final urls = <String>[
      if ((data['photoUrl'] ?? '').toString().isNotEmpty)
        data['photoUrl'].toString(),
      if ((data['coverUrl'] ?? '').toString().isNotEmpty)
        data['coverUrl'].toString(),
      if (data['galleryUrls'] is List)
        ...(data['galleryUrls'] as List).map((e) => e.toString()),
    ].where((e) => e.isNotEmpty).toSet().toList();

    if (urls.isEmpty)
      return const Center(child: Text('Nenhuma foto publicada.'));

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: urls.length,
      itemBuilder: (_, i) => Image.network(urls[i], fit: BoxFit.cover),
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text(
            (data['description'] ?? '').toString(),
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 18),
          _line(Icons.location_on_outlined, (data['address'] ?? '').toString()),
          _line(Icons.phone_outlined, (data['phone'] ?? '').toString()),
          _line(Icons.language_rounded, (data['websiteUrl'] ?? '').toString()),
          _line(Icons.alternate_email_rounded,
              (data['instagram'] ?? '').toString()),
          if (data['verified'] == true)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_rounded, color: AppColors.blue),
              title: Text('Perfil comercial verificado'),
            ),
        ],
      );

  Widget _line(IconData icon, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(value),
    );
  }
}
