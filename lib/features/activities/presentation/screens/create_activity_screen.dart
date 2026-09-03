import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../widgets/activity_category_selector.dart';
import '../widgets/participant_counter.dart';
import '../widgets/privacy_selector.dart';

class CreateActivityScreen extends ConsumerStatefulWidget {
  const CreateActivityScreen({super.key, this.sourceDiscoveryId});
  final String? sourceDiscoveryId;

  @override
  ConsumerState<CreateActivityScreen> createState() =>
      _CreateActivityScreenState();
}

class _CreateActivityScreenState extends ConsumerState<CreateActivityScreen> {
  final Geocoding _geocoding = Geocoding();
  final title = TextEditingController();
  final location = TextEditingController();
  final description = TextEditingController();

  AddressSuggestion? selectedAddress;
  ActivityCategory category = ActivityCategory.football;
  DateTime date = DateTime.now();
  TimeOfDay time = const TimeOfDay(hour: 16, minute: 0);
  int participants = 8;
  bool isPrivate = false;
  bool loading = false;
  bool uploadingCover = false;
  String? coverUrl;
  String? sourceBusinessId;
  String? sourceBusinessName;
  bool sourceBusinessVerified = false;
  double? sourceLatitude;
  double? sourceLongitude;
  bool loadingSource = false;

  bool get fromDiscovery => widget.sourceDiscoveryId != null;

  @override
  void initState() {
    super.initState();
    if (fromDiscovery) _loadDiscovery();
  }

  Future<void> _loadDiscovery() async {
    setState(() => loadingSource = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('discoveries')
          .doc(widget.sourceDiscoveryId)
          .get();
      final data = doc.data();
      if (data == null) throw Exception();
      final discoveryTitle = (data['title'] ?? '').toString();
      final businessName = (data['businessName'] ?? 'local').toString();
      title.text = 'Quem anima ir em $discoveryTitle?';
      description.text = 'Vamos conhecer $businessName juntos?';
      location.text = (data['address'] ?? '').toString();
      coverUrl = data['coverUrl']?.toString();
      sourceBusinessId = data['businessId']?.toString();
      sourceBusinessName = businessName;
      sourceBusinessVerified = data['businessVerified'] == true;
      sourceLatitude = (data['latitude'] as num?)?.toDouble();
      sourceLongitude = (data['longitude'] as num?)?.toDouble();
      final eventStart = (data['eventStartsAt'] as Timestamp?)?.toDate();
      if (eventStart != null && eventStart.isAfter(DateTime.now())) {
        date = eventStart;
        time = TimeOfDay.fromDateTime(eventStart);
      }
    } finally {
      if (mounted) setState(() => loadingSource = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    location.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (result != null) {
      setState(() => date = result);
    }
  }

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: time,
    );

    if (result != null) {
      setState(() => time = result);
    }
  }

  Future<(double, double)> _resolveAddress(String address) async {
    final selected = selectedAddress;

    if (selected != null && selected.label == address) {
      return (selected.latitude, selected.longitude);
    }

    final locations = await _geocoding.locationFromAddress(address);

    if (locations.isEmpty) {
      throw Exception('Endereço não encontrado.');
    }

    return (
      locations.first.latitude,
      locations.first.longitude,
    );
  }

  Future<void> pickCover() async {
    if (loading || uploadingCover) return;

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

  Future<void> publish() async {
    if (loading) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.snack('Sua sessão expirou. Entre novamente.');
      context.go('/login');
      return;
    }

    final titleValue = title.text.trim();
    final locationValue = location.text.trim();
    final descriptionValue = description.text.trim();

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

    final startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!startsAt.isAfter(DateTime.now())) {
      context.snack('Escolha uma data e horário futuros.');
      return;
    }

    setState(() => loading = true);

    DocumentReference<Map<String, dynamic>>? activityReference;

    try {
      late final double latitude;
      late final double longitude;

      try {
        final coordinates = sourceLatitude != null && sourceLongitude != null
            ? (sourceLatitude!, sourceLongitude!)
            : await _resolveAddress(locationValue);
        latitude = coordinates.$1;
        longitude = coordinates.$2;
      } catch (_) {
        if (!mounted) return;

        context.snack(
          'Não conseguimos localizar esse endereço. '
          'Escolha uma das sugestões ou informe rua, número, cidade e estado.',
        );
        return;
      }

      final database = FirebaseFirestore.instance;
      final userSnapshot =
          await database.collection('users').doc(user.uid).get();
      final userData = userSnapshot.data();

      final creatorName =
          (userData?['name'] ?? user.displayName ?? 'Organizador')
              .toString()
              .trim();

      activityReference = database.collection('activities').doc();

      await activityReference.set({
        'creatorId': user.uid,
        'creatorName': creatorName,
        'title': titleValue,
        'description': descriptionValue,
        'category': category.name,
        'address': locationValue,
        'latitude': latitude,
        'longitude': longitude,
        'geohash': '',
        'startsAt': Timestamp.fromDate(startsAt),
        'maxParticipants': participants,
        'participantCount': 1,
        'participantNames': [creatorName],
        'isPrivate': isPrivate,
        'coverUrl': coverUrl,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (widget.sourceDiscoveryId != null)
          'sourceDiscoveryId': widget.sourceDiscoveryId,
        if (sourceBusinessId != null) 'sourceBusinessId': sourceBusinessId,
        if (sourceBusinessName != null)
          'sourceBusinessName': sourceBusinessName,
        if (sourceBusinessId != null)
          'sourceBusinessVerified': sourceBusinessVerified,
      });

      await activityReference.collection('participants').doc(user.uid).set({
        'userId': user.uid,
        'name': creatorName,
        'role': 'creator',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      if (widget.sourceDiscoveryId != null) {
        await database
            .collection('discoveries')
            .doc(widget.sourceDiscoveryId)
            .collection('activity_links')
            .doc(activityReference.id)
            .set({
          'activityId': activityReference.id,
          'creatorId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      context.snack('Atividade publicada!');
      context.go('/activity/${activityReference.id}');
    } on FirebaseException catch (error) {
      if (activityReference != null) {
        try {
          await activityReference.delete();
        } catch (_) {}
      }

      if (!mounted) return;
      context.snack(
        'Não foi possível publicar. ${error.message ?? error.code}',
      );
    } catch (error) {
      if (activityReference != null) {
        try {
          await activityReference.delete();
        } catch (_) {}
      }

      if (!mounted) return;
      context.snack('Erro ao publicar atividade: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: loading ? null : () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Criar atividade',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Preencha os detalhes para criar sua atividade.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (fromDiscovery) ...[
            Card(
                child: ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primary),
                    title: Text(loadingSource
                        ? 'Carregando descoberta...'
                        : 'Atividade inspirada por ${sourceBusinessName ?? 'um local'}'),
                    subtitle: const Text(
                        'Capa, lugar e descrição já foram preenchidos. Escolha quando e com quantas pessoas.'))),
            const SizedBox(height: 12),
          ],
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
            onChanged: loading || fromDiscovery
                ? (_) {}
                : (value) => setState(() => category = value),
          ),
          const SizedBox(height: 16),
          _Section(
            child: AppTextField(
              controller: title,
              label: 'Título da atividade',
              hint: 'Ex.: Futebol no Parque',
              prefixIcon: Icons.title_rounded,
              readOnly: false,
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: AddressAutocompleteField(
              controller: location,
              enabled: !loading && !fromDiscovery,
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
          ),
          const SizedBox(height: 7),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Ao digitar, escolha um endereço da lista para salvar a localização exata.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Section(
                  child: InkWell(
                    onTap: loading ? null : pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/'
                        '${date.year}',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Section(
                  child: InkWell(
                    onTap: loading ? null : pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Horário',
                        prefixIcon: Icon(Icons.access_time_rounded),
                      ),
                      child: Text(time.format(context)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Participantes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Mínimo de 2 participantes',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ParticipantCounter(
                  value: participants,
                  onChanged: loading
                      ? (_) {}
                      : (value) {
                          setState(() {
                            participants = value.clamp(2, 100).toInt();
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacidade',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quem pode ver e participar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                PrivacySelector(
                  isPrivate: isPrivate,
                  onChanged: loading
                      ? (_) {}
                      : (value) => setState(() => isPrivate = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: description,
                  label: 'Descrição (opcional)',
                  hint:
                      'Conte mais sobre a atividade, ponto de referência e o que levar...',
                  maxLines: 4,
                  readOnly: fromDiscovery,
                  onChanged: (_) => setState(() {}),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${description.text.length}/${AppConstants.maxDescription}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            onPressed:
                loading || uploadingCover || fromDiscovery ? null : pickCover,
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
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label:
                loading ? 'Localizando e publicando...' : 'Publicar atividade',
            onPressed: loading ? null : publish,
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
