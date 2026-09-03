# Juntaí — Status de implementação

Atualizado em 03/09/2026.

## App Flutter

- [x] Splash, onboarding, autenticação e recuperação de senha
- [x] Perfil, perfil público, seguir, bloquear e denunciar
- [x] Home, pesquisa, filtros, mapa e localização
- [x] Criar, editar e cancelar atividade
- [x] Atividades públicas e privadas com solicitações
- [x] Participantes e chat de grupo
- [x] Conversas privadas entre usuários
- [x] Foto em chat de grupo e privado
- [x] Áudio em chat de grupo e privado enviado por URL (ImageKit via Render)
- [x] Reprodução de áudio por URL com compatibilidade para áudios Base64 antigos
- [x] Áudio de visualização única
- [x] Editar mensagem de texto por até 15 minutos
- [x] Excluir mensagem para mim
- [x] Excluir mensagem para todos por até 48 horas
- [x] Push para chat de grupo e mensagem privada
- [x] Notificações, badge e navegação por push
- [x] Permissões Android e iOS para microfone e mídia

## Lugares, eventos e comércio

- [x] Perfil comercial
- [x] Edição de perfil comercial
- [x] Fluxo de análise/aprovação comercial
- [x] Publicação bloqueada enquanto o perfil não estiver aprovado
- [x] Publicações comerciais e eventos
- [x] Editar publicação
- [x] Arquivar publicação
- [x] Limite de publicações ativas por plano
- [x] Limite mensal real por plano
- [x] Métricas de impressão e abertura
- [x] Métrica de atividades criadas a partir de uma descoberta
- [x] Métrica de participantes gerados, com deduplicação por usuário/descoberta
- [x] Descobertas ordenadas por proximidade quando a localização estiver disponível
- [x] Seguir comércio, abrir site e rota externa

## Backend e segurança

- [x] Backend canônico na raiz (`server.js`)
- [x] Upload autenticado de imagem
- [x] Upload autenticado de áudio
- [x] Firebase Admin usando variáveis de ambiente
- [x] Firestore Rules para mensagens por URL
- [x] Regras para edição e exclusão temporizadas de mensagens
- [x] Regras para visualização única
- [x] Push de mensagens privadas e de grupos
- [x] Métricas comerciais protegidas pelo backend
- [x] Reports, bloqueios e exclusão de conta

## Antes de publicar nas lojas

- [ ] Confirmar `GoogleService-Info.plist` no iOS
- [ ] Confirmar Google Maps API key Android/iOS se Maps real for usado
- [ ] Confirmar providers Google/Apple no Firebase
- [ ] Confirmar assinatura release Android/iOS
- [ ] Executar `flutter analyze`
- [ ] Executar `flutter test`
- [ ] Gerar e testar APK/AAB release em dispositivo real
- [ ] Testar microfone, foto, push e chat com duas contas em dois aparelhos
