import 'package:flutter/material.dart';
import '../core/widgets/app_bottom_nav.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: child, bottomNavigationBar: AppBottomNav(location: location));
}
