import 'package:flutter/material.dart';

class ReportActivitySheet extends StatelessWidget {
  const ReportActivitySheet({super.key, required this.onSubmit});
  final ValueChanged<String> onSubmit;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Denunciar atividade',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                for (final r in const [
                  'Informação enganosa',
                  'Conteúdo impróprio',
                  'Spam',
                  'Golpe',
                  'Outro'
                ])
                  ListTile(
                      title: Text(r),
                      onTap: () {
                        onSubmit(r);
                        Navigator.pop(context);
                      })
              ])));
}
