import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/juntai_logo.dart';
import '../../../../core/widgets/people_illustration.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 22),
            child: Column(children: [
              const Spacer(flex: 1),
              const JuntaiMark(size: 92),
              const SizedBox(height: 12),
              const JuntaiLogo(size: 58),
              const SizedBox(height: 24),
              const Text('Encontre pessoas para',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 24, color: AppColors.textSecondary)),
              const Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'fazer algo ',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: 'hoje.',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                  ]),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25)),
              const SizedBox(height: 20),
              const Expanded(
                  flex: 5,
                  child: Center(child: PeopleIllustration(height: 280))),
              AppButton(
                  label: 'Começar', onPressed: () => context.go('/register')),
              const SizedBox(height: 10),
              TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Entrar',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      );
}
