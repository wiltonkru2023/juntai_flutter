import 'package:flutter/material.dart';
import '../../../../core/widgets/app_avatar.dart';

class ParticipantAvatarRow extends StatelessWidget {
  const ParticipantAvatarRow(
      {super.key, required this.names, this.maxVisible = 4});
  final List<String> names;
  final int maxVisible;
  @override
  Widget build(BuildContext context) {
    final visible = names.take(maxVisible).toList();
    return SizedBox(
        height: 34,
        child: Stack(children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
                left: i * 24,
                child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: AppAvatar(
                        name: visible[i],
                        size: 34,
                        background: Colors.grey.shade200))),
          if (names.length > maxVisible)
            Positioned(
                left: visible.length * 24,
                child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.grey.shade200,
                    child: Text('+${names.length - maxVisible}',
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600))))
        ]));
  }
}
