import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/notification_service.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  Future<void> _set(
    BuildContext context,
    String key,
    bool value,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    try {
      if (value &&
          (key == 'chatNotifications' ||
              key == 'activityNotifications')) {
        await NotificationService.instance.requestPermission();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          key: value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      context.snack(
        error.message ?? 'Não foi possível salvar a preferência.',
      );
    } catch (_) {
      if (!context.mounted) return;
      context.snack('Não foi possível salvar a preferência.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Faça login para acessar suas preferências.'),
        ),
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Privacidade',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar suas preferências.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};

          bool value(String key) => data[key] is bool ? data[key] as bool : true;

          Widget setting(
            String key,
            String title,
            String subtitle,
            IconData icon,
          ) {
            return SwitchListTile(
              secondary: Icon(icon, color: AppColors.primary),
              value: value(key),
              onChanged: (newValue) => _set(context, key, newValue),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(subtitle),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 6, 8, 10),
                child: Text(
                  'Perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              setting(
                'showCity',
                'Mostrar cidade',
                'Exibe sua cidade no seu perfil público.',
                Icons.location_on_outlined,
              ),
              setting(
                'showActivities',
                'Mostrar atividades no perfil',
                'Exibe as atividades públicas que você organiza.',
                Icons.event_outlined,
              ),
              setting(
                'allowInvites',
                'Permitir convites',
                'Permite receber convites para novas atividades.',
                Icons.person_add_alt_1_outlined,
              ),
              setting(
                'allowMessages',
                'Permitir mensagens',
                'Controla novas interações de mensagem quando aplicável.',
                Icons.chat_bubble_outline_rounded,
              ),
              const Divider(height: 34),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 10),
                child: Text(
                  'Notificações',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              setting(
                'chatNotifications',
                'Notificações de chat',
                'Receber alertas de novas mensagens do grupo.',
                Icons.notifications_active_outlined,
              ),
              setting(
                'activityNotifications',
                'Notificações de atividades',
                'Receber solicitações, aprovações e alterações de atividades.',
                Icons.event_available_outlined,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Usuários bloqueados não podem gerar novas interações sociais para você. '
                        'Atualizações importantes de atividades das quais você já participa continuam visíveis.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
