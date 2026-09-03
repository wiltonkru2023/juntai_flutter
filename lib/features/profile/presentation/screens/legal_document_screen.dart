import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';

class LegalSection {
  const LegalSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.updatedAt,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  intro,
                  style: const TextStyle(
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Última atualização: $updatedAt',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 22),
              for (final section in sections) ...[
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.body,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.55,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
