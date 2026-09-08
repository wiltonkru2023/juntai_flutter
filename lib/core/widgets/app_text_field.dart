import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    this.onTap,
    this.readOnly = false,
    this.suffix,
    this.onChanged,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label, hint;
  final IconData? icon, prefixIcon, suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final bool obscureText, readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
              (prefixIcon ?? icon) == null ? null : Icon(prefixIcon ?? icon),
          suffixIcon: suffix ??
              (suffixIcon == null
                  ? null
                  : IconButton(onPressed: onSuffixTap, icon: Icon(suffixIcon))),
        ),
      );
}
