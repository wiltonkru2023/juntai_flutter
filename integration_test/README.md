# Integration tests

Implementado:

- `app_smoke_test.dart`: valida que o onboarding abre com a marca e a chamada
  inicial.

Observação local: neste ambiente, `flutter test integration_test/app_smoke_test.dart`
exige toolchain desktop do Visual Studio; `-d chrome` não é suportado para
`integration_test` pelo Flutter atual.

Fluxos previstos para automatização em ambiente com Firebase Emulator:

1. cadastro
2. login
3. criar atividade
4. participar
5. enviar mensagem
6. abrir mapa
7. editar perfil
8. bloquear/denunciar
