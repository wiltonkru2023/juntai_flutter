abstract final class Validators {
  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Informe seu e-mail.';
    if (!v.contains('@') || !v.contains('.'))
      return 'Informe um e-mail válido.';
    return null;
  }

  static String? password(String? value) {
    if ((value ?? '').length < 6) return 'Use pelo menos 6 caracteres.';
    return null;
  }

  static String? requiredField(String? value, [String label = 'campo']) {
    if ((value ?? '').trim().isEmpty) return 'Preencha $label.';
    return null;
  }
}
