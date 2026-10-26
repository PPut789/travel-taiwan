// Deterministic image transport for screenshot tests. Bytes are the actual
// public source photos, with URL, canonical ID and SHA-256 in the fixture manifest.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SourcePhotoClient implements HttpClient {
  final Map<String, List<int>> _photos;
  SourcePhotoClient(this._photos);

  factory SourcePhotoClient.fromManifest(String directory) {
    final file = File('$directory/manifest.json');
    final rows = jsonDecode(file.readAsStringSync()) as List;
    return SourcePhotoClient({
      for (final row in rows)
        if (row['file'] != null)
          row['url'] as String: File(
            '$directory/${row['file']}',
          ).readAsBytesSync(),
    });
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _PhotoRequest(_photos[url.toString()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoRequest implements HttpClientRequest {
  final List<int>? bytes;
  _PhotoRequest(this.bytes);
  @override
  Future<HttpClientResponse> close() async =>
      _PhotoResponse(bytes ?? const [], bytes == null ? 404 : 200);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  final List<int> bytes;
  @override
  final int statusCode;
  _PhotoResponse(this.bytes, this.statusCode);
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
