import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/google_auth_service.dart';
import '../../../../core/services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await NotificationService.instance.unregisterCurrentDevice();
      await GoogleAuthService.instance.signOut();
      await FirebaseAuth.instance.signOut();
      await NotificationService.instance.clearDeliveredNotifications();

      if (!context.mounted) return;
      context.go('/login');
    } catch (error) {
      if (!context.mounted) return;
      context.snack('Não foi possível sair da conta: $error');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      await NotificationService.instance.unregisterCurrentDevice();
      await ApiService.instance.deleteAccount();
      await GoogleAuthService.instance.signOut();
      await FirebaseAuth.instance.signOut();
      await NotificationService.instance.clearDeliveredNotifications();

      if (!context.mounted) return;
      context.go('/onboarding');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      context.snack(error.message);
    } catch (error) {
      if (!context.mounted) return;
      context.snack('Não foi possível excluir sua conta: $error');
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Essa ação é permanente. Seu perfil e dados pessoais de conta serão removidos. '
          'Alguns registros podem ser preservados quando necessários para segurança, denúncias, '
          'obrigações legais ou integridade do histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Excluir definitivamente',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteAccount(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Configurações',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _tile(
              context,
              Icons.person_outline_rounded,
              'Conta',
              () => context.go('/profile/edit'),
            ),
            _tile(
              context,
              Icons.alternate_email_rounded,
              'Alterar @usuÃ¡rio',
              () => context.go('/profile/username/change'),
            ),
            _tile(
              context,
              Icons.alternate_email_rounded,
              'Alterar @usuário',
              () => context.go('/profile/username/change'),
            ),
            _tile(
              context,
              Icons.notifications_none_rounded,
              'Notificações',
              () => context.go('/notifications'),
            ),
            _tile(
              context,
              Icons.tune_rounded,
              'Preferências de notificações',
              () => context.go('/privacy'),
            ),
            _tile(
              context,
              Icons.location_on_outlined,
              'Localização',
              () => context.go('/location-permission'),
            ),
            _tile(
              context,
              Icons.privacy_tip_outlined,
              'Privacidade',
              () => context.go('/privacy'),
            ),
            _tile(
              context,
              Icons.block_rounded,
              'Usuários bloqueados',
              () => context.go('/blocked-users'),
            ),
            const Divider(height: 32),
            _tile(
              context,
              Icons.help_outline_rounded,
              'Ajuda',
              () => context.push('/help'),
            ),
            _tile(
              context,
              Icons.description_outlined,
              'Termos de uso',
              () => context.push('/terms'),
            ),
            _tile(
              context,
              Icons.policy_outlined,
              'Política de privacidade',
              () => context.push('/privacy-policy'),
            ),
            const Divider(height: 32),
            _tile(
              context,
              Icons.delete_forever_rounded,
              'Excluir conta',
              () => _confirmDelete(context),
              danger: true,
            ),
            _tile(
              context,
              Icons.logout_rounded,
              'Sair',
              () => _logout(context),
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: danger ? AppColors.error : AppColors.primary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: danger ? AppColors.error : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
