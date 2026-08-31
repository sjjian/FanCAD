import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lock.dart';
import '../rpc.dart';
import 'session.dart';

/// Splits a typed allowlist into IPs. Empty means no extra filter.
List<String> parseMcpAllowlist(String raw) {
  return [
    for (final part in raw.split(RegExp(r'[\s,;]+')))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

/// Loopback always passes so a same-machine Cursor still works.
bool mcpPeerAllowed(String peer, List<String> allowlist) {
  final addr = normalizeMcpIp(peer);
  if (addr == '127.0.0.1' || addr == '::1' || addr == 'localhost') {
    return true;
  }
  if (allowlist.isEmpty) return true;
  return allowlist.any((entry) => normalizeMcpIp(entry) == addr);
}

String normalizeMcpIp(String raw) {
  var ip = raw.trim();
  if (ip.startsWith('::ffff:')) ip = ip.substring(7);
  return ip;
}

int parseMcpPort(String raw, {int fallback = defaultMcpPort}) {
  final n = int.tryParse(raw.trim());
  if (n == null || n < 1 || n > 65535) return fallback;
  return n;
}

/// Streamable HTTP MCP. Cursor and Claude connect with a URL, not a command.
class McpHttpServer {
  McpHttpServer({
    required this.session,
    required this.token,
    this.allowlist = const [],
  });

  final McpSession session;
  final String token;
  final List<String> allowlist;

  HttpServer? _server;

  int get port => _server?.port ?? 0;

  String get host => _server?.address.address ?? '127.0.0.1';

  String get url => fancadMcpUrl(host: host, port: port);

  Future<int> start({String host = '127.0.0.1', int port = 0}) async {
    await stop();
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen(_accept);
    return server.port;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  void _accept(HttpRequest request) {
    unawaited(_handle(request));
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      _cors(response);
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        return;
      }
      if (!_peerAllowed(request)) {
        _writePlain(response, HttpStatus.forbidden, 'Forbidden');
        return;
      }
      if (!_isMcpPath(request.uri.path)) {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      if (!_authorized(request)) {
        _writePlain(response, HttpStatus.unauthorized, 'Unauthorized');
        return;
      }
      if (request.method == 'POST') {
        await _post(request);
        return;
      }
      response.statusCode = HttpStatus.methodNotAllowed;
    } catch (error) {
      _writePlain(response, HttpStatus.internalServerError, '$error');
    } finally {
      await response.close();
    }
  }

  Future<void> _post(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      _writePlain(request.response, HttpStatus.badRequest, 'Invalid JSON');
      return;
    }
    final message = JsonRpcMessage.parse(decoded);
    if (message == null) {
      _writePlain(request.response, HttpStatus.badRequest, 'Invalid JSON-RPC');
      return;
    }
    final reply = await session.handle(message);
    if (reply == null) {
      request.response.statusCode = HttpStatus.accepted;
      request.response.headers.contentLength = 0;
      return;
    }
    final encoded = reply.encode();
    final bytes = utf8.encode(encoded);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.contentLength = bytes.length;
    request.response.add(bytes);
  }

  static void _writePlain(HttpResponse response, int status, String text) {
    final bytes = utf8.encode(text);
    response.statusCode = status;
    response.headers.contentType = ContentType.text;
    response.headers.contentLength = bytes.length;
    response.add(bytes);
  }

  bool _peerAllowed(HttpRequest request) {
    final peer = request.connectionInfo?.remoteAddress.address ?? '';
    return mcpPeerAllowed(peer, allowlist);
  }

  bool _authorized(HttpRequest request) {
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    return header == 'Bearer $token';
  }

  static bool _isMcpPath(String path) => path == '/mcp';

  static void _cors(HttpResponse response) {
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set(
        'Access-Control-Allow-Headers',
        'Authorization, Content-Type, Mcp-Session-Id, MCP-Protocol-Version',
      )
      ..set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  }
}

/// POST one MCP JSON-RPC message to [url].
///
/// Speaks HTTP/1.1 over a [Socket] so Flutter's test [HttpClient] mock
/// cannot swallow the request.
Future<JsonRpcMessage?> postMcpJsonRpc(
  Uri url, {
  required String token,
  required JsonRpcMessage message,
}) async {
  final body = message.encode();
  final bytes = utf8.encode(body);
  final path = url.hasQuery
      ? '${url.path}?${url.query}'
      : (url.path.isEmpty ? '/' : url.path);
  final socket = await Socket.connect(url.host, url.port);
  try {
    socket.write(
      'POST $path HTTP/1.1\r\n'
      'Host: ${url.host}:${url.port}\r\n'
      'Authorization: Bearer $token\r\n'
      'Content-Type: application/json\r\n'
      'Accept: application/json\r\n'
      'Content-Length: ${bytes.length}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    socket.add(bytes);
    await socket.flush();
    final raw = await utf8.decoder.bind(socket).join();
    final split = raw.indexOf('\r\n\r\n');
    if (split < 0) throw StateError('Invalid HTTP response');
    final header = raw.substring(0, split);
    final payload = raw.substring(split + 4);
    final status = _httpStatus(header);
    if (status == HttpStatus.accepted) return null;
    if (status >= 400) {
      throw StateError(
        payload.trim().isEmpty ? 'HTTP $status' : payload.trim(),
      );
    }
    if (payload.trim().isEmpty) return null;
    return JsonRpcMessage.parse(jsonDecode(payload));
  } finally {
    await socket.close();
  }
}

int _httpStatus(String header) {
  final parts = header.split('\r\n').first.split(' ');
  return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
}
