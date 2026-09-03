import 'package:flutter/material.dart';

abstract final class AppShadows {
  static List<BoxShadow> get soft => [
        BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 18,
            offset: const Offset(0, 6)),
      ];
}
