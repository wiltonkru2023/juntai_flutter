import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';

class BusinessPlansScreen extends StatefulWidget {
  const BusinessPlansScreen({super.key});

  @override
  State<BusinessPlansScreen> createState() => _BusinessPlansScreenState();
}

class _BusinessPlansScreenState extends State<BusinessPlansScreen> {
  String? loading;

  Future<void> _buy(String plan) async {
    setState(() => loading = plan);
    try {
      final result = await ApiService.instance.checkoutPlan(plan);
      final url = (result['checkoutUrl'] ?? '').toString();
      if (url.isEmpty) throw Exception();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } catch (_) {
      if (mounted) context.snack('Não foi possível abrir o pagamento.');
    } finally {
      if (mounted) setState(() => loading = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Planos comerciais')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _plan('Grátis', 'free', 'R\$ 0',
                '1 publicação/mês\n1 publicação ativa\nMétricas básicas'),
            _plan('Local', 'local', 'R\$ 29,90/mês',
                '5 publicações/mês\nBenefícios para grupos\nMétricas comerciais'),
            _plan('Pro', 'pro', 'R\$ 59,90/mês',
                '15 publicações/mês\nVagas abertas e agenda\nCupons e destaque'),
            _plan('Premium', 'premium', 'R\$ 99,90/mês',
                '50 publicações/mês\nCampanhas ampliadas\nRelatórios avançados'),
          ],
        ),
      );

  Widget _plan(String title, String id, String price, String details) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              Text(price, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              Text(details, style: const TextStyle(height: 1.5)),
              if (id != 'free') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading == null ? () => _buy(id) : null,
                    child: Text(loading == id
                        ? 'Abrindo pagamento...'
                        : 'Assinar $title'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
