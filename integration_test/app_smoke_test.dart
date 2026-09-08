import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:juntai/core/widgets/juntai_logo.dart';
import 'package:juntai/features/splash/presentation/screens/onboarding_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding abre com a marca e chamada inicial', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.byType(JuntaiLogo), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });
}
