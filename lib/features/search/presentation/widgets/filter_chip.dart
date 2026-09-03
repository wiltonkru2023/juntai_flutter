import 'package:flutter/material.dart';

class JuntaiFilterChip extends StatelessWidget {
  const JuntaiFilterChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => FilterChip(
      label: Text(label), selected: selected, onSelected: onSelected);
}
