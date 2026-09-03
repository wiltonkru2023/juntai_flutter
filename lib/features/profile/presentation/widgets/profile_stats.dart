import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats(
      {super.key,
      required this.activities,
      required this.participations,
      required this.friends});
  final int activities, participations, friends;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _s('$activities', 'Atividades'),
        _s('$participations', 'Participações'),
        _s('$friends', 'Amigos')
      ]);
  Widget _s(String a, String b) => Column(children: [
        Text(a,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text(b)
      ]);
}
