import 'package:flutter/material.dart';
class MyLocationButton extends StatelessWidget{const MyLocationButton({super.key,required this.onTap});final VoidCallback onTap;@override Widget build(BuildContext context)=>FilledButton.tonalIcon(onPressed:onTap,icon:const Icon(Icons.my_location_rounded),label:const Text('Minha localização'));}
