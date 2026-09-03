import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/username_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/juntai_logo.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final username = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();
  final city = TextEditingController();

  DateTime? birth;

  bool terms = false;
  bool privacy = false;
  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    for (final controller in [
      name,
      email,
      username,
      pass,
      confirm,
      city,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> pickBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      setState(() => birth = date);
    }
  }

  Future<void> submit() async {
    final nameValue = name.text.trim();
    final emailValue = email.text.trim().toLowerCase();
    final usernameValue = UsernameService.normalize(username.text);
    final passwordValue = pass.text;
    final cityValue = city.text.trim();

    if (nameValue.isEmpty) {
      context.snack('Informe seu nome.');
      return;
    }

    if (emailValue.isEmpty) {
      context.snack('Informe seu e-mail.');
      return;
    }

    final usernameError = UsernameService.validate(usernameValue);
    if (usernameError != null) {
      context.snack(usernameError);
      return;
    }

    if (passwordValue.length < 6) {
      context.snack('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }

    if (passwordValue != confirm.text) {
      context.snack('As senhas não são iguais.');
      return;
    }

    if (birth == null) {
      context.snack('Informe sua data de nascimento.');
      return;
    }

    if (cityValue.isEmpty) {
      context.snack('Informe sua cidade.');
      return;
    }

    if (!terms || !privacy) {
      context.snack(
        'Você precisa aceitar os Termos de uso e a Política de privacidade.',
      );
      return;
    }

    setState(() => loading = true);

    UserCredential? credential;

    try {
      // 1. Cria a conta real no Firebase Authentication.
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailValue,
        password: passwordValue,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Não foi possível concluir a criação da conta.');
      }

      // 2. Salva o nome também no Firebase Authentication.
      await user.updateDisplayName(nameValue);

      final uid = user.uid;

      // 3. Cria o perfil inicial no Cloud Firestore.
      await UsernameService().createProfileWithUsername(
        uid: uid,
        username: usernameValue,
        profile: {
          'uid': uid,
          'name': nameValue,
          'email': emailValue,
          'city': cityValue,
          'birthDate': Timestamp.fromDate(birth!),

          // Perfil será completado na próxima tela.
          'bio': '',
          'interests': <String>[],
          'photoUrl': '',

          // Dados iniciais do perfil.
          'verified': false,
          'rating': 0.0,
          'activitiesCreated': 0,
          'activitiesJoined': 0,

          // Preferências iniciais.
          'showCity': true,
          'showActivities': true,
          'allowInvites': true,
          'allowMessages': true,
          'chatNotifications': true,
          'activityNotifications': true,

          // Controle.
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      if (!mounted) return;

      // 5. Segue para completar bio/interesses/foto.
      context.go('/complete-profile');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case 'email-already-in-use':
          context.snack('Já existe uma conta com este e-mail.');
          break;

        case 'invalid-email':
          context.snack('Informe um e-mail válido.');
          break;

        case 'weak-password':
          context.snack('A senha informada é muito fraca.');
          break;

        case 'operation-not-allowed':
          context.snack(
            'O cadastro por e-mail está temporariamente indisponível.',
          );
          break;

        case 'network-request-failed':
          context.snack(
            'Não foi possível conectar. Verifique sua internet e tente novamente.',
          );
          break;

        default:
          context.snack(
            'Não foi possível criar a conta. ${e.message ?? e.code}',
          );
      }
    } on UsernameException catch (e) {
      final suggestions = await UsernameService().suggestions(usernameValue);
      try {
        await credential?.user?.delete();
      } catch (_) {}
      if (!mounted) return;
      context.snack(suggestions.isEmpty
          ? e.message
          : '${e.message} Tente: ${suggestions.map((v) => '@$v').join(', ')}');
    } on FirebaseException catch (e) {
      // Se o Auth criou a conta mas o Firestore falhou,
      // removemos a conta recém-criada para não deixar
      // um cadastro incompleto.
      try {
        await credential?.user?.delete();
      } catch (_) {}

      if (!mounted) return;

      context.snack(
        'Erro ao salvar seu perfil no banco de dados. '
        '${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;

      context.snack(
        'Ocorreu um erro ao criar sua conta: $e',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: loading ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
          children: [
            const Center(
              child: JuntaiLogo(size: 46),
            ),
            const SizedBox(height: 14),
            const Text(
              'Criar sua conta',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Leva menos de um minuto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: name,
              hint: 'Nome completo',
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: email,
              hint: 'E-mail',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: username,
              hint: '@usuário único',
              prefixIcon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: pass,
              hint: 'Senha',
              obscureText: obscure,
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffixTap: () {
                setState(() => obscure = !obscure);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: confirm,
              hint: 'Confirmar senha',
              obscureText: true,
              prefixIcon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: loading ? null : pickBirth,
              borderRadius: BorderRadius.circular(20),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.cake_outlined),
                  hintText: 'Data de nascimento',
                ),
                child: Text(
                  birth == null
                      ? 'Data de nascimento'
                      : '${birth!.day.toString().padLeft(2, '0')}/'
                          '${birth!.month.toString().padLeft(2, '0')}/'
                          '${birth!.year}',
                  style: TextStyle(
                    color: birth == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: city,
              hint: 'Cidade',
              prefixIcon: Icons.location_city_outlined,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: terms,
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() {
                        terms = value ?? false;
                      });
                    },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aceito os Termos de uso',
              ),
            ),
            CheckboxListTile(
              value: privacy,
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() {
                        privacy = value ?? false;
                      });
                    },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aceito a Política de privacidade',
              ),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: loading ? 'Criando conta...' : 'Criar conta',
              onPressed: loading ? null : submit,
            ),
            TextButton(
              onPressed: loading ? null : () => context.go('/login'),
              child: const Text(
                'Já tenho uma conta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
