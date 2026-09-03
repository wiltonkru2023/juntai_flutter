import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField(
      {super.key,
      this.controller,
      this.onChanged,
      this.onTap,
      this.onFilter,
      this.readOnly = false});
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap, onFilter;
  final bool readOnly;
  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      decoration: InputDecoration(
          hintText: 'Buscar atividades ou pessoas',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
              onPressed: onFilter, icon: const Icon(Icons.tune_rounded))));
}
