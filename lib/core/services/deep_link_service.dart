import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks links = AppLinks();
  Stream<Uri> get uriLinks => links.uriLinkStream;
}
