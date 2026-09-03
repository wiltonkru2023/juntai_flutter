import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';

class CreateDiscoveryScreen extends StatefulWidget {
  const CreateDiscoveryScreen({super.key, this.postId});
  final String? postId;

  @override
  State<CreateDiscoveryScreen> createState() => _CreateDiscoveryScreenState();
}

class _CreateDiscoveryScreenState extends State<CreateDiscoveryScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final cta = TextEditingController(text: 'Criar atividade aqui');
  final price = TextEditingController();
  final juntaiPrice = TextEditingController();
  final minParticipants = TextEditingController(text: '2');
  final maxParticipants = TextEditingController(text: '10');
  final benefitValue = TextEditingController();
  final benefitMin = TextEditingController();
  final benefitLabel = TextEditingController();
  final slots = TextEditingController();

  String type = 'experience';
  String benefitType = 'none';
  bool officialEvent = false;
  bool publishing = false;
  bool loading = false;
  String? coverUrl;
  final galleryUrls = <String>[];
  DateTime? startsAt;
  DateTime? endsAt;
  TimeOfDay startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 21, minute: 0);

  bool get editing => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (editing) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('discoveries')
          .doc(widget.postId)
          .get();
      final d = doc.data();
      if (d == null) throw Exception();

      type = (d['type'] ?? 'experience').toString();
      title.text = (d['title'] ?? '').toString();
      description.text = (d['description'] ?? '').toString();
      cta.text = (d['ctaLabel'] ?? 'Criar atividade aqui').toString();
      coverUrl = d['coverUrl']?.toString();
      price.text = d['price']?.toString() ?? '';
      juntaiPrice.text = d['juntaiPrice']?.toString() ?? '';
      minParticipants.text = '${d['minParticipants'] ?? 2}';
      maxParticipants.text = '${d['maxParticipants'] ?? 10}';
      benefitType = (d['benefitType'] ?? 'none').toString();
      benefitValue.text = d['benefitValue']?.toString() ?? '';
      benefitMin.text = d['benefitMinParticipants']?.toString() ?? '';
      benefitLabel.text = (d['groupBenefit'] ?? '').toString();
      officialEvent = d['officialEvent'] == true;

      if (d['galleryUrls'] is List) {
        galleryUrls
          ..clear()
          ..addAll((d['galleryUrls'] as List).map((e) => e.toString()));
      }

      if (d['eventStartsAt'] is Timestamp) {
        startsAt = (d['eventStartsAt'] as Timestamp).toDate();
        startTime = TimeOfDay.fromDateTime(startsAt!);
      }
      if (d['eventEndsAt'] is Timestamp) {
        endsAt = (d['eventEndsAt'] as Timestamp).toDate();
        endTime = TimeOfDay.fromDateTime(endsAt!);
      }
      if (d['availabilitySlots'] is List) {
        slots.text = (d['availabilitySlots'] as List)
            .whereType<Map>()
            .map((item) => (item['label'] ?? '').toString())
            .where((item) => item.isNotEmpty)
            .join(', ');
      }
    } catch (_) {
      if (mounted) context.snack('Não foi possível carregar a publicação.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String?> _pickImage() async {
    try {
      final image = await ImageUploadService.instance.pickFromGallery(
        purpose: 'discovery',
        maxWidth: 1800,
        maxHeight: 1400,
        imageQuality: 82,
      );
      return image?.url;
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
      return null;
    }
  }

  double? _money(TextEditingController c) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final normalized =
        raw.contains(',') ? raw.replaceAll('.', '').replaceAll(',', '.') : raw;
    return double.tryParse(normalized);
  }

  Future<DateTime?> _pickDateTime(DateTime? current, TimeOfDay time) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return null;

    final chosen = await showTimePicker(context: context, initialTime: time);
    if (chosen == null) return null;

    return DateTime(
        date.year, date.month, date.day, chosen.hour, chosen.minute);
  }

  Future<void> _publish() async {
    if (title.text.trim().isEmpty ||
        description.text.trim().isEmpty ||
        (coverUrl ?? '').isEmpty) {
      context.snack('Adicione título, descrição e foto de capa.');
      return;
    }

    if ((type == 'event' || type == 'open_slots' || type == 'schedule') &&
        startsAt == null) {
      context.snack('Defina a data e horário.');
      return;
    }

    final max = int.tryParse(maxParticipants.text) ?? 0;
    final min = int.tryParse(minParticipants.text) ?? 0;
    if ((type == 'open_slots' || type == 'schedule') &&
        (max < 2 || min < 1 || min > max)) {
      context.snack('Confira mínimo e máximo de participantes.');
      return;
    }
    if (type == 'schedule' && slots.text.trim().isEmpty) {
      context.snack('Informe os horários disponíveis.');
      return;
    }

    setState(() => publishing = true);
    try {
      final availability = slots.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((label) => {
                'label': label,
                'capacity': max > 0 ? max : 10,
                'claimed': 0,
              })
          .toList();

      final payload = <String, dynamic>{
        'type': type,
        'title': title.text.trim(),
        'description': description.text.trim(),
        'coverUrl': coverUrl,
        'galleryUrls': galleryUrls,
        'ctaLabel': cta.text.trim().isEmpty
            ? (type == 'open_slots' ? 'Eu vou' : 'Criar atividade aqui')
            : cta.text.trim(),
        'officialEvent': officialEvent || type == 'event',
        'eventStartsAt': startsAt?.toUtc().toIso8601String(),
        'eventEndsAt': endsAt?.toUtc().toIso8601String(),
        'price': _money(price),
        'juntaiPrice': _money(juntaiPrice),
        'minParticipants': min,
        'maxParticipants': max,
        'benefitType': benefitType == 'none' ? null : benefitType,
        'benefitValue': _money(benefitValue),
        'benefitMinParticipants': int.tryParse(benefitMin.text) ?? 0,
        'groupBenefit': benefitLabel.text.trim(),
        'availabilitySlots': availability,
      };

      if (editing) {
        await ApiService.instance.updateBusinessPost(widget.postId!, payload);
      } else {
        await ApiService.instance.createBusinessPost(payload);
      }

      if (!mounted) return;
      context.snack(editing ? 'Publicação atualizada!' : 'Publicação criada!');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      title,
      description,
      cta,
      price,
      juntaiPrice,
      minParticipants,
      maxParticipants,
      benefitValue,
      benefitMin,
      benefitLabel,
      slots,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(editing ? 'Editar publicação' : 'Nova publicação')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'experience', child: Text('Experiência')),
                      DropdownMenuItem(value: 'event', child: Text('Evento')),
                      DropdownMenuItem(
                          value: 'open_slots', child: Text('Vagas abertas')),
                      DropdownMenuItem(
                          value: 'promotion',
                          child: Text('Promoção para grupo')),
                      DropdownMenuItem(
                          value: 'schedule', child: Text('Horário disponível')),
                    ],
                    onChanged:
                        editing ? null : (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  field(title, 'Título'),
                  field(description, 'Descrição', maxLines: 4),
                  if (type == 'event' ||
                      type == 'open_slots' ||
                      type == 'schedule') ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_rounded),
                      title: Text(
                        startsAt == null
                            ? 'Definir início'
                            : '${startsAt!.day}/${startsAt!.month}/${startsAt!.year} '
                                '${startTime.format(context)}',
                      ),
                      onTap: () async {
                        final value = await _pickDateTime(startsAt, startTime);
                        if (value != null && mounted) {
                          setState(() {
                            startsAt = value;
                            startTime = TimeOfDay.fromDateTime(value);
                          });
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_busy_rounded),
                      title: Text(
                        endsAt == null
                            ? 'Definir fim (opcional)'
                            : '${endsAt!.day}/${endsAt!.month}/${endsAt!.year} '
                                '${endTime.format(context)}',
                      ),
                      onTap: () async {
                        final value = await _pickDateTime(endsAt, endTime);
                        if (value != null && mounted) {
                          setState(() {
                            endsAt = value;
                            endTime = TimeOfDay.fromDateTime(value);
                          });
                        }
                      },
                    ),
                  ],
                  if (type == 'open_slots' || type == 'schedule')
                    Row(
                      children: [
                        Expanded(
                          child: field(
                            minParticipants,
                            'Mínimo',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: field(
                            maxParticipants,
                            'Máximo',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  if (type == 'schedule')
                    field(slots, 'Horários separados por vírgula', maxLines: 2),
                  Row(
                    children: [
                      Expanded(
                        child: field(
                          price,
                          'Preço normal',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: field(
                          juntaiPrice,
                          'Preço Juntaí',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: benefitType,
                    decoration: const InputDecoration(
                        labelText: 'Benefício para grupo'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Nenhum')),
                      DropdownMenuItem(
                          value: 'percentage_discount',
                          child: Text('Desconto percentual')),
                      DropdownMenuItem(
                          value: 'fixed_discount',
                          child: Text('Desconto em R\$')),
                      DropdownMenuItem(
                          value: 'free_item', child: Text('Item grátis')),
                      DropdownMenuItem(
                          value: 'group_reward',
                          child: Text('Recompensa do grupo')),
                      DropdownMenuItem(
                          value: 'special_price',
                          child: Text('Preço especial')),
                      DropdownMenuItem(
                          value: 'priority_entry',
                          child: Text('Entrada prioritária')),
                    ],
                    onChanged: (v) => setState(() => benefitType = v!),
                  ),
                  if (benefitType != 'none') ...[
                    const SizedBox(height: 12),
                    field(
                      benefitValue,
                      'Valor do benefício (quando aplicável)',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    field(
                      benefitMin,
                      'Desbloquear com quantas pessoas?',
                      keyboardType: TextInputType.number,
                    ),
                    field(benefitLabel, 'Descrição do benefício', maxLines: 2),
                  ],
                  field(cta, 'Texto do botão'),
                  if ((coverUrl ?? '').isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.network(
                        coverUrl!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final url = await _pickImage();
                      if (url != null && mounted)
                        setState(() => coverUrl = url);
                    },
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text(
                        coverUrl == null ? 'Adicionar capa' : 'Trocar capa'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Galeria da publicação',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in galleryUrls)
                        Stack(
                          children: [
                            Image.network(url,
                                width: 80, height: 80, fit: BoxFit.cover),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                onPressed: () =>
                                    setState(() => galleryUrls.remove(url)),
                                icon: const Icon(Icons.cancel,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      if (galleryUrls.length < 6)
                        IconButton.filledTonal(
                          onPressed: () async {
                            final url = await _pickImage();
                            if (url != null && mounted)
                              setState(() => galleryUrls.add(url));
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: publishing ? null : _publish,
                    child: Text(
                      publishing
                          ? 'Salvando...'
                          : editing
                              ? 'Salvar alterações'
                              : 'Publicar',
                    ),
                  ),
                ],
              ),
      );
}
