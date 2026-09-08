import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

class BusinessCenterScreen extends StatelessWidget {
  const BusinessCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Faça login.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Área comercial',
            style: TextStyle(fontWeight: FontWeight.w900)),
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
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 18),
                Image.asset(
                  'assets/icons/icone_comunidade.png',
                  height: 82,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Escolha como você quer aparecer no Juntaí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Comércios divulgam locais, promoções e vagas. Profissionais '
                  'oferecem serviços, aulas, consultorias e experiências.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 28),
                _CreateProfileCard(
                  icon: Icons.storefront_rounded,
                  title: 'Comércio local',
                  body: 'Restaurantes, bares, academias, lojas e espaços.',
                  action: 'Cadastrar comércio',
                  onTap: () => context.push('/business/create?type=business'),
                ),
                const SizedBox(height: 12),
                _CreateProfileCard(
                  icon: Icons.badge_outlined,
                  title: 'Profissional',
                  body:
                      'Personal, professor, guia, fotógrafo, terapeuta e mais.',
                  action: 'Cadastrar profissional',
                  onTap: () =>
                      context.push('/business/create?type=professional'),
                ),
                const SizedBox(height: 12),
                _CreateProfileCard(
                  icon: Icons.event_available_rounded,
                  title: 'Organizador ou instituição',
                  body: 'Eventos, coletivos, ONGs, clubes e projetos.',
                  action: 'Cadastrar organização',
                  onTap: () => context.push('/business/create?type=organizer'),
                ),
              ],
            );
          }

          final d = snapshot.data!.data()!;
          final reviewStatus = (d['reviewStatus'] ?? 'pending').toString();

          return ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: (d['photoUrl'] ?? '').toString().isNotEmpty
                        ? NetworkImage(d['photoUrl'].toString())
                        : null,
                    child: (d['photoUrl'] ?? '').toString().isEmpty
                        ? const Icon(Icons.store_rounded)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (d['name'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (d['verified'] == true)
                              const Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(Icons.verified_rounded,
                                    color: Colors.blue),
                              ),
                          ],
                        ),
                        Text('@${d['username'] ?? ''}'),
                        Text('${d['city'] ?? ''} • ${d['state'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: Icon(
                    reviewStatus == 'approved'
                        ? Icons.verified_rounded
                        : reviewStatus == 'rejected'
                            ? Icons.error_outline_rounded
                            : Icons.hourglass_top_rounded,
                    color: reviewStatus == 'approved'
                        ? Colors.green
                        : reviewStatus == 'rejected'
                            ? AppColors.error
                            : Colors.orange,
                  ),
                  title: Text(
                    reviewStatus == 'approved'
                        ? 'Perfil aprovado'
                        : reviewStatus == 'rejected'
                            ? 'Perfil precisa de correções'
                            : 'Verificação em análise',
                  ),
                  subtitle: Text(
                    'Plano ${(d['plan'] ?? 'free').toString().toUpperCase()}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => context.push('/business/$uid/dashboard'),
                icon: const Icon(Icons.dashboard_rounded),
                label: const Text('Abrir painel comercial'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/business/edit'),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar perfil completo'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/business/$uid'),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Ver perfil público'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreateProfileCard extends StatelessWidget {
  const _CreateProfileCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        action,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      );
}
