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
      if (value && key.toLowerCase().contains('notification')) {
        await NotificationService.instance.requestPermission();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (context.mounted) {
        context.snack(
          error.message ?? 'Não foi possível salvar a preferência.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        context.snack(
          'Não foi possível salvar a preferência.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Faça login para acessar suas preferências.',
          ),
        ),
      );
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Privacidade e notificações',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};

          bool value(String key) =>
              data[key] is bool ? data[key] as bool : true;

          Widget setting(
            String key,
            String title,
            String subtitle,
            IconData icon,
          ) =>
              SwitchListTile(
                secondary: Icon(
                  icon,
                  color: AppColors.primary,
                ),
                value: value(key),
                onChanged: (v) => _set(context, key, v),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(subtitle),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Privacidade',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              setting(
                'showCity',
                'Mostrar cidade',
                'Exibe sua cidade no perfil público.',
                Icons.location_on_outlined,
              ),
              setting(
                'showActivities',
                'Mostrar atividades',
                'Exibe suas atividades públicas.',
                Icons.event_outlined,
              ),
              setting(
                'allowInvites',
                'Permitir convites',
                'Permite receber convites de atividade.',
                Icons.person_add_alt_rounded,
              ),
              setting(
                'allowMessages',
                'Permitir mensagens',
                'Permite novas conversas privadas.',
                Icons.chat_bubble_outline_rounded,
              ),
              const Divider(height: 34),
              const Text(
                'Notificações',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              setting(
                'directMessageNotifications',
                'Mensagens privadas',
                'Nova mensagem de outra pessoa.',
                Icons.mark_chat_unread_outlined,
              ),
              setting(
                'groupMessageNotifications',
                'Mensagens de grupo',
                'Novas mensagens nas atividades.',
                Icons.groups_outlined,
              ),
              setting(
                'followerNotifications',
                'Novos seguidores',
                'Quando alguém começar a seguir você.',
                Icons.person_add_outlined,
              ),
              setting(
                'inviteNotifications',
                'Convites',
                'Convites e solicitações de atividades.',
                Icons.mail_outline_rounded,
              ),
              setting(
                'businessNotifications',
                'Comércios seguidos',
                'Novos posts, eventos e benefícios.',
                Icons.storefront_outlined,
              ),
              setting(
                'nearbyOpenSlotsNotifications',
                'Vagas próximas',
                'Vagas abertas perto de você.',
                Icons.flash_on_outlined,
              ),
              setting(
                'eventReminderNotifications',
                'Lembretes de eventos',
                'Lembretes antes de atividades e eventos.',
                Icons.alarm_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}
