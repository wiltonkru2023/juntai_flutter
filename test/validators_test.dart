import 'package:flutter_test/flutter_test.dart';
import 'package:juntai/core/utils/validators.dart';

void main() {
  test('valida email', () {
    expect(Validators.email('teste@email.com'), isNull);
    expect(Validators.email('errado'), isNotNull);
  });

  test('valida senha', () {
    expect(Validators.password('123456'), isNull);
    expect(Validators.password('123'), isNotNull);
  });
}
