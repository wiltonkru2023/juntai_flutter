# Google Maps setup — Juntaí

Ative no Google Cloud:
- Maps SDK for Android
- Maps SDK for iOS
- Places API
- Geocoding API

Restrinja as chaves por package name + SHA-1/SHA-256 no Android e Bundle ID no iOS.

O projeto usa um mapa visual de demonstração por padrão. Para ativar `GoogleMap` real, execute com:

```bash
flutter run --dart-define=REAL_MAPS=true
```

Depois configure as API keys nativas conforme a documentação do `google_maps_flutter`.
