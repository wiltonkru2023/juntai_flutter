import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';

class SponsorPostScreen extends StatefulWidget {
  const SponsorPostScreen({super.key, required this.postId});
  final String postId;

  @override
  State<SponsorPostScreen> createState() => _SponsorPostScreenState();
}

class _SponsorPostScreenState extends State<SponsorPostScreen> {
  final city = TextEditingController();
  String package = '24h';
  bool loading = false;

  Future<void> _buy() async {
    setState(() => loading = true);
    try {
      final result = await ApiService.instance.sponsorPost(
        postId: widget.postId,
        package: package,
        city: city.text.trim(),
      );
      final url = (result['checkoutUrl'] ?? '').toString();
      if (url.isEmpty) throw Exception();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } catch (_) {
      if (mounted) context.snack('Não foi possível abrir o pagamento.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Patrocinar publicação')),
        body: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            RadioGroup<String>(
              groupValue: package,
              onChanged: (v) {
                if (v != null) {
                  setState(() => package = v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: '24h',
                    title: Text('Destacar por 24h'),
                    subtitle: Text('R\$ 9,90'),
                  ),
                  RadioListTile<String>(
                    value: '3d',
                    title: Text('Destacar por 3 dias'),
                    subtitle: Text('R\$ 19,90'),
                  ),
                  RadioListTile<String>(
                    value: 'city3d',
                    title: Text('Destaque na cidade por 3 dias'),
                    subtitle: Text('R\$ 39,90'),
                  ),
                ],
              ),
            ),
            if (package == 'city3d')
              TextField(
                controller: city,
                decoration:
                    const InputDecoration(labelText: 'Cidade da campanha'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : _buy,
              child: Text(loading ? 'Aguarde...' : 'Continuar para pagamento'),
            ),
            const SizedBox(height: 10),
            const Text(
                'Publicações pagas aparecem identificadas como “Patrocinado”.'),
          ],
        ),
      );
}
