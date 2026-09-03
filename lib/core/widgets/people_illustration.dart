import 'package:flutter/material.dart';

class PeopleIllustration extends StatelessWidget {
  const PeopleIllustration({super.key, this.height = 230});
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: Image.asset(
          'assets/illustrations/login_people.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Pessoas conectadas pelo Juntaí',
        ),
      );
}
