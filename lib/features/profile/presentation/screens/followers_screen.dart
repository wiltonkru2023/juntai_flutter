import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';

class FollowersScreen extends StatelessWidget {
  const FollowersScreen({
    super.key,
    required this.userId,
    required this.mode,
  });

  final String userId;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final followers = mode == 'followers';
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(followers ? 'followers' : 'following');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          followers ? 'Seguidores' : 'Seguindo',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ref.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data!.docs.map((d) => d.id).toList();
          if (ids.isEmpty) {
            return Center(
              child: Text(
                followers
                    ? 'Nenhum seguidor ainda.'
                    : 'Ainda não segue ninguém.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ids.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => _UserRow(userId: ids[index]),
          );
        },
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (_, snapshot) {
          final d = snapshot.data?.data();
          if (d == null) return const SizedBox.shrink();

          final name = (d['name'] ?? 'Usuário').toString();
          final username = (d['username'] ?? '').toString();

          return ListTile(
            onTap: () => context.push('/profile/user/$userId'),
            leading: AppAvatar(
              name: name,
              photoUrl: d['photoUrl']?.toString(),
              size: 44,
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: username.isEmpty ? null : Text('@$username'),
            trailing: const Icon(Icons.chevron_right_rounded),
          );
        },
      );
}
