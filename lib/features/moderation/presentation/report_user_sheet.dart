import 'package:flutter/material.dart';

class ReportUserSheet extends StatelessWidget {
  const ReportUserSheet({super.key, required this.onSubmit});
  final ValueChanged<String> onSubmit;
  @override
  Widget build(BuildContext context) {
    const reasons = [
      'Assédio',
      'Spam',
      'Perfil falso',
      'Conteúdo impróprio',
      'Golpe',
      'Ameaça',
      'Outro'
    ];
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Denunciar usuário',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final r in reasons)
                    ListTile(
                        title: Text(r),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          onSubmit(r);
                          Navigator.pop(context);
                        })
                ])));
  }
}
