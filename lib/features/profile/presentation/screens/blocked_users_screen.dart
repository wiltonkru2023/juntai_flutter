import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_avatar.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
    BuildContext context,
    String uid,
    String blockedId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('blocks')
          .doc(blockedId)
          .delete();

      if (!context.mounted) return;
      context.snack('Usuário desbloqueado.');
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message ?? 'Não foi possível desbloquear.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Faça login para continuar.')),
      );
    }

    final blocks = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('blocks');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/settings'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Usuários bloqueados',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: blocks.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Não foi possível carregar os bloqueios.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: 52),
                    SizedBox(height: 12),
                    Text(
                      'Nenhum usuário bloqueado.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final block = docs[index];
              return _BlockedUserTile(
                blockedId: block.id,
                blockData: block.data(),
                onUnblock: () => _unblock(
                  context,
                  user.uid,
                  block.id,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.blockedId,
    required this.blockData,
    required this.onUnblock,
  });

  final String blockedId;
  final Map<String, dynamic> blockData;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final storedName = (blockData['name'] ?? '').toString().trim();
    final storedPhoto = blockData['photoUrl']?.toString();

    if (storedName.isNotEmpty) {
      return _tile(storedName, storedPhoto);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(blockedId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['name'] ?? 'Usuário').toString();
        final photoUrl = data?['photoUrl']?.toString();
        return _tile(name, photoUrl);
      },
    );
  }

  Widget _tile(String name, String? photoUrl) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AppAvatar(
        name: name,
        photoUrl: photoUrl,
        size: 48,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(blockedId),
      trailing: TextButton(
        onPressed: onUnblock,
        child: const Text('Desbloquear'),
      ),
    );
  }
}
