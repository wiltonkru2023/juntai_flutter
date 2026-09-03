import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
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
  final name = TextEditingController();
  final category = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final website = TextEditingController();
  final description = TextEditingController();

  bool saving = false;

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    for (final controller in [
      name,
      category,
      city,
      address,
      website,
      description
    ]) {
      controller.dispose();
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
        'description': description.text.trim(),
      });

      if (mounted) {
        context.snack('Perfil comercial enviado para análise.');
      }
    } on ApiException catch (error) {
      if (mounted) context.snack(error.message);
    } catch (_) {
      if (mounted) {
        context.snack('Não foi possível criar o perfil. Confira o endereço.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Área comercial',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('business_profiles')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.data!.exists) {
              return ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  const Icon(Icons.storefront_rounded, size: 64),
                  const SizedBox(height: 10),
                  const Text(
                    'Crie seu perfil comercial',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lugares, organizadores e instituições podem transformar novidades em encontros.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  AppTextField(
                    controller: name,
                    label: 'Nome público',
                    hint: 'Café Central',
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: category,
                    label: 'Categoria',
                    hint: 'Cafeteria, evento, museu...',
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: city,
                    label: 'Cidade',
                    hint: 'Campinas - SP',
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: address,
                    label: 'Endereço',
                    hint: 'Rua, número, cidade e estado',
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: website,
                    label: 'Site (opcional)',
                    hint: 'https://...',
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: description,
                    label: 'Sobre',
                    hint: 'Conte sobre o seu espaço',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: saving ? 'Enviando...' : 'Criar perfil comercial',
                    onPressed: saving ? null : _create,
                  ),
                ],
              );
            }

            final data = snapshot.data!.data()!;
            final reviewStatus = (data['reviewStatus'] ?? 'pending').toString();
            final approved = reviewStatus == 'approved';
            final now = DateTime.now().toUtc();
            final currentMonth =
                '${now.year}-${now.month.toString().padLeft(2, '0')}';
            final usage = data['usageMonth'] == currentMonth
                ? (data['postsUsedThisMonth'] as num?)?.toInt() ?? 0
                : 0;
            final monthlyLimit =
                (data['monthlyPostLimit'] as num?)?.toInt() ?? 1;
            final activeLimit = (data['activePostLimit'] as num?)?.toInt() ?? 1;

            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.store_rounded),
                    ),
                    const SizedBox(width: 12),
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
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (data['verified'] == true)
                                const Padding(
                                  padding: EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.verified_rounded,
                                    color: Colors.blue,
                                  ),
                                ),
                            ],
                          ),
                          Text((data['category'] ?? '').toString()),
                          Text((data['city'] ?? '').toString()),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar perfil comercial',
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => _BusinessEditSheet(data: data),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _ReviewCard(status: reviewStatus, plan: data['plan']),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: 'Publicações no mês',
                            value: '$usage / $monthlyLimit',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            label: 'Ativas permitidas',
                            value: '$activeLimit',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: approved
                      ? () => context.push('/business/post/create')
                      : null,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(
                    approved
                        ? 'Criar publicação'
                        : 'Aguardando aprovação para publicar',
                  ),
                ),
                if (!approved)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'A publicação só é liberada depois que o perfil comercial for aprovado.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Suas publicações',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('discoveries')
                      .where('businessId', isEqualTo: uid)
                      .snapshots(),
                  builder: (_, posts) {
                    final docs = posts.data?.docs ?? [];
                    docs.sort((a, b) {
                      final ad =
                          (a.data()['createdAt'] as Timestamp?)?.toDate();
                      final bd =
                          (b.data()['createdAt'] as Timestamp?)?.toDate();
                      return (bd ?? DateTime(1970))
                          .compareTo(ad ?? DateTime(1970));
                    });

                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text('Nenhuma publicação ainda.'),
                      );
                    }

                    return Column(
                      children: [
                        for (final post in docs) _BusinessPostRow(post: post),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Planos comerciais',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 8),
                        Text('GRÁTIS • perfil + 1 publicação ativa'),
                        Text('LOCAL • 5 publicações/mês + métricas'),
                        Text('PRO • destaque, benefícios e métricas completas'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.status, required this.plan});

  final String status;
  final Object? plan;

  @override
  Widget build(BuildContext context) {
    final (icon, title, color) = switch (status) {
      'approved' => (
          Icons.verified_rounded,
          'Perfil aprovado',
          Colors.green,
        ),
      'rejected' => (
          Icons.error_outline_rounded,
          'Perfil precisa de correções',
          AppColors.error,
        ),
      _ => (
          Icons.hourglass_top_rounded,
          'Verificação em análise',
          Colors.orange,
        ),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text('Plano ${(plan ?? 'free').toString().toUpperCase()}'),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
}

class _BusinessEditSheet extends StatefulWidget {
  const _BusinessEditSheet({required this.data});

  final Map<String, dynamic> data;

  @override
  State<_BusinessEditSheet> createState() => _BusinessEditSheetState();
}

class _BusinessEditSheetState extends State<_BusinessEditSheet> {
  late final TextEditingController name;
  late final TextEditingController category;
  late final TextEditingController city;
  late final TextEditingController address;
  late final TextEditingController website;
  late final TextEditingController description;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: (widget.data['name'] ?? '').toString());
    category =
        TextEditingController(text: (widget.data['category'] ?? '').toString());
    city = TextEditingController(text: (widget.data['city'] ?? '').toString());
    address =
        TextEditingController(text: (widget.data['address'] ?? '').toString());
    website = TextEditingController(
      text: (widget.data['websiteUrl'] ?? '').toString(),
    );
    description = TextEditingController(
      text: (widget.data['description'] ?? '').toString(),
    );
  }

  @override
  void dispose() {
    name.dispose();
    category.dispose();
    city.dispose();
    address.dispose();
    website.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty ||
        category.text.trim().isEmpty ||
        city.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      context.snack('Preencha nome, categoria, cidade e endereço.');
      return;
    }

    setState(() => saving = true);
    try {
      double latitude = (widget.data['latitude'] as num?)?.toDouble() ?? 0;
      double longitude = (widget.data['longitude'] as num?)?.toDouble() ?? 0;

      if (address.text.trim() != (widget.data['address'] ?? '').toString()) {
        final points =
            await Geocoding().locationFromAddress(address.text.trim());
        if (points.isEmpty) throw Exception('Endereço não encontrado');
        latitude = points.first.latitude;
        longitude = points.first.longitude;
      }

      await ApiService.instance.updateBusiness({
        'name': name.text.trim(),
        'category': category.text.trim(),
        'city': city.text.trim(),
        'address': address.text.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'websiteUrl': website.text.trim(),
        'description': description.text.trim(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      context.snack('Perfil comercial atualizado.');
    } on ApiException catch (error) {
      if (mounted) context.snack(error.message);
    } catch (_) {
      if (mounted) context.snack('Não foi possível atualizar o perfil.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Editar perfil comercial',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              AppTextField(controller: name, label: 'Nome público'),
              const SizedBox(height: 10),
              AppTextField(controller: category, label: 'Categoria'),
              const SizedBox(height: 10),
              AppTextField(controller: city, label: 'Cidade'),
              const SizedBox(height: 10),
              AppTextField(controller: address, label: 'Endereço'),
              const SizedBox(height: 10),
              AppTextField(controller: website, label: 'Site (opcional)'),
              const SizedBox(height: 10),
              AppTextField(
                controller: description,
                label: 'Sobre',
                maxLines: 4,
              ),
              const SizedBox(height: 18),
              AppButton(
                label: saving ? 'Salvando...' : 'Salvar alterações',
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
      );
}

class _BusinessPostRow extends StatelessWidget {
  const _BusinessPostRow({required this.post});

  final QueryDocumentSnapshot<Map<String, dynamic>> post;

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Arquivar publicação?'),
            content: const Text(
              'Ela deixará de aparecer para os usuários, mas as métricas serão preservadas.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Arquivar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      await ApiService.instance.archiveBusinessPost(post.id);
      if (context.mounted) context.snack('Publicação arquivada.');
    } on ApiException catch (error) {
      if (context.mounted) context.snack(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = post.data();
    final archived = data['status'] == 'archived';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: post.reference.collection('activity_links').snapshots(),
      builder: (context, links) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(child: Text((data['title'] ?? '').toString())),
            if (archived)
              const Chip(
                visualDensity: VisualDensity.compact,
                label: Text('Arquivada'),
              ),
          ],
        ),
        subtitle: Text(
          '${data['views'] ?? 0} visualizações • '
          '${data['opens'] ?? 0} aberturas • '
          '${links.data?.size ?? data['activitiesCreated'] ?? 0} atividades • '
          '${data['participantsGenerated'] ?? 0} participantes',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'open') {
              context.push('/discovery/${post.id}');
            } else if (value == 'edit') {
              context.push('/business/post/${post.id}/edit');
            } else if (value == 'archive') {
              _archive(context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'open', child: Text('Ver publicação')),
            if (!archived)
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (!archived)
              const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
          ],
        ),
        onTap: () => context.push('/discovery/${post.id}'),
      ),
    );
  }
}
