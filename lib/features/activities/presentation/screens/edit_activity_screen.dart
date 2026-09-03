import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/address_search_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/widgets/address_autocomplete_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../shared/enums/activity_category.dart';
import '../../../../shared/models/activity.dart';
import '../widgets/activity_category_selector.dart';
import '../widgets/participant_counter.dart';
import '../widgets/privacy_selector.dart';

class EditActivityScreen extends StatefulWidget {
  const EditActivityScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  final Geocoding _geocoding = Geocoding();
  final title = TextEditingController();
  final location = TextEditingController();
  final description = TextEditingController();

  AddressSuggestion? selectedAddress;
  ActivityCategory category = ActivityCategory.football;
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  int maxParticipants = 2;
  bool isPrivate = false;
  bool seeded = false;
  bool saving = false;
  bool uploadingCover = false;
  String? coverUrl;

  String originalAddress = '';
  double originalLatitude = 0;
  double originalLongitude = 0;
  String originalGeohash = '';

  DocumentReference<Map<String, dynamic>> get _ref => FirebaseFirestore.instance
      .collection('activities')
      .doc(widget.activityId);

  @override
  void dispose() {
    title.dispose();
    location.dispose();
    description.dispose();
    super.dispose();
  }

  void _seed(Activity activity) {
    if (seeded) return;

    title.text = activity.title;
    location.text = activity.address;
    description.text = activity.description;
    category = activity.category;
    date = DateTime(
      activity.startsAt.year,
      activity.startsAt.month,
      activity.startsAt.day,
    );
    time = TimeOfDay.fromDateTime(activity.startsAt);
    maxParticipants = activity.maxParticipants;
    isPrivate = activity.isPrivate;
    originalAddress = activity.address;
    originalLatitude = activity.latitude;
    originalLongitude = activity.longitude;
    originalGeohash = activity.geohash;
    coverUrl = activity.coverUrl;
    seeded = true;
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date.isBefore(DateTime.now()) ? DateTime.now() : date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (result != null) {
      setState(() => date = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: time,
    );

    if (result != null) {
      setState(() => time = result);
    }
  }

  Future<(double, double, String)> _resolveAddress(
    String address,
  ) async {
    if (address == originalAddress && selectedAddress == null) {
      return (
        originalLatitude,
        originalLongitude,
        originalGeohash,
      );
    }

    final selected = selectedAddress;

    if (selected != null && selected.label == address) {
      return (
        selected.latitude,
        selected.longitude,
        '',
      );
    }

    final matches = await _geocoding.locationFromAddress(address);

    if (matches.isEmpty) {
      throw Exception('Endereço não encontrado.');
    }

    return (
      matches.first.latitude,
      matches.first.longitude,
      '',
    );
  }

  Future<void> _pickCover() async {
    if (saving || uploadingCover) return;

    setState(() => uploadingCover = true);

    try {
      final uploaded = await ImageUploadService.instance.pickFromGallery(
        purpose: 'activity',
        maxWidth: 1800,
        maxHeight: 1400,
        imageQuality: 82,
      );

      if (uploaded == null) return;

      if (!mounted) return;
      setState(() => coverUrl = uploaded.url);
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a capa.');
    } finally {
      if (mounted) setState(() => uploadingCover = false);
    }
  }

  Future<void> _save(Activity activity) async {
    if (saving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    if (user.uid != activity.creatorId) {
      context.snack('Somente o organizador pode editar esta atividade.');
      return;
    }

    final titleValue = title.text.trim();
    final locationValue = location.text.trim();
    final descriptionValue = description.text.trim();
    final startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (titleValue.isEmpty) {
      context.snack('Informe o título da atividade.');
      return;
    }

    if (locationValue.isEmpty) {
      context.snack('Informe o local da atividade.');
      return;
    }

    if (descriptionValue.length > AppConstants.maxDescription) {
      context.snack(
        'A descrição deve ter no máximo '
        '${AppConstants.maxDescription} caracteres.',
      );
      return;
    }

    if (!startsAt.isAfter(DateTime.now())) {
      context.snack('Escolha uma data e horário futuros.');
      return;
    }

    if (maxParticipants < activity.participantCount) {
      context.snack(
        'O limite não pode ser menor que os '
        '${activity.participantCount} participantes atuais.',
      );
      return;
    }

    setState(() => saving = true);

    try {
      final coordinates = await _resolveAddress(locationValue);

      await ApiService.instance.updateActivity(
        activityId: activity.id,
        title: titleValue,
        description: descriptionValue,
        category: category.name,
        address: locationValue,
        latitude: coordinates.$1,
        longitude: coordinates.$2,
        geohash: coordinates.$3,
        startsAt: startsAt,
        maxParticipants: maxParticipants,
        isPrivate: isPrivate,
      );

      if (coverUrl != activity.coverUrl) {
        await _ref.update({
          'coverUrl': coverUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      context.snack('Atividade atualizada.');
      context.go('/activity/${activity.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } catch (error) {
      if (!mounted) return;
      context.snack('Não foi possível salvar a atividade: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _cancel(Activity activity) async {
    if (activity.status == 'cancelled') return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar atividade?'),
        content: const Text(
          'Os participantes serão avisados e a atividade ficará '
          'indisponível para novas participações.',
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

    setState(() => saving = true);

    try {
      await ApiService.instance.cancelActivity(activity.id);

      if (!mounted) return;
      context.snack('Atividade cancelada.');
      context.go('/activity/${activity.id}');
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Não foi possível carregar a atividade.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final document = snapshot.data;

        if (document == null || !document.exists) {
          return const Scaffold(
            body: Center(child: Text('Atividade não encontrada.')),
          );
        }

        final activity = Activity.fromFirestore(document);
        _seed(activity);

        if (uid == null || uid != activity.creatorId) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Somente o organizador pode editar esta atividade.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed:
                  saving ? null : () => context.go('/activity/${activity.id}'),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'Editar atividade',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const Text(
                  'Categoria',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ActivityCategorySelector(
                  value: category,
                  onChanged: saving
                      ? (_) {}
                      : (value) => setState(() => category = value),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: title,
                  label: 'Título',
                  prefixIcon: Icons.title_rounded,
                ),
                const SizedBox(height: 12),
                AddressAutocompleteField(
                  controller: location,
                  enabled: !saving,
                  label: 'Local',
                  hint: 'Digite rua e número para ver sugestões',
                  onSelected: (value) {
                    selectedAddress = value;
                  },
                  onChanged: (value) {
                    if (selectedAddress?.label != value) {
                      selectedAddress = null;
                    }
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: description,
                  label: 'Descrição',
                  maxLines: 5,
                ),
                const SizedBox(height: 18),
                if (coverUrl != null && coverUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      coverUrl!,
                      width: double.infinity,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 190,
                        color: AppColors.primaryLight,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 54,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: saving || uploadingCover ? null : _pickCover,
                  icon: uploadingCover
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                        ),
                  label: Text(
                    uploadingCover
                        ? 'Enviando capa...'
                        : coverUrl == null
                            ? 'Adicionar capa'
                            : 'Trocar capa',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${date.day.toString().padLeft(2, '0')}/'
                          '${date.month.toString().padLeft(2, '0')}/'
                          '${date.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _pickTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(
                          '${time.hour.toString().padLeft(2, '0')}:'
                          '${time.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Limite de participantes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                ParticipantCounter(
                  value: maxParticipants,
                  onChanged: (value) {
                    if (!saving && value >= activity.participantCount) {
                      setState(() => maxParticipants = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Participação',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                PrivacySelector(
                  isPrivate: isPrivate,
                  onChanged: saving
                      ? (_) {}
                      : (value) => setState(() => isPrivate = value),
                ),
                const SizedBox(height: 26),
                if (activity.status == 'cancelled')
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Esta atividade já foi cancelada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else ...[
                  AppButton(
                    label: saving ? 'Salvando...' : 'Salvar alterações',
                    onPressed: saving ? null : () => _save(activity),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Cancelar atividade',
                    danger: true,
                    onPressed: saving ? null : () => _cancel(activity),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
