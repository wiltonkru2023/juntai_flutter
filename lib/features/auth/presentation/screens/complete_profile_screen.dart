import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final bio = TextEditingController();

  final selected = <String>{};

  final interests = <String>[
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
  ];

  bool loading = false;

  @override
  void dispose() {
    bio.dispose();
    super.dispose();
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _message('Sua sessão expirou. Entre novamente.');

      if (mounted) {
        context.go('/login');
      }

      return;
    }

    final bioValue = bio.text.trim();

    if (bioValue.isEmpty) {
      _message('Conte um pouco sobre você.');
      return;
    }

    setState(() => loading = true);

    try {
      // Atualiza o perfil real do usuário no Firestore.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'bio': bioValue,
          'interests': selected.toList(),
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      context.go('/location-permission');
    } on FirebaseException catch (e) {
      if (!mounted) return;

      _message(
        'Não foi possível salvar seu perfil. '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;

      _message('Erro ao salvar perfil: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete seu perfil'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Stack(
                children: [
                  const CircleAvatar(
                    radius: 54,
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(
                      Icons.person_rounded,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () {
                        _message(
                          'Você pode adicionar sua foto depois em Editar perfil.',
                        );
                      },
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Conte um pouco sobre você',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: bio,
              hint: 'Ex: Gosto de futebol, café e conhecer gente nova.',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            const Text(
              'Seus interesses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Opcional — escolha apenas se quiser.',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in interests)
                  FilterChip(
                    label: Text(item),
                    selected: selected.contains(item),
                    onSelected: loading
                        ? null
                        : (value) {
                            setState(() {
                              if (value) {
                                selected.add(item);
                              } else {
                                selected.remove(item);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 32),
            AppButton(
              label: loading ? 'Salvando...' : 'Continuar',
              onPressed: loading ? null : saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
