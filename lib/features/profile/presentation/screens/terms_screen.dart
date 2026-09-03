import 'package:flutter/material.dart';

import 'legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Termos de uso',
      updatedAt: '02/09/2026',
      intro:
          'Estes Termos regulam o uso do Juntaí, aplicativo destinado a conectar pessoas interessadas em participar e organizar atividades. Ao criar uma conta ou usar o serviço, você declara que leu e concorda com estas condições.',
      sections: [
        LegalSection(
          title: '1. Conta e acesso',
          body:
              'Você deve fornecer informações verdadeiras e manter o acesso à sua conta protegido. A conta é pessoal. Você é responsável pelas ações realizadas enquanto estiver autenticado. O Juntaí pode limitar ou suspender contas usadas para fraude, abuso, assédio, spam, falsidade de identidade ou violação destes Termos.',
        ),
        LegalSection(
          title: '2. Atividades e encontros',
          body:
              'O Juntaí facilita o encontro entre usuários, mas não organiza, supervisiona nem garante atividades criadas pelos usuários. O organizador é responsável pelas informações publicadas sobre horário, local, capacidade, regras e condições da atividade. Cada participante deve avaliar por conta própria se deseja participar e adotar cuidados compatíveis com a atividade.',
        ),
        LegalSection(
          title: '3. Conteúdo publicado',
          body:
              'Você continua responsável pelo conteúdo que publica, incluindo nome, biografia, fotos, mensagens, descrição de atividades e demais materiais. Ao enviar conteúdo ao Juntaí, você autoriza o processamento e a exibição desse conteúdo na medida necessária para operar as funcionalidades do aplicativo.',
        ),
        LegalSection(
          title: '4. Condutas proibidas',
          body:
              'Não é permitido usar o serviço para ameaças, assédio, discriminação, exploração, fraude, golpes, spam, conteúdo ilegal, divulgação não autorizada de dados pessoais, incentivo a violência, falsidade de identidade ou atividades que coloquem outras pessoas em risco. Denúncias podem ser analisadas e resultar em restrições de conta.',
        ),
        LegalSection(
          title: '5. Chat, bloqueio e denúncia',
          body:
              'Mensagens do grupo existem para comunicação relacionada às atividades e convivência entre participantes. Recursos de bloqueio e denúncia podem ser utilizados quando houver comportamento inadequado. O envio de uma denúncia não garante uma medida específica; a resposta dependerá das informações disponíveis e da gravidade do caso.',
        ),
        LegalSection(
          title: '6. Fotos e arquivos',
          body:
              'Você somente deve enviar imagens e arquivos que tenha direito de utilizar e compartilhar. Não envie documentos pessoais, informações financeiras, conteúdo íntimo sem consentimento ou qualquer material cuja divulgação possa causar dano a terceiros.',
        ),
        LegalSection(
          title: '7. Disponibilidade do serviço',
          body:
              'O serviço pode ficar temporariamente indisponível por manutenção, falhas de rede, serviços de terceiros ou motivos de segurança. Funcionalidades podem ser alteradas para correção de erros, segurança, compatibilidade ou evolução do produto.',
        ),
        LegalSection(
          title: '8. Encerramento da conta',
          body:
              'Você pode solicitar a exclusão da conta nas Configurações. Alguns registros podem ser mantidos quando necessários para segurança, prevenção de abuso, cumprimento de obrigação legal ou preservação da integridade de atividades e denúncias, conforme descrito na Política de privacidade.',
        ),
        LegalSection(
          title: '9. Responsabilidade',
          body:
              'O Juntaí não garante o comportamento, identidade, pontualidade ou segurança de outros usuários. Em encontros presenciais, use locais adequados, informe alguém de confiança quando necessário e interrompa a participação se considerar a situação insegura.',
        ),
        LegalSection(
          title: '10. Alterações',
          body:
              'Estes Termos podem ser atualizados para refletir mudanças no serviço, em requisitos legais ou em práticas de segurança. A versão vigente ficará disponível no aplicativo com a data da última atualização.',
        ),
      ],
    );
  }
}
