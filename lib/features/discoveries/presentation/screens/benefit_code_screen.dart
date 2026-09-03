import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';

class BenefitCodeScreen extends StatefulWidget {
  const BenefitCodeScreen({super.key, required this.code});
  final String code;

  @override
  State<BenefitCodeScreen> createState() => _BenefitCodeScreenState();
}

class _BenefitCodeScreenState extends State<BenefitCodeScreen> {
  bool redeeming = false;

  Future<void> _redeem() async {
    setState(() => redeeming = true);
    try {
      await ApiService.instance.redeemBenefit(widget.code);
      if (mounted) {
        context.snack('Benefício validado com sucesso.');
        setState(() {});
      }
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } finally {
      if (mounted) setState(() => redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Benefício Juntaí')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: ApiService.instance.benefitStatus(widget.code),
          builder: (_, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;
            final code = (data['code'] ?? widget.code).toString();
            final status = (data['status'] ?? '').toString();
            final canRedeem = data['canRedeem'] == true;

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.redeem_rounded,
                          size: 56, color: AppColors.primary),
                      const SizedBox(height: 10),
                      const Text('Código',
                          style: TextStyle(color: AppColors.textSecondary)),
                      SelectableText(
                        code,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (data['benefitLabel'] ?? 'Benefício Juntaí').toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status == 'redeemed'
                            ? '✓ Código já utilizado'
                            : 'Código válido',
                        style: TextStyle(
                          color: status == 'redeemed'
                              ? AppColors.textSecondary
                              : Colors.green,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (canRedeem)
                  FilledButton.icon(
                    onPressed: redeeming ? null : _redeem,
                    icon: const Icon(Icons.verified_rounded),
                    label: Text(redeeming ? 'Validando...' : 'Confirmar uso'),
                  ),
              ],
            );
          },
        ),
      );
}
