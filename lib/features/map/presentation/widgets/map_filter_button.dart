import 'package:flutter/material.dart';

class MapFilterButton extends StatelessWidget {
  const MapFilterButton({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.tune_rounded),
      label: const Text('Filtrar'));
}
