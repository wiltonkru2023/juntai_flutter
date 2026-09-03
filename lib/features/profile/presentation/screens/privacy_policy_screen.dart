import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Política de privacidade',
      updatedAt: '02/09/2026',
      intro:
          'Esta Política explica como o Juntaí trata dados pessoais necessários para autenticação, perfis, atividades, chat, segurança, localização aproximada e notificações. O Juntaí busca coletar apenas o necessário para oferecer e proteger o serviço.',
      sections: [
        LegalSection(
          title: '1. Dados da conta e perfil',
          body:
              'Podemos tratar identificador da conta, nome, e-mail, foto, cidade, biografia, interesses, preferências de privacidade e informações básicas de uso do perfil. O login pode ser realizado por e-mail/senha ou, quando habilitado, por provedores como Google.',
        ),
        LegalSection(
          title: '2. Atividades e participação',
          body:
              'Ao criar ou participar de uma atividade, o serviço pode armazenar título, descrição, categoria, endereço, coordenadas do local da atividade, horário, limite de participantes, status de participação e informações relacionadas a solicitações de entrada.',
        ),
        LegalSection(
          title: '3. Localização',
          body:
              'Com sua permissão, o aplicativo pode acessar a localização do dispositivo para calcular distâncias, centralizar o mapa e encontrar atividades próximas. O Juntaí não publica sua localização em tempo real para outros usuários. O endereço e as coordenadas de uma atividade criada por você podem ser armazenados para exibir o local dessa atividade.',
        ),
        LegalSection(
          title: '4. Mensagens, imagens e áudio',
          body:
              'Mensagens de grupos, imagens enviadas e áudios podem ser processados para disponibilizar a conversa aos participantes autorizados. Imagens podem ser armazenadas por serviço especializado de mídia. Não use o chat para compartilhar dados pessoais sensíveis desnecessários.',
        ),
        LegalSection(
          title: '5. Notificações push',
          body:
              'Quando você permite notificações, o aplicativo registra um token técnico do Firebase Cloud Messaging associado ao seu dispositivo e à sua conta. Esse token é usado somente para encaminhar alertas de mensagens, solicitações, aprovações e atualizações relacionadas ao uso do Juntaí.',
        ),
        LegalSection(
          title: '6. Segurança, bloqueios e denúncias',
          body:
              'Podemos tratar identificadores de usuários bloqueados, conteúdo ou contexto de denúncias e registros necessários para investigar abuso, proteger usuários, impedir novas interações indevidas e preservar a segurança do serviço.',
        ),
        LegalSection(
          title: '7. Prestadores de serviço',
          body:
              'Para operar o aplicativo, o Juntaí pode utilizar serviços de infraestrutura e processamento, incluindo Firebase/Google para autenticação, banco de dados e notificações; Render para funções de servidor; ImageKit para imagens; e OpenStreetMap/Photon para recursos de mapa e busca de endereços. Cada fornecedor trata dados conforme sua função técnica e suas próprias obrigações de segurança.',
        ),
        LegalSection(
          title: '8. Compartilhamento',
          body:
              'Dados não são vendidos a anunciantes. Informações podem ser compartilhadas com prestadores técnicos necessários ao funcionamento do aplicativo, por obrigação legal, para proteção de direitos e segurança, ou quando você determina a publicação de informações para outros usuários dentro do próprio serviço.',
        ),
        LegalSection(
          title: '9. Retenção e exclusão',
          body:
              'Os dados são mantidos enquanto forem necessários para operar a conta e as funcionalidades utilizadas. Ao solicitar exclusão da conta, dados pessoais diretamente vinculados ao perfil são removidos ou desassociados quando possível. Registros podem ser preservados pelo período necessário para segurança, prevenção de fraude, resolução de disputas, denúncias ou obrigação legal.',
        ),
        LegalSection(
          title: '10. Seus direitos',
          body:
              'Você pode atualizar dados do perfil, alterar preferências, bloquear usuários e solicitar exclusão da conta dentro do aplicativo. Quando aplicável, você também pode solicitar acesso, correção, informação sobre tratamento e outros direitos previstos na legislação brasileira de proteção de dados, utilizando a Central de Ajuda.',
        ),
        LegalSection(
          title: '11. Segurança',
          body:
              'São utilizadas medidas técnicas como autenticação, regras de acesso no banco de dados, comunicação protegida e validações no servidor. Nenhum sistema é totalmente imune a riscos; por isso, mantenha seu dispositivo e credenciais protegidos e informe comportamentos suspeitos.',
        ),
        LegalSection(
          title: '12. Alterações desta Política',
          body:
              'A Política pode ser atualizada quando houver mudanças relevantes no aplicativo, nos prestadores utilizados ou em requisitos legais. A versão vigente ficará disponível no aplicativo com sua data de atualização.',
        ),
      ],
    );
  }
}
