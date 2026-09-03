# Juntaí — Flutter

Aplicativo social para encontrar pessoas, atividades, lugares e eventos próximos.

## Principais recursos

- autenticação e perfis de usuário;
- atividades públicas e privadas;
- participação, solicitações e grupos;
- chat de grupo e conversa privada;
- texto, foto e áudio;
- edição de texto por 15 minutos;
- exclusão para mim e exclusão para todos por 48 horas;
- áudio armazenado como mídia externa e salvo no Firestore apenas por URL;
- notificações push;
- bloqueio e denúncia;
- área comercial com aprovação, limites de plano, edição e arquivamento;
- descobertas de comércios/eventos ordenadas por proximidade quando possível;
- métricas de visualização, abertura, grupos criados e participantes gerados.

## Backend

O backend de produção é o `server.js` da raiz e é executado pelo Render usando o `package.json` da raiz.

Variáveis obrigatórias no Render:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `IMAGEKIT_PRIVATE_KEY` para upload de imagens e áudios
- `IMAGEKIT_PUBLIC_KEY` e `IMAGEKIT_URL_ENDPOINT` quando usados

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Validar o backend:

```bash
npm ci
npm run check
```

Depois de alterar regras/índices:

```bash
firebase deploy --only firestore:rules,firestore:indexes --project juntai-f7605
```

Consulte `PROJECT_STATUS.md` para o checklist de release.
