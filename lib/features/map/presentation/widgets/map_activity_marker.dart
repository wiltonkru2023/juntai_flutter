import 'package:flutter/material.dart';
import '../../../../shared/enums/activity_category.dart';

class MapActivityMarker extends StatelessWidget {
  const MapActivityMarker(
      {super.key, required this.category, required this.onTap});
  final ActivityCategory category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .12), blurRadius: 12)
              ]),
          child: Icon(category.icon, color: category.color)));
}
