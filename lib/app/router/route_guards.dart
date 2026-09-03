// Guards podem consultar authProvider quando Firebase estiver conectado.
String? requireAuth(bool signedIn,String location)=>signedIn?null:'/login';
