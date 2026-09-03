import 'package:flutter/material.dart';

Future<bool> confirmDialog(BuildContext context,
        {required String title,
        required String message,
        String confirm = 'Confirmar'}) async =>
    (await showDialog<bool>(
        context: context,
        builder: (_) =>
            AlertDialog(title: Text(title), content: Text(message), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Voltar')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(confirm))
            ]))) ??
    false;
