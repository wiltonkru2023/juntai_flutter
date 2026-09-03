# Arquitetura

- Flutter / Dart
- Feature-first
- Riverpod para estado
- go_router para navegação
- Repository pattern para Firebase
- DemoAppState para demonstração sem credenciais

A UI nunca deve chamar Firestore diretamente. Em produção, providers devem injetar os repositories Firebase em vez do estado demo.
