import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'public_profile_screen.dart';

class ProfileByUsernameScreen extends StatelessWidget {
  const ProfileByUsernameScreen({
    super.key,
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('usernames')
            .doc(username.toLowerCase().replaceFirst('@', ''))
            .get(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final uid = snapshot.data?.data()?['uid']?.toString();
          if (uid == null || uid.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Perfil não encontrado.')),
            );
          }

          return PublicProfileScreen(userId: uid);
        },
      );
}
