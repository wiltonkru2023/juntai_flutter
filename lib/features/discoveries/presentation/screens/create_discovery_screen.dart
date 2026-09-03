import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class CreateDiscoveryScreen extends StatefulWidget {
  const CreateDiscoveryScreen({super.key});
  @override
  State<CreateDiscoveryScreen> createState() => _CreateDiscoveryScreenState();
}

class _CreateDiscoveryScreenState extends State<CreateDiscoveryScreen> {
  final title = TextEditingController(),
      description = TextEditingController(),
      benefit = TextEditingController(),
      cta = TextEditingController(text: 'Criar atividade aqui');
  bool officialEvent = false, publishing = false;
  String? coverUrl;
  DateTime? eventDate;
  TimeOfDay eventTime = const TimeOfDay(hour: 19, minute: 0);
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    benefit.dispose();
    cta.dispose();
    super.dispose();
  }

  Future<void> _cover() async {
    try {
      final image = await ImageUploadService.instance.pickFromGallery(
          purpose: 'discovery',
          maxWidth: 1800,
          maxHeight: 1400,
          imageQuality: 82);
      if (image != null && mounted) setState(() => coverUrl = image.url);
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    }
  }

  Future<void> _publish() async {
    if (title.text.trim().isEmpty ||
        description.text.trim().isEmpty ||
        coverUrl == null) {
      context.snack('Adicione título, descrição e uma foto.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    setState(() => publishing = true);
    try {
      final business =
          (await db.collection('business_profiles').doc(uid).get()).data();
      if (business == null) throw Exception();
      DateTime? starts;
      if (eventDate != null)
        starts = DateTime(eventDate!.year, eventDate!.month, eventDate!.day,
            eventTime.hour, eventTime.minute);
      await ApiService.instance.createBusinessPost({
        'type': officialEvent ? 'event' : 'experience',
        'title': title.text.trim(),
        'description': description.text.trim(),
        'coverUrl': coverUrl,
        'groupBenefit': benefit.text.trim(),
        'ctaLabel':
            cta.text.trim().isEmpty ? 'Criar atividade aqui' : cta.text.trim(),
        'officialEvent': officialEvent,
        'eventStartsAt': starts?.toUtc().toIso8601String()
      });
      if (mounted) {
        context.snack('Publicação criada!');
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) context.snack(error.message);
    } catch (_) {
      if (mounted) context.snack('Não foi possível publicar.');
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nova descoberta')),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        AppTextField(
            controller: title, label: 'Título', hint: 'Novo café especial'),
        const SizedBox(height: 12),
        AppTextField(
            controller: description,
            label: 'Descrição',
            hint: 'Conte o que há de interessante',
            maxLines: 4),
        const SizedBox(height: 12),
        AppTextField(
            controller: benefit,
            label: 'Benefício para grupos (opcional)',
            hint: 'Grupos com 4+ ganham...'),
        const SizedBox(height: 12),
        AppTextField(
            controller: cta,
            label: 'Texto do botão',
            hint: 'Criar atividade aqui'),
        const SizedBox(height: 12),
        SwitchListTile(
            value: officialEvent,
            onChanged: (v) => setState(() => officialEvent = v),
            title: const Text('Evento oficial'),
            subtitle:
                const Text('Permite vários grupos ligados ao mesmo evento')),
        if (officialEvent)
          ListTile(
              leading: const Icon(Icons.event_rounded),
              title: Text(eventDate == null
                  ? 'Escolher data do evento'
                  : '${eventDate!.day}/${eventDate!.month}/${eventDate!.year} • ${eventTime.format(context)}'),
              onTap: () async {
                final date = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: eventDate ?? DateTime.now());
                if (date == null || !mounted) return;
                final time = await showTimePicker(
                    context: context, initialTime: eventTime);
                if (mounted)
                  setState(() {
                    eventDate = date;
                    if (time != null) eventTime = time;
                  });
              }),
        if (coverUrl != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(coverUrl!,
                      height: 180, fit: BoxFit.cover))),
        OutlinedButton.icon(
            onPressed: _cover,
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: Text(coverUrl == null ? 'Adicionar foto' : 'Trocar foto')),
        const SizedBox(height: 20),
        AppButton(
            label: publishing ? 'Publicando...' : 'Publicar',
            onPressed: publishing ? null : _publish),
      ]));
}
