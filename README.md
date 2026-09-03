# Juntaí — Flutter

Aplicativo social para encontrar atividades e pessoas próximas, construído a partir dos mockups aprovados.

## O que já existe
- Splash e onboarding
- Login, cadastro, recuperação, completar perfil e localização
- Home, pesquisa e filtros
- Mapa demo + suporte a Google Maps real
- Criar, editar, cancelar e participar de atividades
- Detalhes e participantes
- Lista de chats e chat de grupo
- Notificações/sininho
- Perfil, editar perfil, configurações e privacidade
- Bloquear e denunciar
- Firebase repositories, Security Rules, Storage Rules, Functions e índices

## Rodar
Este pacote contém o código fonte. Se as pastas nativas ainda não existirem no seu computador:

```bash
flutter create . --project-name juntai --org app.juntai --platforms android,ios
flutter pub get
flutter run
```

O app roda em modo demonstração sem Firebase configurado. Consulte `docs/firebase-setup.md` e `docs/maps-setup.md` para produção.
