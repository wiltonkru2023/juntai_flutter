import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != widget.businessId) {
      return const Scaffold(
          body: Center(child: Text('Este painel é privado do comércio.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel comercial',
            style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: FutureBuilder<Map<String, dynamic>>(
          future: ApiService.instance.businessDashboard(),
          builder: (_, dashboard) =>
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('business_profiles')
                .doc(uid)
                .snapshots(),
            builder: (context, business) {
              if (!business.hasData)
                return const Center(child: CircularProgressIndicator());

              final d = business.data!.data() ?? const <String, dynamic>{};
              final week = dashboard.data?['week'] is Map
                  ? Map<String, dynamic>.from(dashboard.data!['week'] as Map)
                  : const <String, dynamic>{};

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Olá, ${d['name'] ?? 'comércio'}',
                    style: const TextStyle(
                        fontSize: 27, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Plano ${(d['plan'] ?? 'free').toString().toUpperCase()}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Metric('Visualizações',
                          week['impressions'] ?? week['views'] ?? 0),
                      _Metric('Aberturas', week['opens'] ?? 0),
                      _Metric('Quero ir', week['wantToGoClicks'] ?? 0),
                      _Metric('Grupos', week['groupsCreated'] ?? 0),
                      _Metric(
                          'Participantes', week['participantsGenerated'] ?? 0),
                      _Metric('Seguidores', week['followersGained'] ?? 0),
                      _Metric('Compartilhamentos', week['shareCount'] ?? 0),
                      _Metric('Cupons usados', week['couponValidations'] ?? 0),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: d['reviewStatus'] == 'approved'
                        ? () => context.push('/business/post/create')
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nova publicação'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/business/$uid/metrics'),
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Métricas completas'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/business/plans'),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('Planos e assinatura'),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Publicações',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _Posts(businessId: uid!),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Container(
        width: 155,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('$value',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
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

class _Posts extends StatelessWidget {
  const _Posts({required this.businessId});
  final String businessId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('discoveries')
            .where('businessId', isEqualTo: businessId)
            .snapshots(),
        builder: (_, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const Text('Nenhuma publicação ainda.');

          return Column(
            children: [
              for (final doc in docs)
                Card(
                  child: ListTile(
                    title: Text((doc.data()['title'] ?? '').toString()),
                    subtitle: Text(
                      '${doc.data()['type'] ?? 'experience'} • ${doc.data()['status'] ?? 'draft'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          context.push('/business/post/${doc.id}/edit');
                        } else if (value == 'sponsor') {
                          context.push('/business/post/${doc.id}/sponsor');
                        } else if (value == 'archive') {
                          await ApiService.instance.archiveBusinessPost(doc.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(
                            value: 'sponsor', child: Text('Patrocinar')),
                        PopupMenuItem(
                            value: 'archive', child: Text('Arquivar')),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
