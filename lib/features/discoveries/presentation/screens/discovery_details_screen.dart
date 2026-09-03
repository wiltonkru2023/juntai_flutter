import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/activity.dart';
import '../../../home/presentation/widgets/activity_card.dart';
import '../../domain/discovery.dart';

class DiscoveryDetailsScreen extends StatelessWidget {
  const DiscoveryDetailsScreen({super.key, required this.discoveryId});
  final String discoveryId;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('discoveries')
              .doc(discoveryId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.data!.exists) {
              return const Center(child: Text('Descoberta não encontrada.'));
            }

            final discovery = Discovery.fromFirestore(snapshot.data!);
            final currentUid = FirebaseAuth.instance.currentUser?.uid;
            if (discovery.status != 'published' &&
                discovery.businessId != currentUid) {
              return const Center(
                child: Text('Esta publicação não está disponível.'),
              );
            }

            return _DiscoveryBody(discovery: discovery);
          },
        ),
      );
}

class _DiscoveryBody extends StatefulWidget {
  const _DiscoveryBody({required this.discovery});
  final Discovery discovery;

  @override
  State<_DiscoveryBody> createState() => _DiscoveryBodyState();
}

class _DiscoveryBodyState extends State<_DiscoveryBody> {
  bool tracked = false;

  Discovery get d => widget.discovery;

  @override
  Widget build(BuildContext context) {
    if (!tracked) {
      tracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ApiService.instance
            .trackBusinessPost(d.id, 'open')
            .catchError((_) => <String, dynamic>{});
      });
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: (d.coverUrl ?? '').isEmpty ? 120 : 285,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: (d.coverUrl ?? '').isEmpty
                ? const ColoredBox(color: AppColors.primaryLight)
                : Image.network(d.coverUrl!, fit: BoxFit.cover),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList.list(
            children: [
              InkWell(
                onTap: () => context.push('/business/${d.businessId}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (d.businessVerified)
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.blue,
                      ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              Text(
                d.businessCategory,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(_typeLabel(d.type))),
                  if (d.sponsored) const Chip(label: Text('Patrocinado')),
                  if (d.officialEvent)
                    const Chip(label: Text('Evento oficial')),
                ],
              ),
              Text(
                d.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                d.description,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              if (d.eventStartsAt != null) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(_date(d.eventStartsAt!)),
                  subtitle: d.eventEndsAt == null
                      ? null
                      : Text('Até ${_date(d.eventEndsAt!)}'),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                ),
                title: Text(d.address),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=${d.latitude},${d.longitude}',
                      ),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.directions_rounded),
                    label: const Text('Como chegar'),
                  ),
                  if ((d.websiteUrl ?? '').isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(d.websiteUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.language_rounded),
                      label: const Text('Site'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://juntai-flutter.onrender.com/discovery/${d.id}',
                        ),
                      );
                      try {
                        await ApiService.instance
                            .trackBusinessPost(d.id, 'share');
                      } catch (_) {}
                      if (context.mounted) {
                        context.snack('Link copiado para compartilhar.');
                      }
                    },
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartilhar'),
                  ),
                ],
              ),
              if (d.price != null || d.juntaiPrice != null) ...[
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      d.juntaiPrice != null
                          ? 'Juntaí R\$ ${d.juntaiPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
                          : 'R\$ ${d.price!.toStringAsFixed(2).replaceAll('.', ',')}',
                    ),
                    subtitle: d.juntaiPrice != null && d.price != null
                        ? Text(
                            'Preço normal R\$ ${d.price!.toStringAsFixed(2).replaceAll('.', ',')}',
                          )
                        : null,
                  ),
                ),
              ],
              if (d.isOpenSlots && d.maxParticipants > 0) ...[
                const SizedBox(height: 14),
                _Progress(discovery: d),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: d.isFull
                      ? null
                      : () async {
                          try {
                            final result =
                                await ApiService.instance.claimOpenSlot(d.id);
                            if (!context.mounted) return;

                            final code =
                                (result['benefitCode'] ?? '').toString();
                            context.snack(
                              code.isEmpty
                                  ? 'Sua vaga foi confirmada!'
                                  : 'Vaga confirmada e benefício desbloqueado!',
                            );
                          } on ApiException catch (e) {
                            if (context.mounted) context.snack(e.message);
                          }
                        },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(d.isFull ? 'Grupo completo' : 'Eu vou'),
                ),
              ],
              if (d.isSchedule && d.availabilitySlots.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Horários disponíveis',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final slot in d.availabilitySlots)
                  _SlotTile(postId: d.id, slot: slot),
              ],
              if ((d.groupBenefit ?? '').isNotEmpty) ...[
                const SizedBox(height: 14),
                Card(
                  child: ListTile(
                    leading: Icon(
                      d.benefitUnlocked
                          ? Icons.card_giftcard_rounded
                          : Icons.groups_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      d.benefitUnlocked
                          ? 'Benefício desbloqueado'
                          : 'Benefício para o grupo',
                    ),
                    subtitle: Text(d.groupBenefit!),
                  ),
                ),
                if (d.benefitUnlocked && (d.benefitCode ?? '').isNotEmpty)
                  FilledButton.tonalIcon(
                    onPressed: () => context.push('/benefit/${d.benefitCode}'),
                    icon: const Icon(Icons.qr_code_rounded),
                    label: Text('Código ${d.benefitCode}'),
                  ),
              ],
              const SizedBox(height: 10),
              if (!d.isOpenSlots && !d.isSchedule)
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/activity/create?source=${d.id}'),
                  icon: const Icon(Icons.group_add_rounded),
                  label: Text(d.ctaLabel),
                ),
              _InterestedButton(postId: d.id),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d.interestedCount} pessoas querem ir',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.push('/activity/create?source=${d.id}'),
                    child: const Text('Criar meu grupo'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Encontrar companhia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _RelatedGroups(discoveryId: d.id),
            ],
          ),
        ),
      ],
    );
  }

  static String _typeLabel(String value) => switch (value) {
        'event' => 'Evento',
        'open_slots' => 'Vagas abertas',
        'promotion' => 'Promoção',
        'schedule' => 'Horários',
        _ => 'Experiência',
      };

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year} • '
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

class _InterestedButton extends StatefulWidget {
  const _InterestedButton({required this.postId});
  final String postId;

  @override
  State<_InterestedButton> createState() => _InterestedButtonState();
}

class _InterestedButtonState extends State<_InterestedButton> {
  bool? interested;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('discoveries')
        .doc(widget.postId)
        .collection('interested')
        .doc(uid)
        .get();

    if (mounted) setState(() => interested = doc.exists);
  }

  Future<void> _toggle() async {
    if (busy) return;
    final next = interested != true;
    setState(() => busy = true);

    try {
      await ApiService.instance.setInterested(
        widget.postId,
        interested: next,
      );
      if (mounted) setState(() => interested = next);
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: interested == null || busy ? null : _toggle,
        icon: Icon(
          interested == true
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
        ),
        label: Text(
          busy
              ? 'Aguarde...'
              : interested == true
                  ? 'Quero ir ✓'
                  : 'Quero ir',
        ),
      );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.discovery});
  final Discovery discovery;

  @override
  Widget build(BuildContext context) {
    final max = discovery.maxParticipants;
    final current = discovery.claimedParticipants.clamp(0, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: max <= 0 ? 0 : current / max,
          minHeight: 10,
          borderRadius: BorderRadius.circular(99),
        ),
        const SizedBox(height: 7),
        Text(
          '$current/$max confirmados • '
          '${discovery.remainingSlots == 0 ? 'grupo completo' : 'faltam ${discovery.remainingSlots}'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.postId, required this.slot});
  final String postId;
  final Map<String, dynamic> slot;

  @override
  Widget build(BuildContext context) {
    final capacity = (slot['capacity'] as num?)?.toInt() ?? 0;
    final claimed = (slot['claimed'] as num?)?.toInt() ?? 0;
    final full = capacity > 0 && claimed >= capacity;
    final label = (slot['label'] ?? '').toString();

    return Card(
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          full
              ? 'Lotado'
              : capacity > 0
                  ? 'Faltam ${(capacity - claimed).clamp(0, capacity)}'
                  : 'Disponível',
        ),
        trailing: FilledButton(
          onPressed: full
              ? null
              : () async {
                  try {
                    await ApiService.instance.claimOpenSlot(
                      postId,
                      slotLabel: label,
                    );
                    if (context.mounted) {
                      context.snack('Horário confirmado!');
                    }
                  } on ApiException catch (e) {
                    if (context.mounted) context.snack(e.message);
                  }
                },
          child: Text(full ? 'Lotado' : 'Eu vou'),
        ),
      ),
    );
  }
}

class _RelatedGroups extends StatelessWidget {
  const _RelatedGroups({required this.discoveryId});
  final String discoveryId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('activities')
            .where('sourceDiscoveryId', isEqualTo: discoveryId)
            .snapshots(),
        builder: (context, snapshot) {
          final groups = (snapshot.data?.docs ?? [])
              .map(Activity.fromFirestore)
              .where(
                (a) =>
                    !a.isPrivate &&
                    a.status == 'active' &&
                    a.startsAt.isAfter(DateTime.now()),
              )
              .toList()
            ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

          if (groups.isEmpty) {
            return const Text(
              'Ainda não há grupos públicos. Crie o primeiro.',
              style: TextStyle(color: AppColors.textSecondary),
            );
          }

          return Column(
            children: [
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 196,
                    child: ActivityCard(
                      activity: group,
                      onJoin: () => context.push('/activity/${group.id}'),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
