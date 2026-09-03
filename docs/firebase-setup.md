# Firebase setup — Juntaí

1. Crie um projeto Firebase para `dev` e outro para `prod`.
2. Ative Authentication: Email/Senha, Google e Apple.
3. Ative Firestore, Storage, Cloud Messaging, Functions, Analytics, Crashlytics e App Check.
4. Rode `flutterfire configure` para gerar `firebase_options.dart` (opcional se usar os arquivos nativos do Firebase).
5. Android: adicione `google-services.json` em `android/app/`.
6. iOS: adicione `GoogleService-Info.plist` no Runner pelo Xcode.
7. Rode `firebase deploy --only firestore:rules,firestore:indexes,storage,functions`.

O app inicia em DEMO_MODE por padrão; assim a UI e os fluxos podem ser testados antes das credenciais reais.
