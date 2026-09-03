import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../../../moderation/presentation/report_activity_sheet.dart';
import '../../data/activity_participation_service.dart';
import '../widgets/participants_avatar_row.dart';

class ActivityDetailsScreen extends StatefulWidget {
  const ActivityDetailsScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  final ActivityParticipationService _participation =
      ActivityParticipationService();

  bool loading = false;

  DocumentReference<Map<String, dynamic>> get _activityRef =>
      FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId);

  Future<void> _run(
    Future<void> Function() action,
    String success,
  ) async {
    if (loading) return;

    setState(() => loading = true);

    try {
      await action();

      if (!mounted) return;
      context.snack(success);
    } on ActivityParticipationException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      context.snack(
        error.message ?? 'Não foi possível concluir a ação.',
      );
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível concluir a ação.');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _cancel(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar atividade?'),
        content: const Text(
          'Os participantes serão avisados e ninguém novo poderá entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Cancelar atividade',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _run(
      () async {
        await ApiService.instance.cancelActivity(widget.activityId);
      },
      'Atividade cancelada.',
    );
  }

  Future<void> _report(String reason) async {
    try {
      await ApiService.instance.reportContent(
        targetType: 'activity',
        targetId: widget.activityId,
        reason: reason,
      );

      if (!mounted) return;
      context.snack('Denúncia enviada. Obrigado por avisar.');
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a denúncia.');
    }
  }

  void _showReport() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ReportActivitySheet(
        onSubmit: _report,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _activityRef.snapshots(),
      builder: (context, activitySnapshot) {
        if (activitySnapshot.connectionState == ConnectionState.waiting &&
            !activitySnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (activitySnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar atividade:\n${activitySnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final document = activitySnapshot.data;

        if (document == null || !document.exists) {
          return const Scaffold(
            body: Center(child: Text('Atividade não encontrada.')),
          );
        }

        final activity = Activity.fromFirestore(document);
        final isCreator = uid != null && activity.creatorId == uid;

        final participantRef =
            _activityRef.collection('participants').doc(uid ?? '_none_');

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: uid == null ? null : participantRef.snapshots(),
          builder: (context, participantSnapshot) {
            final joined =
                isCreator || participantSnapshot.data?.exists == true;

            final requestRef =
                _activityRef.collection('join_requests').doc(uid ?? '_none_');

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: uid != null && activity.isPrivate && !isCreator
                  ? requestRef.snapshots()
                  : null,
              builder: (context, requestSnapshot) {
                final requestStatus =
                    requestSnapshot.data?.data()?['status']?.toString();

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _activityRef.collection('participants').snapshots(),
                  builder: (context, participantsSnapshot) {
                    final names = participantsSnapshot.data?.docs
                            .map(
                              (doc) => (doc.data()['name'] ?? 'Participante')
                                  .toString(),
                            )
                            .toList() ??
                        <String>[];

                    return Scaffold(
                      body: SafeArea(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Container(
                              height: 230,
                              decoration: BoxDecoration(
                                color: activity.category.color
                                    .withValues(alpha: .12),
                              ),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _ActivityHeaderImage(
                                      activity: activity,
                                    ),
                                  ),
                                  Positioned(
                                    left: 16,
                                    top: 14,
                                    child: _CircleButton(
                                      icon: Icons.arrow_back_rounded,
                                      onTap: () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/home');
                                        }
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    right: 68,
                                    top: 14,
                                    child: _CircleButton(
                                      icon: Icons.share_rounded,
                                      onTap: () {
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text: '${activity.title}\n'
                                                '${AppConstants.deepLinkBase}/activity/${activity.id}\n'
                                                'Abrir no Juntaí: juntai:///activity/${activity.id}',
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    right: 16,
                                    top: 14,
                                    child: PopupMenuButton<String>(
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                      ),
                                      color: Colors.white,
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          context.go(
                                            '/activity/${activity.id}/edit',
                                          );
                                        } else if (value == 'report') {
                                          _showReport();
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        if (isCreator)
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar atividade'),
                                          ),
                                        if (!isCreator)
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Text('Denunciar atividade'),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -24),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  24,
                                  22,
                                  30,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(28),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            activity.title,
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        if (activity.isPrivate)
                                          const Padding(
                                            padding: EdgeInsets.only(top: 7),
                                            child: Icon(
                                              Icons.lock_rounded,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _Tag(
                                          icon: activity.category.icon,
                                          label: activity.category.label,
                                          color: activity.category.color,
                                        ),
                                        if (activity.isPrivate)
                                          const _Tag(
                                            icon: Icons.lock_outline_rounded,
                                            label: 'Privada',
                                            color: AppColors.purple,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    _Info(
                                      icon: Icons.location_on_outlined,
                                      text: activity.address,
                                    ),
                                    _Info(
                                      icon: Icons.calendar_month_outlined,
                                      text: _when(activity.startsAt),
                                    ),
                                    _Info(
                                      icon: Icons.groups_rounded,
                                      text:
                                          '${activity.participantCount} / ${activity.maxParticipants} participantes',
                                    ),
                                    _Info(
                                      icon: Icons.person_outline_rounded,
                                      text:
                                          'Criado por ${activity.creatorName}',
                                    ),
                                    if (activity.sourceDiscoveryId != null)
                                      InkWell(
                                        onTap: () => context.push(
                                            '/discovery/${activity.sourceDiscoveryId}'),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 7),
                                          child: Row(children: [
                                            const Icon(
                                                Icons.auto_awesome_rounded,
                                                color: AppColors.primary),
                                            const SizedBox(width: 10),
                                            const Text('Inspirada por ',
                                                style: TextStyle(
                                                    color: AppColors
                                                        .textSecondary)),
                                            Flexible(
                                                child: Text(
                                                    activity.sourceBusinessName ??
                                                        'Local',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: AppColors
                                                            .primary))),
                                            if (activity.sourceBusinessVerified)
                                              const Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Icon(
                                                      Icons.verified_rounded,
                                                      size: 17,
                                                      color: AppColors.blue)),
                                          ]),
                                        ),
                                      ),
                                    const Divider(height: 30),
                                    Text(
                                      activity.description.isEmpty
                                          ? 'Encontro aberto para conhecer pessoas e aproveitar a atividade.'
                                          : activity.description,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        height: 1.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    if (activity.status == 'cancelled')
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.error
                                              .withValues(alpha: .1),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Atividade cancelada',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      )
                                    else if (isCreator)
                                      const AppButton(
                                        label: 'Você é o organizador',
                                        icon: Icons.verified_rounded,
                                        onPressed: null,
                                      )
                                    else
                                      AppButton(
                                        label: _buttonLabel(
                                          activity: activity,
                                          joined: joined,
                                          requestStatus: requestStatus,
                                          loading: loading,
                                        ),
                                        icon: joined
                                            ? Icons.logout_rounded
                                            : activity.isPrivate
                                                ? Icons.lock_open_rounded
                                                : Icons
                                                    .person_add_alt_1_rounded,
                                        onPressed: _canAct(
                                          activity: activity,
                                          joined: joined,
                                          requestStatus: requestStatus,
                                        )
                                            ? () {
                                                if (joined) {
                                                  _run(
                                                    () => _participation.leave(
                                                      activity.id,
                                                    ),
                                                    'Você saiu da atividade.',
                                                  );
                                                } else if (activity.isPrivate) {
                                                  _run(
                                                    () => _participation
                                                        .requestPrivate(
                                                      activity.id,
                                                    ),
                                                    'Solicitação enviada ao organizador.',
                                                  );
                                                } else {
                                                  _run(
                                                    () => _participation
                                                        .joinPublic(
                                                      activity.id,
                                                    ),
                                                    'Você entrou na atividade!',
                                                  );
                                                }
                                              }
                                            : null,
                                      ),
                                    if (activity.isPrivate &&
                                        !isCreator &&
                                        requestStatus == 'rejected' &&
                                        !joined) ...[
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Sua solicitação anterior foi recusada. Você pode enviar uma nova solicitação.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: joined || isCreator
                                            ? () => context.go(
                                                  '/chat/${activity.id}',
                                                )
                                            : null,
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                        ),
                                        label: const Text('Chat do grupo'),
                                      ),
                                    ),
                                    if (isCreator && activity.isPrivate) ...[
                                      const SizedBox(height: 26),
                                      _PendingRequests(
                                        activityId: activity.id,
                                        participation: _participation,
                                      ),
                                    ],
                                    const SizedBox(height: 26),
                                    Row(
                                      children: [
                                        const Text(
                                          'Quem vai',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () => context.go(
                                            '/activity/${activity.id}/participants',
                                          ),
                                          child: const Text('Ver todos ›'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () => context.go(
                                        '/activity/${activity.id}/participants',
                                      ),
                                      child: ParticipantAvatarRow(
                                        names: names,
                                        maxVisible: 7,
                                      ),
                                    ),
                                    if (isCreator) ...[
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed:
                                                  activity.status == 'cancelled'
                                                      ? null
                                                      : () => context.go(
                                                            '/activity/${activity.id}/edit',
                                                          ),
                                              icon: const Icon(
                                                Icons.edit_rounded,
                                              ),
                                              label: const Text('Editar'),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed:
                                                  activity.status == 'cancelled'
                                                      ? null
                                                      : () => _cancel(activity),
                                              icon: const Icon(
                                                Icons.cancel_outlined,
                                              ),
                                              label: const Text('Cancelar'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  bool _canAct({
    required Activity activity,
    required bool joined,
    required String? requestStatus,
  }) {
    if (loading || activity.status != 'active') return false;
    if (!joined && activity.isFull) return false;
    if (activity.isPrivate &&
        !joined &&
        (requestStatus == 'pending' || requestStatus == 'accepted')) {
      return false;
    }
    return true;
  }

  String _buttonLabel({
    required Activity activity,
    required bool joined,
    required String? requestStatus,
    required bool loading,
  }) {
    if (loading) return 'Aguarde...';
    if (joined) return 'Sair da atividade';
    if (activity.isFull) return 'Atividade lotada';

    if (activity.isPrivate) {
      if (requestStatus == 'pending') return 'Solicitação enviada';
      if (requestStatus == 'accepted') return 'Participação aprovada';
      if (requestStatus == 'rejected') return 'Solicitar novamente';
      return 'Solicitar participação';
    }

    return 'Participar';
  }

  static String _when(DateTime date) {
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final day = sameDay
        ? 'Hoje'
        : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}';

    return '$day • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PendingRequests extends StatefulWidget {
  const _PendingRequests({
    required this.activityId,
    required this.participation,
  });

  final String activityId;
  final ActivityParticipationService participation;

  @override
  State<_PendingRequests> createState() => _PendingRequestsState();
}

class _PendingRequestsState extends State<_PendingRequests> {
  final Set<String> busy = <String>{};

  Future<void> _respond(
    BuildContext context,
    String userId,
    bool accept,
  ) async {
    if (busy.contains(userId)) return;

    setState(() => busy.add(userId));

    try {
      await widget.participation.respondRequest(
        activityId: widget.activityId,
        userId: userId,
        accept: accept,
      );

      if (!context.mounted) return;
      context.snack(
        accept ? 'Solicitação aceita.' : 'Solicitação recusada.',
      );
    } on ActivityParticipationException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message);
    } finally {
      if (mounted) {
        setState(() => busy.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .doc(widget.activityId)
          .collection('join_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                requests.length == 1
                    ? '1 solicitação pendente'
                    : '${requests.length} solicitações pendentes',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (final request in requests) ...[
                _RequestRow(
                  name: (request.data()['name'] ?? 'Usuário').toString(),
                  busy: busy.contains(request.id),
                  onReject: () => _respond(context, request.id, false),
                  onAccept: () => _respond(context, request.id, true),
                ),
                if (request != requests.last) const Divider(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.name,
    required this.busy,
    required this.onReject,
    required this.onAccept,
  });

  final String name;
  final bool busy;
  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onReject,
                child: const Text('Recusar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onAccept,
                child: Text(busy ? 'Aguarde...' : 'Aceitar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActivityHeaderImage extends StatelessWidget {
  const _ActivityHeaderImage({
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final cover = activity.coverUrl?.trim() ?? '';

    if (cover.isEmpty) {
      return Container(
        color: activity.category.color.withValues(alpha: .12),
        alignment: Alignment.center,
        child: Icon(
          activity.category.icon,
          size: 100,
          color: activity.category.color,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          cover,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: activity.category.color.withValues(alpha: .12),
            alignment: Alignment.center,
            child: Icon(
              activity.category.icon,
              size: 100,
              color: activity.category.color,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .22),
                Colors.transparent,
                Colors.black.withValues(alpha: .08),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
