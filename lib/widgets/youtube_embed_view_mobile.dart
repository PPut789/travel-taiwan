import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeEmbedView extends StatefulWidget {
  final String url;

  const YouTubeEmbedView({super.key, required this.url});

  @override
  State<YouTubeEmbedView> createState() => _YouTubeEmbedViewState();
}

class _YouTubeEmbedViewState extends State<YouTubeEmbedView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    final embedUrl = _buildEmbedUrl(widget.url);
    if (embedUrl != null) {
      controller.loadRequest(
        embedUrl,
        headers: const {'Referer': 'https://www.youtube.com/'},
      );
    } else {
      controller.loadHtmlString(
        '<html><body style="margin:0;background:#000"></body></html>',
        baseUrl: 'https://www.youtube.com',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: controller);
  }

  Uri? _buildEmbedUrl(String url) {
    final videoId = YoutubePlayerController.convertUrlToId(url);
    if (videoId == null) return null;

    return Uri.https('www.youtube.com', '/embed/$videoId', {
      'playsinline': '1',
      'rel': '0',
      'autoplay': '1',
      'origin': 'https://www.youtube.com',
    });
  }
}
