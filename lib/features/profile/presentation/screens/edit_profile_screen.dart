import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final name = TextEditingController();
  final city = TextEditingController();
  final bio = TextEditingController();

  final selectedInterests = <String>{};

  final availableInterests = <String>[
    'Futebol',
    'Corrida',
    'Pedalar',
    'Games',
    'Cinema',
    'Café',
    'Música',
    'Trilha',
    'Academia',
    'Estudos',
    'Restaurante',
    'Praia',
    'Pet',
    'Jogos de mesa',
  ];

  bool loading = true;
  bool saving = false;
  bool uploadingPhoto = false;

  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) {
        throw Exception('Perfil não encontrado.');
      }

      final data = snapshot.data()!;

      name.text = (data['name'] ?? '').toString();
      city.text = (data['city'] ?? '').toString();
      bio.text = (data['bio'] ?? '').toString();
      photoUrl = data['photoUrl']?.toString();

      if (data['interests'] is List) {
        selectedInterests.addAll(
          (data['interests'] as List)
              .map((item) => item.toString()),
        );
      }
    } catch (error) {
      if (!mounted) return;
      context.snack('Não foi possível carregar o perfil: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _choosePhoto() async {
    if (saving || uploadingPhoto) return;

    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Foto do perfil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Escolher da galeria'),
                  onTap: () =>
                      Navigator.pop(sheetContext, 'gallery'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tirar uma foto'),
                  onTap: () =>
                      Navigator.pop(sheetContext, 'camera'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    setState(() => uploadingPhoto = true);

    try {
      final uploaded = source == 'camera'
          ? await ImageUploadService.instance.pickFromCamera(
              purpose: 'profile',
              maxWidth: 1000,
              maxHeight: 1000,
              imageQuality: 82,
            )
          : await ImageUploadService.instance.pickFromGallery(
              purpose: 'profile',
              maxWidth: 1000,
              maxHeight: 1000,
              imageQuality: 82,
            );

      if (uploaded == null) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        context.snack('Sua sessão expirou. Entre novamente.');
        return;
      }

      final separator = uploaded.url.contains('?') ? '&' : '?';
      final persistedUrl =
          '${uploaded.url}${separator}v=${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'photoUrl': persistedUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await user.updatePhotoURL(persistedUrl);

      if (!mounted) return;
      setState(() => photoUrl = persistedUrl);

      context.snack('Foto do perfil atualizada.');
    } on ApiException catch (error) {
      if (!mounted) return;
      context.snack(error.message);
    } catch (_) {
      if (!mounted) return;
      context.snack('Não foi possível enviar a foto.');
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
  }

  Future<void> save() async {
    if (saving || uploadingPhoto) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      context.go('/login');
      return;
    }

    final nameValue = name.text.trim();
    final cityValue = city.text.trim();
    final bioValue = bio.text.trim();

    if (nameValue.isEmpty) {
      context.snack('Informe seu nome.');
      return;
    }

    if (cityValue.isEmpty) {
      context.snack('Informe sua cidade.');
      return;
    }

    if (bioValue.length > 500) {
      context.snack('A bio deve ter no máximo 500 caracteres.');
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': nameValue,
        'city': cityValue,
        'bio': bioValue,
        'photoUrl': photoUrl ?? '',
        'interests': selectedInterests.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (user.displayName != nameValue) {
        await user.updateDisplayName(nameValue);
      }

      if (!mounted) return;
      context.snack('Perfil atualizado!');
      context.go('/profile');
    } on FirebaseException catch (error) {
      if (!mounted) return;
      context.snack(
        'Não foi possível salvar. ${error.message ?? error.code}',
      );
    } catch (error) {
      if (!mounted) return;
      context.snack('Erro ao salvar perfil: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SafeArea(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed:
                    saving ? null : () => context.go('/profile'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Text(
                'Editar perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Center(
            child: Stack(
              children: [
                AppAvatar(
                  name: name.text.isEmpty ? 'Usuário' : name.text,
                  photoUrl: photoUrl,
                  size: 120,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: uploadingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : IconButton(
                            onPressed: _choosePhoto,
                            icon: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppTextField(
            controller: name,
            label: 'Nome',
            prefixIcon: Icons.person_outline_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: city,
            label: 'Cidade',
            hint: 'Ex.: São Paulo, SP',
            prefixIcon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: bio,
            label: 'Bio',
            hint: 'Conte um pouco sobre você...',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          const Text(
            'Interesses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableInterests.map((interest) {
              final selected =
                  selectedInterests.contains(interest);

              return FilterChip(
                label: Text(interest),
                selected: selected,
                onSelected: saving
                    ? null
                    : (value) {
                        setState(() {
                          if (value) {
                            selectedInterests.add(interest);
                          } else {
                            selectedInterests.remove(interest);
                          }
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: saving ? 'Salvando...' : 'Salvar perfil',
            onPressed:
                saving || uploadingPhoto ? null : save,
          ),
        ],
      ),
    );
  }
}
