import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/username_service.dart';

class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final controller = TextEditingController();
  bool saving = false;
  bool checking = false;
  bool? available;
  String original = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (!mounted) return;
    original = (doc.data()?['username'] ?? '').toString();
    controller.text = original;
    setState(() {});
  }

  Future<void> _check() async {
    final value = UsernameService.normalize(controller.text);
    final error = UsernameService.validate(value);
    if (error != null) {
      context.snack(error);
      return;
    }

    if (value == original) {
      setState(() => available = true);
      return;
    }

    setState(() => checking = true);
    try {
      final result = await UsernameService().isAvailable(value);
      if (mounted) setState(() => available = result);
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _save() async {
    final value = UsernameService.normalize(controller.text);
    final error = UsernameService.validate(value);
    if (error != null) {
      context.snack(error);
      return;
    }

    setState(() => saving = true);
    try {
      await ApiService.instance.changeUsername(value);
      if (!mounted) return;
      context.snack('Seu @usuário agora é @$value.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alterar @usuário')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            TextField(
              controller: controller,
              autocorrect: false,
              decoration: InputDecoration(
                prefixText: '@',
                labelText: 'Usuário',
                suffixIcon: checking
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        onPressed: _check,
                        icon: const Icon(Icons.search_rounded),
                      ),
              ),
              onChanged: (_) => setState(() => available = null),
            ),
            if (available != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  available == true
                      ? '✓ disponível'
                      : 'Este @usuário já está em uso.',
                  style: TextStyle(
                    color: available == true ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(
                saving ? 'Salvando...' : 'Salvar @usuário',
              ),
            ),
          ],
        ),
      );
}
