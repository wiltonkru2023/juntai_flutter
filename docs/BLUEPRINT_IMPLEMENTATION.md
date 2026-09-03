# Juntaí — Blueprint completo

Este script adiciona:

- perfil comercial com @usuário, avatar, capa, galeria, estado, telefone e Instagram;
- comércio, organizador e instituição;
- seguidores persistidos e métricas;
- experiências, eventos, vagas abertas, promoção para grupo e agenda;
- preço normal e preço Juntaí;
- capacidade, "Eu vou", horários e bloco urgente na Home;
- benefícios automáticos para grupo e código JUNTAI;
- validação de benefício sem reutilização;
- dashboard e métricas comerciais;
- planos Free, Local, Pro e Premium;
- pagamento por Mercado Pago;
- campanhas patrocinadas;
- seguir pessoa pelo backend com counters;
- telas Seguidores e Seguindo;
- troca segura de @usuário;
- preferências granulares de notificações;
- normalização de interesses;
- deep links;
- Descobrir na navegação inferior;
- Quero ir e Encontrar companhia;
- moderação ampliada;
- portal web /admin;
- chat privado pelo backend;
- áudio estilo WhatsApp;
- status Enviada / Entregue / Visualizada;
- Apple Login no código Flutter.

## Render

Configure:

MERCADO_PAGO_ACCESS_TOKEN
PUBLIC_API_URL=https://juntai-flutter.onrender.com
ADMIN_EMAILS=seu-email@dominio.com
CRON_SECRET=uma-chave-forte

## Cron

POST:

https://juntai-flutter.onrender.com/blueprint/cron/reminders

Header:

x-cron-secret: valor de CRON_SECRET

Sugestão: executar a cada 15 minutos.

## Apple

No Firebase Authentication:
- ative Sign in with Apple.

No Apple Developer:
- habilite Sign in with Apple no App ID;
- configure o projeto iOS/Xcode antes de publicar.

## Admin

O painel é copiado para:

juntai.nexoio.com.br/admin

quando -SiteRoot apontar para o projeto Firebase Hosting.