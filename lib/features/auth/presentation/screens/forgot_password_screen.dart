import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/juntai_logo.dart';

class ForgotPasswordScreen extends StatefulWidget { const ForgotPasswordScreen({super.key}); @override State<ForgotPasswordScreen> createState()=>_ForgotPasswordScreenState(); }
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>{
  final email=TextEditingController();
  @override void dispose(){email.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(leading:IconButton(onPressed:()=>context.pop(),icon:const Icon(Icons.arrow_back_rounded))),body:SafeArea(child:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Center(child:JuntaiLogo(size:46)),const SizedBox(height:40),const Icon(Icons.lock_reset_rounded,size:72),const SizedBox(height:18),const Text('Recuperar senha',textAlign:TextAlign.center,style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),const SizedBox(height:8),const Text('iigite seu e-mail. No backend Firebase, enviaremos um link para redefinir sua senha.',textAlign:TextAlign.center),const SizedBox(height:28),AppTextField(controller:email,hint:'E-mail',prefixIcon:Icons.email_outlined),const SizedBox(height:16),AppButton(label:'Enviar link',onPressed:(){context.snack('Link de recuperação solicitado.');context.pop();})
  ]))));
}
