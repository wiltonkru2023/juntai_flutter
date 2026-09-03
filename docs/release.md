# Release

## Antes do build
- `flutter analyze`
- `flutter test`
- confirmar regras Firebase
- confirmar App Check
- restringir Google Maps keys
- configurar assinatura Android/iOS
- revisar política de privacidade e exclusão de conta

## Android
`flutter build appbundle --release --dart-define=DEMO_MODE=false --dart-define=REAL_MAPS=true`

## iOS
`flutter build ipa --release --dart-define=DEMO_MODE=false --dart-define=REAL_MAPS=true`
