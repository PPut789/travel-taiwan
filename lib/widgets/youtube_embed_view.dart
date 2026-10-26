export 'youtube_embed_view_stub.dart'
    if (dart.library.io) 'youtube_embed_view_mobile.dart'
    if (dart.library.html) 'youtube_embed_view_web.dart';
