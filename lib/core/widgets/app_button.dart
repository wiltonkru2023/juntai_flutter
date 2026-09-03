import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: danger ? AppColors.error : AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
    final child = loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: icon == null
          ? FilledButton(onPressed: loading ? null : onPressed, style: style, child: child)
          : FilledButton.icon(onPressed: loading ? null : onPressed, style: style, icon: Icon(icon), label: child),
    );
  }
}
