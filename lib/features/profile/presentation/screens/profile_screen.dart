import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/juntai_logo.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SafeArea(
        child: Center(
          child: Text(
            'Faça login para acessar seu perfil.',
          ),
        ),
      );
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SafeArea(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return SafeArea(
            child: Center(
              child: Text(
                'Erro ao carregar perfil:\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.data == null || !snapshot.data!.exists) {
          return const SafeArea(
            child: Center(
              child: Text(
                'Perfil não encontrado.',
              ),
            ),
          );
        }

        final data = snapshot.data!.data()!;

        final name = (data['name'] ?? 'Usuário').toString();

        final city = (data['city'] ?? '').toString();

        final bio = (data['bio'] ?? '').toString();

        final photoUrl = data['photoUrl']?.toString();

        final verified = data['verified'] == true;

        final rating = (data['rating'] as num?)?.toDouble() ?? 0;

        final interests = data['interests'] is List
            ? List<String>.from(
                (data['interests'] as List).map(
                  (item) => item.toString(),
                ),
              )
            : <String>[];

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              28,
            ),
            children: [
              Row(
                children: [
                  const JuntaiLogo(
                    size: 38,
                  ),
                  const Spacer(),
                  _NotificationButton(
                    uid: user.uid,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AppAvatar(
                        name: name,
                        size: 112,
                        photoUrl: photoUrl,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 2,
                        child: Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () => context.go(
                              '/profile/edit',
                            ),
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (city.isNotEmpty) ...[
                          const SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              Expanded(
                                child: Text(
                                  city,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (bio.isNotEmpty) ...[
                          const SizedBox(
                            height: 7,
                          ),
                          Text(
                            bio,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(
                          height: 10,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 5,
                          children: [
                            if (verified)
                              const Chip(
                                avatar: Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.blue,
                                  size: 18,
                                ),
                                label: Text(
                                  'Verificado',
                                ),
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ProfileStats(
                uid: user.uid,
                interestCount: interests.length,
              ),
              const SizedBox(height: 26),
              _Header(
                'Próximas atividades',
                onTap: () => context.go('/home'),
              ),
              const SizedBox(height: 10),
              _UpcomingActivities(
                uid: user.uid,
              ),
              if (interests.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Header(
                  'Interesses',
                  onTap: () => context.go(
                    '/profile/edit',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: interests.length,
                    itemBuilder: (context, index) {
                      final interest = interests[index];

                      final category = _findCategory(
                        interest,
                      );

                      return Container(
                        width: 112,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: .05,
                              ),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              category?.icon ?? Icons.interests_rounded,
                              color: category?.color ?? AppColors.primary,
                              size: 32,
                            ),
                            const SizedBox(
                              height: 7,
                            ),
                            Text(
                              interest,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(
                      width: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    22,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: .05,
                      ),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _Menu(
                      icon: Icons.edit_rounded,
                      label: 'Editar perfil',
                      onTap: () => context.go(
                        '/profile/edit',
                      ),
                    ),
                    _Menu(
                      icon: Icons.settings_rounded,
                      label: 'Configurações',
                      onTap: () => context.go(
                        '/settings',
                      ),
                    ),
                    _Menu(
                      icon: Icons.storefront_rounded,
                      label: 'Área comercial',
                      onTap: () => context.go('/business'),
                    ),
                    _Menu(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacidade',
                      onTap: () => context.go(
                        '/privacy',
                      ),
                      last: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static ActivityCategory? _findCategory(
    String interest,
  ) {
    for (final category in ActivityCategory.values) {
      if (category.label.toLowerCase() == interest.toLowerCase()) {
        return category;
      }
    }

    return null;
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({
    required this.uid,
    required this.interestCount,
  });

  final String uid;
  final int interestCount;

  @override
  Widget build(BuildContext context) {
    final createdStream = FirebaseFirestore.instance
        .collection('activities')
        .where(
          'creatorId',
          isEqualTo: uid,
        )
        .snapshots();

    final joinedStream = FirebaseFirestore.instance
        .collectionGroup(
          'participants',
        )
        .where(
          'userId',
          isEqualTo: uid,
        )
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: createdStream,
      builder: (
        context,
        createdSnapshot,
      ) {
        final created = createdSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: joinedStream,
          builder: (
            context,
            joinedSnapshot,
          ) {
            final joined = joinedSnapshot.data?.docs.length ?? 0;

            return Container(
              padding: const EdgeInsets.symmetric(
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  22,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: .05,
                    ),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _Stat(
                    value: created,
                    label: 'Atividades\norganizadas',
                    icon: Icons.groups_rounded,
                    color: AppColors.primary,
                  ),
                  _Stat(
                    value: joined,
                    label: 'Participações\nem atividades',
                    icon: Icons.person_rounded,
                    color: AppColors.blue,
                  ),
                  _Stat(
                    value: interestCount,
                    label: 'Interesses\ndo perfil',
                    icon: Icons.interests_rounded,
                    color: AppColors.purple,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _UpcomingActivities extends StatelessWidget {
  const _UpcomingActivities({
    required this.uid,
  });

  final String uid;

  Future<List<Activity>> _load(
    QuerySnapshot<Map<String, dynamic>> memberships,
  ) async {
    final activities = <Activity>[];

    for (final membership in memberships.docs) {
      final activityRef = membership.reference.parent.parent;

      if (activityRef == null) {
        continue;
      }

      final document = await activityRef.get();

      if (!document.exists) {
        continue;
      }

      final activity = Activity.fromFirestore(
        document,
      );

      if (activity.status == 'active' &&
          activity.startsAt.isAfter(
            DateTime.now(),
          )) {
        activities.add(
          activity,
        );
      }
    }

    activities.sort(
      (a, b) => a.startsAt.compareTo(
        b.startsAt,
      ),
    );

    return activities.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup(
            'participants',
          )
          .where(
            'userId',
            isEqualTo: uid,
          )
          .snapshots(),
      builder: (context, membershipSnapshot) {
        if (!membershipSnapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return FutureBuilder<List<Activity>>(
          future: _load(
            membershipSnapshot.data!,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final activities = snapshot.data!;

            if (activities.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 15,
                ),
                child: Text(
                  'Você não possui atividades futuras.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final activity in activities)
                  _CompactActivity(
                    activity: activity,
                    onTap: () => context.go(
                      '/activity/${activity.id}',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
    this.title, {
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          child: const Text(
            'Ver todas ›',
          ),
        ),
      ],
    );
  }
}

class _CompactActivity extends StatelessWidget {
  const _CompactActivity({
    required this.activity,
    required this.onTap,
  });

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = activity.startsAt;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(
          bottom: 10,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            20,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: .04,
              ),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 74,
              decoration: BoxDecoration(
                color: activity.category.color.withValues(
                  alpha: .12,
                ),
                borderRadius: BorderRadius.circular(
                  16,
                ),
              ),
              child: Icon(
                activity.category.icon,
                color: activity.category.color,
                size: 38,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    activity.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/'
                    '${date.month.toString().padLeft(2, '0')} '
                    '• '
                    '${date.hour.toString().padLeft(2, '0')}:'
                    '${date.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.icon,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Icon(
            icon,
            color: AppColors.primary,
          ),
          title: Text(
            label,
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
          ),
        ),
        if (!last)
          const Divider(
            height: 1,
            indent: 56,
          ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where(
            'read',
            isEqualTo: false,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        final unread = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push(
                '/notifications',
              ),
              icon: const Icon(
                Icons.notifications_none_rounded,
                size: 28,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 1,
                top: 0,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
