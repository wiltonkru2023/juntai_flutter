import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/deep_link_service.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class JuntaiApp extends ConsumerStatefulWidget {
  const JuntaiApp({super.key});

  @override
  ConsumerState<JuntaiApp> createState() => _JuntaiAppState();
}

class _JuntaiAppState extends ConsumerState<JuntaiApp> {
  StreamSubscription<Uri>? subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  Future<void> _listen() async {
    final initial = await DeepLinkService.instance.initialLink();

    subscription = DeepLinkService.instance.uriLinks.listen(_openLink);

    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openLink(initial);
      });
    }
  }

  Future<void> _openLink(Uri uri) async {
    final route = await DeepLinkService.instance.routeFor(uri);
    if (!mounted || route == null) return;

    try {
      ref.read(appRouterProvider).go(route);
    } catch (_) {}
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Juntaí',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
