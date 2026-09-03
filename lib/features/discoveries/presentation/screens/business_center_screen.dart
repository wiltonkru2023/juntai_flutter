import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class BusinessCenterScreen extends StatefulWidget {
  const BusinessCenterScreen({super.key});
  @override
  State<BusinessCenterScreen> createState() => _BusinessCenterScreenState();
}

class _BusinessCenterScreenState extends State<BusinessCenterScreen> {
  final name = TextEditingController(),
      category = TextEditingController(),
      city = TextEditingController(),
      address = TextEditingController(),
      website = TextEditingController(),
      description = TextEditingController();
  bool saving = false;
  String get uid => FirebaseAuth.instance.currentUser!.uid;
  @override
  void dispose() {
    for (final c in [name, category, city, address, website, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    if (name.text.trim().isEmpty ||
        category.text.trim().isEmpty ||
        city.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      context.snack('Preencha nome, categoria, cidade e endereço.');
      return;
    }
    setState(() => saving = true);
    try {
      final points = await Geocoding().locationFromAddress(address.text.trim());
      if (points.isEmpty) throw Exception('Endereço não encontrado');
      await ApiService.instance.createBusiness({
        'name': name.text.trim(),
        'category': category.text.trim(),
        'city': city.text.trim(),
        'address': address.text.trim(),
        'latitude': points.first.latitude,
        'longitude': points.first.longitude,
        'websiteUrl': website.text.trim(),
        'description': description.text.trim()
      });
      if (mounted) context.snack('Perfil comercial enviado para análise.');
    } catch (_) {
      if (mounted)
        context.snack('Não foi possível criar o perfil. Confira o endereço.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Área comercial',
              style: TextStyle(fontWeight: FontWeight.w900))),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('business_profiles')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!.exists)
              return ListView(padding: const EdgeInsets.all(22), children: [
                const Icon(Icons.storefront_rounded, size: 64),
                const SizedBox(height: 10),
                const Text('Crie seu perfil comercial',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                    'Lugares, organizadores e instituições podem transformar novidades em encontros.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 22),
                AppTextField(
                    controller: name,
                    label: 'Nome público',
                    hint: 'Café Central'),
                const SizedBox(height: 10),
                AppTextField(
                    controller: category,
                    label: 'Categoria',
                    hint: 'Cafeteria, evento, museu...'),
                const SizedBox(height: 10),
                AppTextField(
                    controller: city, label: 'Cidade', hint: 'Campinas - SP'),
                const SizedBox(height: 10),
                AppTextField(
                    controller: address,
                    label: 'Endereço',
                    hint: 'Rua, número, cidade e estado'),
                const SizedBox(height: 10),
                AppTextField(
                    controller: website,
                    label: 'Site (opcional)',
                    hint: 'https://...'),
                const SizedBox(height: 10),
                AppTextField(
                    controller: description,
                    label: 'Sobre',
                    hint: 'Conte sobre o seu espaço',
                    maxLines: 4),
                const SizedBox(height: 18),
                AppButton(
                    label: saving ? 'Enviando...' : 'Criar perfil comercial',
                    onPressed: saving ? null : _create),
              ]);
            final d = snapshot.data!.data()!;
            return ListView(padding: const EdgeInsets.all(22), children: [
              Row(children: [
                const CircleAvatar(
                    radius: 30, child: Icon(Icons.store_rounded)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Flexible(
                            child: Text((d['name'] ?? '').toString(),
                                style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900))),
                        if (d['verified'] == true)
                          const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.verified_rounded,
                                  color: Colors.blue))
                      ]),
                      Text((d['category'] ?? '').toString()),
                      Text((d['city'] ?? '').toString())
                    ]))
              ]),
              const SizedBox(height: 18),
              Card(
                  child: ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(d['reviewStatus'] == 'approved'
                          ? 'Perfil aprovado'
                          : 'Verificação em análise'),
                      subtitle: Text(
                          'Plano ${(d['plan'] ?? 'free').toString().toUpperCase()}'))),
              FilledButton.icon(
                  onPressed: () => context.push('/business/post/create'),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Criar publicação')),
              const SizedBox(height: 20),
              const Text('Suas publicações',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('discoveries')
                      .where('businessId', isEqualTo: uid)
                      .snapshots(),
                  builder: (_, posts) {
                    final docs = posts.data?.docs ?? [];
                    if (docs.isEmpty)
                      return const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text('Nenhuma publicação ainda.'));
                    return Column(children: [
                      for (final p in docs) _BusinessPostRow(post: p)
                    ]);
                  }),
              const SizedBox(height: 18),
              const Card(
                  child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Planos comerciais',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            SizedBox(height: 8),
                            Text('GRÁTIS • perfil + 1 publicação ativa'),
                            Text('LOCAL • 5 publicações/mês + métricas'),
                            Text(
                                'PRO • destaque, benefícios e métricas completas')
                          ]))),
            ]);
          }));
}

class _BusinessPostRow extends StatelessWidget {
  const _BusinessPostRow({required this.post});
  final QueryDocumentSnapshot<Map<String, dynamic>> post;
  @override
  Widget build(BuildContext context) {
    final d = post.data();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: post.reference.collection('activity_links').snapshots(),
        builder: (context, links) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text((d['title'] ?? '').toString()),
            subtitle: Text(
                '${d['views'] ?? 0} visualizações • ${d['opens'] ?? 0} aberturas • ${links.data?.size ?? 0} atividades criadas • ${d['participantsGenerated'] ?? 0} participantes'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/discovery/${post.id}')));
  }
}
