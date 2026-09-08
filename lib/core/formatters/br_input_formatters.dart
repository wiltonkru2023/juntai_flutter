import 'package:flutter/services.dart';

class BrPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();

    for (var i = 0; i < limited.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if ((limited.length <= 10 && i == 6) || (limited.length > 10 && i == 7)) {
        buffer.write('-');
      }
      buffer.write(limited[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class UfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var value =
        newValue.text.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();

    if (value.length > 2) {
      value = value.substring(0, 2);
    }

    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class UsernameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var value = newValue.text
        .toLowerCase()
        .replaceAll('@', '')
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');

    if (value.length > 15) {
      value = value.substring(0, 15);
    }

    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
