import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A transport failure that is safe to show to the user.
class UpdateTransportException implements Exception {
  const UpdateTransportException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thrown when the caller cancelled a download.
class UpdateCancelled implements Exception {
  const UpdateCancelled();

  @override
  String toString() => 'Cancelled';
}

/// One HTTP response, body already read.
class HttpResponseData {
  const HttpResponseData({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Uint8List body;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  String get text => utf8.decode(body, allowMalformed: true);
}

/// Swappable so feed and download logic can be tested without a network, and
/// so a future proxy-aware client is a drop-in.
abstract interface class HttpTransport {
  Future<HttpResponseData> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
  });

  /// Streams [url] into [destination] and returns the number of bytes written.
  Future<int> download(
    Uri url, {
    required File destination,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration? timeout,
  });

  void close();
}

/// `dart:io` implementation with the guards the updater needs.
///
/// HTTPS only, bounded bodies, redirects followed by hand so a mirror cannot
/// downgrade the connection, and a per-event idle timeout so a stalled server
/// cannot hang the check forever.
class IoHttpTransport implements HttpTransport {
  IoHttpTransport({
    this.userAgent = defaultUserAgent,
    this.connectTimeout = const Duration(seconds: 3),
    this.idleTimeout = const Duration(seconds: 6),
    this.maxDownloadDuration = const Duration(minutes: 30),
    this.maxResponseBytes = 4 << 20,
    this.allowInsecure = false,
    this.maxRedirects = 5,
    HttpClient? client,
    bool useSystemProxy = true,
  }) : _client = client ?? HttpClient() {
    _client.connectionTimeout = connectTimeout;
    _client.autoUncompress = true;
    if (useSystemProxy) {
      _client.findProxy = HttpClient.findProxyFromEnvironment;
    }
  }

  static const String defaultUserAgent = 'FanCAD-Updater';

  final String userAgent;
  final Duration connectTimeout;

  /// Gaps longer than this between bytes abort the request.
  final Duration idleTimeout;

  /// A download that keeps trickling forever is still abandoned here.
  final Duration maxDownloadDuration;
  final int maxResponseBytes;
  final int maxRedirects;

  /// Only tests set this: release feeds must never be fetched over plain HTTP.
  final bool allowInsecure;

  final HttpClient _client;

  @override
  Future<HttpResponseData> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
  }) async {
    final response = await _open(url, headers: headers, timeout: timeout);
    final buffer = BytesBuilder(copy: false);
    try {
      await for (final chunk in response.timeout(timeout ?? idleTimeout)) {
        buffer.add(chunk);
        if (buffer.length > maxResponseBytes) {
          throw const UpdateTransportException('Response is too large');
        }
      }
    } on TimeoutException {
      throw const UpdateTransportException('The server did not answer in time');
    } on HttpException catch (error) {
      throw UpdateTransportException('The connection failed: ${error.message}');
    } on SocketException catch (error) {
      throw UpdateTransportException(_socketMessage(error));
    }
    return HttpResponseData(
      statusCode: response.statusCode,
      body: buffer.takeBytes(),
      headers: _flattenHeaders(response.headers),
    );
  }

  @override
  Future<int> download(
    Uri url, {
    required File destination,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration? timeout,
  }) async {
    final response = await _open(
      url,
      headers: {HttpHeaders.acceptEncodingHeader: 'identity', ...headers},
      timeout: timeout,
    );
    if (response.statusCode != HttpStatus.ok) {
      await _drainQuietly(response);
      throw UpdateTransportException(
        'Download failed with HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final total = response.contentLength >= 0 ? response.contentLength : null;
    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    final started = DateTime.now();
    var received = 0;
    onProgress?.call(0, total);
    try {
      await for (final chunk in response.timeout(timeout ?? idleTimeout)) {
        if (isCancelled?.call() ?? false) {
          throw const UpdateCancelled();
        }
        if (DateTime.now().difference(started) > maxDownloadDuration) {
          throw const UpdateTransportException('The download took too long');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
        if (total != null && received > total) {
          throw const UpdateTransportException(
            'Download is larger than declared',
          );
        }
      }
      if (total != null && received != total) {
        throw const UpdateTransportException('The download ended early');
      }
      await sink.flush();
      await sink.close();
      return received;
    } on TimeoutException {
      await sink.close();
      await _deleteQuietly(destination);
      throw const UpdateTransportException('The download stalled');
    } on UpdateCancelled {
      await sink.close();
      await _deleteQuietly(destination);
      rethrow;
    } on HttpException catch (error) {
      await sink.close();
      await _deleteQuietly(destination);
      throw UpdateTransportException('The connection failed: ${error.message}');
    } on SocketException catch (error) {
      await sink.close();
      await _deleteQuietly(destination);
      throw UpdateTransportException(_socketMessage(error));
    } catch (_) {
      await sink.close();
      await _deleteQuietly(destination);
      rethrow;
    }
  }

  Future<HttpClientResponse> _open(
    Uri url, {
    required Map<String, String> headers,
    Duration? timeout,
  }) async {
    var current = url;
    for (var hop = 0; hop <= maxRedirects; hop++) {
      if (!allowInsecure && current.scheme != 'https') {
        throw UpdateTransportException(
          'Refusing to fetch ${current.scheme}://${current.host}',
        );
      }
      final HttpClientRequest request;
      try {
        request = await _client.getUrl(current).timeout(connectTimeout);
      } on TimeoutException {
        throw const UpdateTransportException('Could not connect');
      } on SocketException catch (error) {
        throw UpdateTransportException(_socketMessage(error));
      }
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.followRedirects = false;
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(timeout ?? idleTimeout);
      } on TimeoutException {
        request.abort();
        throw const UpdateTransportException(
          'The server did not answer in time',
        );
      } on HandshakeException {
        throw const UpdateTransportException('TLS handshake failed');
      } on SocketException catch (error) {
        throw UpdateTransportException(_socketMessage(error));
      }
      if (!response.isRedirect) return response;
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null) {
        throw const UpdateTransportException('Redirect without a location');
      }
      current = current.resolve(location);
    }
    throw const UpdateTransportException('Too many redirects');
  }

  @override
  void close() => _client.close(force: true);

  static Map<String, String> _flattenHeaders(HttpHeaders headers) {
    final flat = <String, String>{};
    headers.forEach((name, values) => flat[name] = values.join(','));
    return flat;
  }

  /// A redirect or an error page has a body the caller will never read.
  /// Draining it keeps the connection reusable, but a server that never
  /// finishes it must not stall the update.
  Future<void> _drainQuietly(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(idleTimeout);
    } on Exception {
      // The response is discarded either way.
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A leftover partial file is harmless: the next attempt overwrites it.
    }
  }

  static String _socketMessage(SocketException error) {
    final host = error.address?.host;
    return host == null ? 'Network error' : 'Cannot reach $host';
  }
}
