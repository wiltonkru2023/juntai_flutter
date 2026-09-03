import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juntai/features/splash/presentation/screens/onboarding_screen.dart';
import 'package:juntai/core/widgets/juntai_logo.dart';

void main() {
  testWidgets('onboarding mostra Juntaí', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    expect(find.byType(JuntaiLogo), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });
}
