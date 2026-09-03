import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState(
      {super.key,
      required this.title,
      this.message = 'Crie uma e chame a galera.',
      this.icon = Icons.explore_off_rounded});
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center)
          ])));
}
