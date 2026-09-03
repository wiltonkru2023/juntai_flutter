import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/interest_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/username_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_outline_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/juntai_logo.dart';
import '../../../../core/widgets/people_illustration.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool obscure = true;
  bool loading = false;
  String loadingLabel = 'Entrando...';

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final emailValue = email.text.trim().toLowerCase();
    final passwordValue = password.text;

    if (emailValue.isEmpty || passwordValue.isEmpty) {
      _message('Informe seu e-mail e senha.');
      return;
    }

    _setLoading(true, 'Entrando...');

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailValue,
        password: passwordValue,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Usuário não encontrado após o login.');
      }

      await _finishLogin(user);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'invalid-email':
          _message('E-mail inválido.');
          break;
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          _message('E-mail ou senha incorretos.');
          break;
        case 'user-disabled':
          _message('Esta conta foi desativada.');
          break;
        case 'too-many-requests':
          _message('Muitas tentativas. Tente novamente mais tarde.');
          break;
        case 'network-request-failed':
          _message('Sem conexão. Verifique sua internet.');
          break;
        default:
          _message('Não foi possível entrar. Tente novamente.');
      }
    } catch (error) {
      if (!mounted) return;
      _message('Não foi possível entrar: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loginWithGoogle() async {
    if (loading) return;

    _setLoading(true, 'Conectando ao Google...');

    try {
      final googleCredential = await GoogleAuthService.instance.getCredential();
      UserCredential credential;
      try {
        credential =
            await FirebaseAuth.instance.signInWithCredential(googleCredential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'account-exists-with-different-credential' ||
            (error.email ?? '').isEmpty) {
          rethrow;
        }
        credential = await _linkExistingAccount(error.email!, googleCredential);
      }
      final user = credential.user;

      if (user == null) {
        throw const GoogleAuthServiceException(
          'Não foi possível obter sua conta do Google.',
        );
      }

      await _finishLogin(user);
    } on GoogleSignInException catch (error) {
      if (!mounted) return;

      if (error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }

      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        _message(
          'O login com Google ainda precisa ser habilitado para este aplicativo no Firebase.',
        );
        return;
      }

      _message('Não foi possível entrar com Google. Tente novamente.');
    } on GoogleAuthServiceException catch (error) {
      if (!mounted) return;
      _message(error.message);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      if (error.code == 'account-exists-with-different-credential') {
        _message(
          'Entre com a senha da conta existente para vincular o Google.',
        );
      } else {
        _message(
          error.message ?? 'Não foi possível autenticar com Google.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _message('Não foi possível entrar com Google. Tente novamente.');
    } finally {
      _setLoading(false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<void> loginWithApple() async {
    if (loading) return;

    _setLoading(true, 'Conectando Ã  Apple...');

    try {
      final rawNonce = _generateNonce();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );

      final identityToken = apple.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        throw const GoogleAuthServiceException(
          'A Apple nÃ£o retornou um token de identidade.',
        );
      }

      final appleCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      );

      UserCredential result;

      try {
        result =
            await FirebaseAuth.instance.signInWithCredential(appleCredential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'account-exists-with-different-credential' ||
            (error.email ?? '').isEmpty) {
          rethrow;
        }

        result = await _linkExistingAccount(
          error.email!,
          appleCredential,
        );
      }

      final user = result.user;

      if (user == null) {
        throw const GoogleAuthServiceException(
          'NÃ£o foi possÃ­vel concluir o login com Apple.',
        );
      }

      final fullName = [
        apple.givenName,
        apple.familyName,
      ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' ');

      if ((user.displayName ?? '').trim().isEmpty && fullName.isNotEmpty) {
        await user.updateDisplayName(fullName);
      }

      await _finishLogin(user);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (!mounted) return;

      if (error.code == AuthorizationErrorCode.canceled) {
        return;
      }

      _message(
        'NÃ£o foi possÃ­vel entrar com Apple. '
        'Confira a configuraÃ§Ã£o do provedor.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      _message(
        error.message ?? 'NÃ£o foi possÃ­vel entrar com Apple.',
      );
    } on GoogleAuthServiceException catch (error) {
      if (!mounted) return;
      _message(error.message);
    } catch (_) {
      if (!mounted) return;
      _message('NÃ£o foi possÃ­vel entrar com Apple.');
    } finally {
      _setLoading(false);
    }
  }

  Future<UserCredential> _linkExistingAccount(
    String accountEmail,
    AuthCredential googleCredential,
  ) async {
    final passwordController = TextEditingController();
    final passwordValue = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vincular conta existente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Já existe um perfil para $accountEmail. Informe a senha para usar o mesmo perfil com Google.'),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, passwordController.text),
              child: const Text('Vincular')),
        ],
      ),
    );
    passwordController.dispose();
    if (passwordValue == null || passwordValue.isEmpty) {
      throw const GoogleAuthServiceException('Vínculo cancelado.');
    }
    final existing = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: accountEmail,
      password: passwordValue,
    );
    await existing.user!.linkWithCredential(googleCredential);
    return existing;
  }

  Future<void> _finishLogin(User user) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final profileSnapshot = await userRef.get();

    if (!profileSnapshot.exists) {
      final username =
          await _availableUsername(user.displayName ?? user.email ?? 'usuario');
      await UsernameService().createProfileWithUsername(
          uid: user.uid,
          username: username,
          profile: {
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'city': '',
            'bio': '',
            'interests': <String>[],
            'profileCompleted': false,
            'verified': user.emailVerified,
            'showCity': true,
            'showActivities': true,
            'allowInvites': true,
            'allowMessages': true,
            'chatNotifications': true,
            'activityNotifications': true,
            'accountStatus': 'active',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } else {
      final data = profileSnapshot.data()!;

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final name = (data['name'] ?? '').toString().trim();
      final emailValue = (data['email'] ?? '').toString().trim();
      final photo = (data['photoUrl'] ?? '').toString().trim();

      // Normaliza campos antigos que chegaram como null, string ou lista inválida.
      if (data['interests'] is! List) updates['interests'] = <String>[];
      if (data['bio'] is! String) updates['bio'] = '';
      if (data['photoUrl'] is! String) updates['photoUrl'] = '';
      if (data['activitiesCreated'] is! num) updates['activitiesCreated'] = 0;
      if (data['activitiesJoined'] is! num) updates['activitiesJoined'] = 0;

      if (name.isEmpty && (user.displayName ?? '').trim().isNotEmpty) {
        updates['name'] = user.displayName;
      }

      if (emailValue.isEmpty && (user.email ?? '').trim().isNotEmpty) {
        updates['email'] = user.email;
      }

      if (photo.isEmpty && (user.photoURL ?? '').trim().isNotEmpty) {
        updates['photoUrl'] = user.photoURL;
      }

      if ((data['username'] ?? '').toString().trim().isEmpty) {
        final generated = await _availableUsername(
            name.isEmpty ? (user.displayName ?? 'usuario') : name);
        await ApiService.instance.reserveUsername(generated);
        await userRef.set({
          ...updates,
          'username': generated,
          'usernameLower': generated,
        }, SetOptions(merge: true));
      } else {
        await userRef.set(updates, SetOptions(merge: true));
      }
    }

    await InterestService.normalizeUser(user.uid);

    try {
      await ApiService.instance.syncSocialCounters();
    } catch (_) {
      // A sincronizaÃ§Ã£o Ã© corretiva e nÃ£o deve impedir o login.
    }

    await NotificationService.instance.syncTokenForCurrentUser();

    final refreshed = await userRef.get();
    final data = refreshed.data() ?? const <String, dynamic>{};
    final profileCompleted = data['profileCompleted'] == true;

    if (!mounted) return;

    if (profileCompleted) {
      context.go('/home');
    } else {
      context.go('/complete-profile');
    }
  }

  Future<String> _availableUsername(String source) async {
    var base = UsernameService.normalize(source);
    if (base.length < 3) base = 'usuario';
    if (!RegExp(r'^[a-z]').hasMatch(base)) base = 'u$base';
    if (base.length > 15) base = base.substring(0, 15);
    final service = UsernameService();
    if (await service.isAvailable(base)) return base;
    for (var i = 1; i < 1000; i++) {
      final candidate = '$base$i';
      if (candidate.length <= 20 && await service.isAvailable(candidate)) {
        return candidate;
      }
    }
    return 'usuario${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  void _setLoading(
    bool value, [
    String label = 'Entrando...',
  ]) {
    if (!mounted) return;
    setState(() {
      loading = value;
      loadingLabel = label;
    });
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            children: [
              const JuntaiLogo(size: 82),
              const SizedBox(height: 12),
              const Text(
                'Entre para encontrar pessoas e\natividades perto de você.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              const PeopleIllustration(height: 230),
              const SizedBox(height: 10),
              AppTextField(
                controller: email,
                hint: 'E-mail',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: password,
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      loading ? null : () => context.push('/forgot-password'),
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              AppButton(
                label: loading ? loadingLabel : 'Entrar',
                onPressed: loading ? null : login,
              ),
              const SizedBox(height: 12),
              AppOutlineButton(
                label: 'Criar conta',
                onPressed: loading ? null : () => context.go('/register'),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Expanded(
                    child: Divider(color: AppColors.border),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'ou continue com',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: AppColors.border),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: loading && loadingLabel.contains('Google')
                    ? 'Conectando ao Google...'
                    : 'Continuar com Google',
                onTap: loading ? null : loginWithGoogle,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                icon: Icons.apple_rounded,
                label: 'Continuar com Apple',
                onTap: loading
                    ? null
                    : () {
                        _message(
                          'Entrar com Apple ainda não está disponível.',
                        );
                      },
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'Ao continuar, você concorda com os ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/terms'),
                    child: const Text(
                      'Termos de uso',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Text(
                    ' e a ',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/privacy-policy'),
                    child: const Text(
                      'Política de privacidade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Text(
                    '.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 30),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: AppColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
