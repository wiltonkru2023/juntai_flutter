import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks links = AppLinks();

  Stream<Uri> get uriLinks => links.uriLinkStream;

  Future<Uri?> initialLink() => links.getInitialLink();

  Future<String?> routeFor(Uri uri) async {
    final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();

    if (segments.isEmpty) return null;
    if (segments.first == 'app' && segments.length > 1) {
      segments.removeAt(0);
    }

    switch (segments.first) {
      case 'activity':
        return segments.length >= 2 ? '/activity/${segments[1]}' : null;
      case 'business':
        return segments.length >= 2 ? '/business/${segments[1]}' : '/business';
      case 'discovery':
      case 'event':
        return segments.length >= 2 ? '/discovery/${segments[1]}' : null;
      case 'benefit':
        return segments.length >= 2 ? '/benefit/${segments[1]}' : null;
      case 'profile':
        if (segments.length < 2) return null;
        final username = segments[1].toLowerCase().replaceFirst('@', '');
        final usernameDoc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(username)
            .get();
        final uid = usernameDoc.data()?['uid']?.toString();
        return uid == null || uid.isEmpty ? null : '/profile/user/$uid';
      case 'message':
      case 'direct-chat':
        return segments.length >= 2 ? '/message/${segments[1]}' : null;
      default:
        return null;
    }
  }
}
