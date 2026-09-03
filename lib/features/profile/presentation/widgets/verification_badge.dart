import 'package:flutter/material.dart';import '../../../../app/theme/app_colors.dart';
class VerificationBadge extends StatelessWidget{const VerificationBadge({super.key,this.verified=true});final bool verified;@override Widget build(BuildContext context)=>verified?const Chip(avatar:Icon(Icons.verified_rounded,color:AppColors.blue,size:18),label:Text('Verificado')):const SizedBox.shrink();}
