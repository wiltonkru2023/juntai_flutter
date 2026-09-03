import 'package:flutter/widgets.dart';
import '../../../../core/services/api_service.dart';

class PostMetricTracker extends StatefulWidget {
  const PostMetricTracker(
      {super.key, required this.postId, required this.event});
  final String postId, event;
  @override
  State<PostMetricTracker> createState() => _PostMetricTrackerState();
}

class _PostMetricTrackerState extends State<PostMetricTracker> {
  @override
  void initState() {
    super.initState();
    ApiService.instance
        .trackBusinessPost(widget.postId, widget.event)
        .catchError((_) => <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
