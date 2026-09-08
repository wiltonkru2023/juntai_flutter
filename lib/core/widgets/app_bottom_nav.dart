import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.location,
  });

  final String location;

  int get currentIndex {
    if (location.startsWith('/discover') ||
        location.startsWith('/discovery/') ||
        location.startsWith('/business/')) {
      return 1;
    }
    if (location.startsWith('/activity/create')) return 2;
    if (location.startsWith('/chats') ||
        location.startsWith('/chat/') ||
        location.startsWith('/message/')) {
      return 3;
    }
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void go(BuildContext context, int index) {
    const paths = [
      '/home',
      '/discover',
      '/activity/create',
      '/chats',
      '/profile',
    ];
    context.go(paths[index]);
  }

  @override
  Widget build(BuildContext context) {
    final idx = currentIndex;

    Widget navIcon(String asset, bool active, {double size = 28}) =>
        AnimatedOpacity(
          opacity: active ? 1 : .58,
          duration: const Duration(milliseconds: 160),
          child: Image.asset(
            asset,
            width: size,
            height: size,
            fit: BoxFit.contain,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            cacheHeight:
                (size * MediaQuery.devicePixelRatioOf(context)).round(),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Icon(
              Icons.circle_rounded,
              color: active ? AppColors.primary : Colors.blueGrey,
              size: size,
            ),
          ),
        );

    Widget item(int i, String asset, String label) {
      final active = idx == i;

      return Expanded(
        child: InkWell(
          onTap: () => go(context, i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                navIcon(asset, active),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : Colors.blueGrey,
                  ),
                ),
                if (active && i != 2)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            item(0, 'assets/icons/nav/icone_inicio.png', 'Início'),
            item(1, 'assets/icons/nav/icone_explorar.png', 'Descobrir'),
            Expanded(
              child: InkWell(
                onTap: () => go(context, 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -16),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: .22),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: navIcon(
                            'assets/icons/nav/icone_criar.png',
                            true,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -13),
                      child: Text(
                        'Criar',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              idx == 2 ? FontWeight.w700 : FontWeight.w500,
                          color: idx == 2 ? AppColors.primary : Colors.blueGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            item(
              3,
              'assets/icons/nav/icone_mensagens.png',
              'Conversas',
            ),
            item(4, 'assets/icons/nav/icone_perfil.png', 'Perfil'),
          ],
        ),
      ),
    );
  }
}
