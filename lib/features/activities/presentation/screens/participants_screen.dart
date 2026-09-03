import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_avatar.dart';

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  Widget build(BuildContext context) {
    final activityRef =
        FirebaseFirestore.instance.collection('activities').doc(activityId);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: activityRef.snapshots(),
          builder: (context, activitySnapshot) {
            if (!activitySnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (!activitySnapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Atividade não encontrada.',
                ),
              );
            }

            final activity = activitySnapshot.data!.data()!;

            final count = (activity['participantCount'] as num?)?.toInt() ?? 0;

            final max = (activity['maxParticipants'] as num?)?.toInt() ?? 0;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go(
                          '/activity/$activityId',
                        ),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Participantes',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '$count de $max vagas',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: activityRef
                        .collection(
                          'participants',
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final participants = snapshot.data!.docs.toList();

                      participants.sort(
                        (a, b) {
                          final aCreator = a.data()['role'] == 'creator';

                          final bCreator = b.data()['role'] == 'creator';

                          if (aCreator && !bCreator) {
                            return -1;
                          }

                          if (!aCreator && bCreator) {
                            return 1;
                          }

                          return (a.data()['name'] ?? '').toString().compareTo(
                                (b.data()['name'] ?? '').toString(),
                              );
                        },
                      );

                      if (participants.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nenhum participante.',
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(
                          20,
                        ),
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final doc = participants[index];

                          final data = doc.data();

                          final name =
                              (data['name'] ?? 'Participante').toString();

                          final creator = data['role'] == 'creator';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppAvatar(
                              name: name,
                              size: 48,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              creator ? 'Organizador' : 'Participante',
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                            ),
                            onTap: () => context.go(
                              '/profile/user/${doc.id}',
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
