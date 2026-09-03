import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/juntai_logo.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const JuntaiLogo(size: 44),
                const Spacer(),
                Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                        color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.mark_email_read_outlined,
                        size: 66, color: AppColors.primary)),
                const SizedBox(height: 24),
                const Text('Verifique seu e-mail',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text(
                    'Enviamos um link de confirmação para o seu e-mail. Depois de confirmar, volte para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, height: 1.45)),
                const Spacer(),
                AppButton(
                    label: 'Já verifiquei',
                    onPressed: () => context.go('/complete-profile')),
                TextButton(
                    onPressed: () =>
                        context.snack('Novo e-mail de verificação solicitado.'),
                    child: const Text('Reenviar e-mail'))
              ]))));
}
