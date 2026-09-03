import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Central de ajuda',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primary,
                    size: 34,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Como podemos ajudar?',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Veja respostas para os problemas mais comuns do Juntaí.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _Faq(
              title: 'Não recebo notificações',
              body:
                  'Abra Configurações > Privacidade e confirme que as notificações de chat e atividades estão ativadas. Também verifique nas configurações do Android se o Juntaí tem permissão para mostrar notificações.',
            ),
            const _Faq(
              title: 'Minha localização não funciona',
              body:
                  'Verifique se o GPS do celular está ligado e se o Juntaí tem permissão de localização. Em Configurações > Localização você pode solicitar a permissão novamente.',
            ),
            const _Faq(
              title: 'Não consigo entrar em uma atividade',
              body:
                  'A atividade pode estar lotada, cancelada ou ser privada. Em atividades privadas, o organizador precisa aprovar a solicitação antes da sua participação.',
            ),
            const _Faq(
              title: 'Como bloquear ou denunciar alguém?',
              body:
                  'Abra o perfil ou a área de opções relacionada ao usuário e use Bloquear ou Denunciar. Bloqueios podem ser revisados em Configurações > Usuários bloqueados.',
            ),
            const _Faq(
              title: 'Como excluir minha conta?',
              body:
                  'Abra Configurações > Excluir conta. A ação é permanente e inicia a remoção dos dados pessoais vinculados à conta, observadas as retenções necessárias por segurança ou obrigação legal.',
            ),
            const _Faq(
              title: 'Fotos não aparecem',
              body:
                  'Confirme sua conexão com a internet. Fotos de perfil, capas e imagens do chat são enviadas ao serviço de mídia e podem levar alguns segundos para aparecer após o upload.',
            ),
            const SizedBox(height: 18),
            if (user != null)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.copy_all_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Copiar informações da conta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Útil ao registrar um problema de suporte.',
                  ),
                  onTap: () async {
                    final text = [
                      'Juntaí',
                      'UID: ${user.uid}',
                      'E-mail: ${user.email ?? 'não informado'}',
                    ].join('\n');

                    await Clipboard.setData(
                      ClipboardData(text: text),
                    );

                    if (!context.mounted) return;
                    context.snack('Informações copiadas.');
                  },
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/terms'),
                    child: const Text('Termos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/privacy-policy'),
                    child: const Text('Privacidade'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
