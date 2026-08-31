import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'json.dart';

/// Localhost port the settings dialog advertises and the host binds.
const defaultMcpPort = 17830;

/// HTTP MCP URL a Cursor client pastes into `mcp.json`.
String fancadMcpUrl({String host = '127.0.0.1', int port = defaultMcpPort}) =>
    'http://$host:$port/mcp';

/// Cursor / Claude Desktop remote MCP snippet.
String fancadMcpClientConfig({required String url, required String token}) {
  return const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'fancad': {
        'url': url,
        'headers': {'Authorization': 'Bearer $token'},
      },
    },
  });
}

/// How the stdio proxy finds a running FanCAD.
class McpLock {
  const McpLock({
    required this.port,
    required this.token,
    required this.pid,
    this.host = '127.0.0.1',
  });

  final String host;
  final int port;
  final String token;
  final int pid;

  String get url => fancadMcpUrl(host: host, port: port);

  Uri get mcpUri => Uri.parse(url);

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'token': token,
    'pid': pid,
    'url': fancadMcpUrl(host: host, port: port),
  };

  static McpLock? parse(Object? raw) {
    final map = asObjectMap(raw);
    final port = map['port'];
    final token = '${map['token'] ?? ''}';
    final pid = map['pid'];
    if (port is! num || token.isEmpty || pid is! num) return null;
    final host = '${map['host'] ?? '127.0.0.1'}';
    return McpLock(
      host: host.isEmpty ? '127.0.0.1' : host,
      port: port.toInt(),
      token: token,
      pid: pid.toInt(),
    );
  }

  static Future<void> write(String path, McpLock lock) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(lock.toJson())}\n');
  }

  static Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static McpLock? readSync(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return parse(jsonDecode(file.readAsStringSync()));
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}

/// `FANCAD_MCP_LOCK` wins; otherwise a well-known user-profile path.
String defaultMcpLockPath() {
  final override = Platform.environment['FANCAD_MCP_LOCK'];
  if (override != null && override.trim().isNotEmpty) return override.trim();
  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return '$appData${Platform.pathSeparator}fancad${Platform.pathSeparator}mcp.lock';
    }
  }
  final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
  return '$home/.fancad/mcp.lock';
}

String randomMcpToken() {
  final rng = Random.secure();
  final bytes = List<int>.generate(24, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes);
}
