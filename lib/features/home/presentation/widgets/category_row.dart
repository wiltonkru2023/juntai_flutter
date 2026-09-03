import 'package:flutter/material.dart';
import '../../../../shared/enums/activity_category.dart';
import 'category_chip.dart';

class CategoryRow extends StatelessWidget {
  const CategoryRow({super.key, this.selected, this.onSelected});
  final ActivityCategory? selected;
  final ValueChanged<ActivityCategory>? onSelected;
  @override
  Widget build(BuildContext context) {
    const cats = [
      ActivityCategory.football,
      ActivityCategory.running,
      ActivityCategory.cycling,
      ActivityCategory.games,
      ActivityCategory.cinema,
      ActivityCategory.coffee
    ];
    return SizedBox(
        height: 92,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemBuilder: (_, i) => CategoryChipCard(
                category: cats[i],
                selected: selected == cats[i],
                onTap: () => onSelected?.call(cats[i])),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: cats.length));
  }
}
