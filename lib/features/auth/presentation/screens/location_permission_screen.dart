import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_outline_button.dart';
import '../../../../core/widgets/juntai_logo.dart';
import '../../../map/data/location_service.dart';

class LocationPermissionScreen
    extends StatefulWidget {
  const LocationPermissionScreen({
    super.key,
  });

  @override
  State<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends State<LocationPermissionScreen> {
  bool loading = false;

  Future<void> allowLocation() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final position =
          await LocationService.getCurrentPosition();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Localização encontrada: '
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}',
          ),
        ),
      );

      context.go('/home');
    } on LocationServiceException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: SnackBarAction(
            label: 'Configurações',
            onPressed: () {
              LocationService.openAppSettings();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível obter sua localização: $e',
          ),
        ),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.topCenter,
                child: JuntaiLogo(size: 42),
              ),

              const Spacer(),

              Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 82,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Atividades perto de você',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Use sua localização para calcular distâncias, '
                'centralizar o mapa e mostrar atividades próximas. '
                'O Juntaí não publica sua localização em tempo real.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),

              const Spacer(),

              AppButton(
                label: loading
                    ? 'Localizando...'
                    : 'Permitir localização',
                onPressed:
                    loading ? null : allowLocation,
              ),

              const SizedBox(height: 10),

              AppOutlineButton(
                label: 'Agora não',
                onPressed: loading
                    ? null
                    : () => context.go('/home'),
              ),

              const SizedBox(height: 8),

              const Text(
                'Você também poderá escolher sua cidade manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}