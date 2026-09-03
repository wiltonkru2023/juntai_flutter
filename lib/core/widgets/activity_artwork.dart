import 'package:flutter/material.dart';
import '../../shared/enums/activity_category.dart';

class ActivityArtwork extends StatelessWidget {
  const ActivityArtwork({super.key, required this.category, this.height = 140});
  final ActivityCategory category;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
      height: height,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                category.color.withValues(alpha: .12),
                category.color.withValues(alpha: .38)
              ])),
      child: Stack(children: [
        Positioned(
            right: -18,
            bottom: -18,
            child: Icon(category.icon,
                size: 120, color: category.color.withValues(alpha: .16))),
        Center(
            child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .92),
                    shape: BoxShape.circle),
                child: Icon(category.icon, size: 36, color: category.color)))
      ]));
}
