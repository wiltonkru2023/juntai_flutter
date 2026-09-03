import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/juntai_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Mantém a animação visível por um pequeno período.
    await Future.delayed(
      const Duration(milliseconds: 1500),
    );

    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // Firebase Auth no Android mantém a sessão automaticamente.
    if (user == null) {
      context.go('/onboarding');
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!snapshot.exists) {
        context.go('/complete-profile');
        return;
      }

      final data = snapshot.data()!;

      final profileCompleted = data['profileCompleted'] == true;

      if (!mounted) return;

      if (profileCompleted) {
        context.go('/home');
      } else {
        context.go('/complete-profile');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar sua conta: $e',
          ),
        ),
      );

      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              JuntaiMark(size: 96),
              SizedBox(height: 18),
              JuntaiLogo(size: 60),
              SizedBox(height: 14),
              Text(
                'Encontre. Participe. Juntaí.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
