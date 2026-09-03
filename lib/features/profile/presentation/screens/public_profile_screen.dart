import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/interest_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../../../moderation/presentation/block_user_dialog.dart';
import '../../../moderation/presentation/report_user_sheet.dart';
import '../../data/social_service.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  Future<void> _block(
    BuildContext context,
    String currentUid,
    Map<String, dynamic> profile,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blocks')
          .doc(userId)
          .set({
        'blockedUserId': userId,
        'name': (profile['name'] ?? 'Usuário').toString(),
        'photoUrl': profile['photoUrl'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      context.snack('Usuário bloqueado.');
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message ?? 'Não foi possível bloquear o usuário.');
    }
  }

  Future<void> _unblock(
    BuildContext context,
    String currentUid,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('blocks')
          .doc(userId)
          .delete();

      if (!context.mounted) return;
      context.snack('Usuário desbloqueado.');
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message ?? 'Não foi possível desbloquear o usuário.');
    }
  }

  Future<void> _report(
    BuildContext context,
    String reason,
  ) async {
    try {
      await ApiService.instance.reportContent(
        targetType: 'user',
        targetId: userId,
        reason: reason,
      );

      if (!context.mounted) return;
      context.snack('Denúncia enviada. Obrigado por ajudar a comunidade.');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message);
    } catch (_) {
      if (!context.mounted) return;
      context.snack('Não foi possível enviar a denúncia.');
    }
  }

  void _showReport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReportUserSheet(
        onSubmit: (reason) => _report(context, reason),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Faça login para continuar.')),
      );
    }

    if (currentUser.uid == userId) {
      return const Scaffold(
        body: Center(child: Text('Este é o seu próprio perfil.')),
      );
    }

    final profileRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

    final blockRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocks')
        .doc(userId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileRef.snapshots(),
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting &&
            !profileSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (profileSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Não foi possível carregar o perfil.\n${profileSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final document = profileSnapshot.data;
        if (document == null || !document.exists) {
          return const Scaffold(
            body: Center(child: Text('Perfil não encontrado.')),
          );
        }

        final data = document.data()!;
        final name = (data['name'] ?? 'Usuário').toString();
        final username = (data['username'] ?? '').toString();
        final photoUrl = data['photoUrl']?.toString();
        final city = (data['city'] ?? '').toString();
        final bio = (data['bio'] ?? '').toString();
        final verified = data['verified'] == true;
        final rating = (data['rating'] as num?)?.toDouble() ?? 0;
        final interests = data['interests'] is List
            ? InterestService.normalizeList(
                data['interests'] as List,
              )
            : <String>[];
        final showCity = data['showCity'] != false;
        final showActivities = data['showActivities'] != false;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: blockRef.snapshots(),
          builder: (context, blockSnapshot) {
            final blocked = blockSnapshot.data?.exists == true;

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'report') {
                        _showReport(context);
                        return;
                      }

                      if (value == 'unblock') {
                        _unblock(context, currentUser.uid);
                        return;
                      }

                      if (value == 'block') {
                        showDialog<void>(
                          context: context,
                          builder: (_) => BlockUserDialog(
                            name: name,
                            onConfirm: () => _block(
                              context,
                              currentUser.uid,
                              data,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: blocked ? 'unblock' : 'block',
                        child: Text(
                          blocked ? 'Desbloquear usuário' : 'Bloquear usuário',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'report',
                        child: Text('Denunciar usuário'),
                      ),
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                  children: [
                    Center(
                      child: AppAvatar(
                        name: name,
                        photoUrl: photoUrl,
                        size: 120,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text('@$username',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    if (showCity && city.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          Flexible(
                            child: Text(
                              ' $city',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (verified)
                            const Chip(
                              avatar: Icon(
                                Icons.verified_rounded,
                                color: AppColors.blue,
                                size: 18,
                              ),
                              label: Text('Verificado'),
                            ),
                          if (rating > 0)
                            Chip(
                              avatar: const Icon(
                                Icons.star_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              label: Text(
                                'Nota ${rating.toStringAsFixed(1).replaceAll('.', ',')}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _PS(
                          value:
                              '${(data['activitiesCreated'] as num?)?.toInt() ?? 0}',
                          label: 'Atividades',
                        ),
                        _PS(
                          value:
                              '${(data['activitiesJoined'] as num?)?.toInt() ?? 0}',
                          label: 'Participações',
                        ),
                        _PS(
                          value: rating > 0
                              ? rating.toStringAsFixed(1).replaceAll('.', ',')
                              : '—',
                          label: 'Avaliação',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (blocked)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Você bloqueou este usuário. Desbloqueie para voltar a interagir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else ...[
                      _SocialActions(
                          currentUid: currentUser.uid, userId: userId),
                      const SizedBox(height: 18),
                      _FollowStats(userId: userId),
                      const SizedBox(height: 18),
                      if (interests.isNotEmpty) ...[
                        const Text(
                          'Interesses',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: interests
                              .map((interest) => Chip(label: Text(interest)))
                              .toList(),
                        ),
                      ],
                      if (showActivities) ...[
                        const SizedBox(height: 26),
                        const Text(
                          'Atividades públicas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PublicActivities(userId: userId),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SocialActions extends StatelessWidget {
  const _SocialActions({required this.currentUid, required this.userId});
  final String currentUid;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final service = SocialService(FirebaseFirestore.instance);
    return StreamBuilder<bool>(
      stream: service.watchFollowing(currentUid, userId),
      builder: (context, snapshot) {
        final following = snapshot.data == true;
        return Row(children: [
          Expanded(
              child: FilledButton(
            onPressed: () async {
              try {
                await service.setFollowing(currentUid, userId, !following);
              } on FirebaseException catch (e) {
                if (context.mounted) {
                  context.snack(e.message ?? 'Não foi possível atualizar.');
                }
              }
            },
            child: Text(following ? 'Seguindo' : 'Seguir'),
          )),
          const SizedBox(width: 10),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => context.push('/message/$userId'),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Enviar mensagem'),
          )),
        ]);
      },
    );
  }
}

class _FollowStats extends StatelessWidget {
  const _FollowStats({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (_, snapshot) {
          final d = snapshot.data?.data() ?? const <String, dynamic>{};

          final followers = (d['followersCount'] as num?)?.toInt() ?? 0;
          final following = (d['followingCount'] as num?)?.toInt() ?? 0;

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/followers/$userId'),
                child: Text('$followers seguidores'),
              ),
              const Text('•'),
              TextButton(
                onPressed: () => context.push('/following/$userId'),
                child: Text('$following seguindo'),
              ),
            ],
          );
        },
      );
}

class _PublicActivities extends StatelessWidget {
  const _PublicActivities({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('creatorId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final activities = snapshot.data!.docs
            .map(Activity.fromFirestore)
            .where(
              (activity) =>
                  !activity.isPrivate &&
                  activity.status == 'active' &&
                  activity.startsAt.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

        if (activities.isEmpty) {
          return const Text(
            'Nenhuma atividade pública futura.',
            style: TextStyle(color: AppColors.textSecondary),
          );
        }

        return Column(
          children: [
            for (final activity in activities.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => context.push('/activity/${activity.id}'),
                leading: CircleAvatar(
                  backgroundColor:
                      activity.category.color.withValues(alpha: .12),
                  child: Icon(
                    activity.category.icon,
                    color: activity.category.color,
                  ),
                ),
                title: Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(activity.address),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        );
      },
    );
  }
}

class _PS extends StatelessWidget {
  const _PS({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
