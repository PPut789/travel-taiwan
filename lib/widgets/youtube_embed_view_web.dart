// ignore_for_file: avoid_web_libraries_in_flutter

// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeEmbedView extends StatefulWidget {
  final String url;

  const YouTubeEmbedView({super.key, required this.url});

  @override
  State<YouTubeEmbedView> createState() => _YouTubeEmbedViewState();
}

class _YouTubeEmbedViewState extends State<YouTubeEmbedView> {
  static int viewCounter = 0;
  late final String viewType;

  @override
  void initState() {
    super.initState();
    viewType = 'youtube-embed-${viewCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final videoId = YoutubePlayerController.convertUrlToId(widget.url);
      final iframe = html.IFrameElement()
        ..src = videoId == null
            ? 'about:blank'
            : 'https://www.youtube.com/embed/$videoId?playsinline=1&rel=0&autoplay=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..allowFullscreen = true;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: viewType);
  }
}
