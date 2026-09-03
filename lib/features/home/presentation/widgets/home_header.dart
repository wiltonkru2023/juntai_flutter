import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/juntai_logo.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _HeaderContent(
        name: 'Você',
        photoUrl: null,
        unread: 0,
      );
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userRef.snapshots(),
      builder: (context, profileSnapshot) {
        final data = profileSnapshot.data?.data();
        final name = (data?['name'] ?? user.displayName ?? 'Você')
            .toString()
            .trim();
        final photoUrl = data?['photoUrl']?.toString();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: userRef
              .collection('notifications')
              .where('read', isEqualTo: false)
              .snapshots(),
          builder: (context, notificationSnapshot) {
            final unread = notificationSnapshot.data?.docs.length ?? 0;

            return _HeaderContent(
              name: name.isEmpty ? 'Você' : name,
              photoUrl: photoUrl,
              unread: unread,
            );
          },
        );
      },
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({
    required this.name,
    required this.photoUrl,
    required this.unread,
  });

  final String name;
  final String? photoUrl;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const JuntaiLogo(size: 37),
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () => context.push('/notifications'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => context.go('/profile'),
                child: AppAvatar(
                  name: name,
                  photoUrl: photoUrl,
                  size: 42,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Text(
            'Bora fazer algo hoje? 👋',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Encontre pessoas e atividades perto de você.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
