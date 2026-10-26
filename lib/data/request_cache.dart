class RequestCache<K, V> {
  final _requests = <K, Future<V>>{};

  Future<V> load(K key, Future<V> Function() fetch, {bool refresh = false}) {
    if (refresh) _requests.remove(key);
    return _requests.putIfAbsent(key, () {
      late final Future<V> request;
      request = Future<V>.sync(fetch).then(
        (value) => value,
        onError: (Object error, StackTrace stack) {
          if (identical(_requests[key], request)) _requests.remove(key);
          Error.throwWithStackTrace(error, stack);
        },
      );
      return request;
    });
  }
}
