import 'package:flutter/material.dart';

class JuntaiLogo extends StatelessWidget {
  const JuntaiLogo({super.key, this.compact = false, this.size = 46});
  final bool compact;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        compact
            ? 'assets/branding/juntai_mark.png'
            : 'assets/branding/juntai_logo.png',
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Juntaí',
      );
}

class JuntaiMark extends StatelessWidget {
  const JuntaiMark({super.key, this.size = 74});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/juntai_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
}
