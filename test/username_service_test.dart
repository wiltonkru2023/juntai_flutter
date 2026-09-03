import 'package:flutter_test/flutter_test.dart';
import 'package:juntai/core/services/username_service.dart';

void main() {
  group('UsernameService', () {
    test('normaliza arroba, caixa e caracteres inválidos', () {
      expect(UsernameService.normalize(' @Wilton! '), 'wilton');
    });

    test('aceita formato canônico', () {
      expect(UsernameService.validate('wilton_01'), isNull);
      expect(UsernameService.validate('wilton.silva'), isNull);
    });

    test('rejeita nomes curtos e iniciados por número', () {
      expect(UsernameService.validate('ab'), isNotNull);
      expect(UsernameService.validate('1wilton'), isNotNull);
    });
  });
}
