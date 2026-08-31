import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';

import '../business/ai/skills/bundled.dart';
import 'workspace.dart';

/// Bind settings the MCP tab writes and the host reads.
class McpBind {
  const McpBind({
    required this.enabled,
    required this.port,
    required this.local,
    required this.allowlist,
  });

  final bool enabled;
  final int port;
  final bool local;
  final List<String> allowlist;

  String get bindHost => local ? '127.0.0.1' : InternetAddress.anyIPv4.address;

  /// Cursor on this machine always uses loopback; remote clients replace the host.
  String get advertisedHost => '127.0.0.1';
}

/// URL and token a Cursor MCP config should use.
class McpClientEndpoint {
  const McpClientEndpoint({required this.url, required this.token});

  final String url;
  final String token;

  String get clientConfig => fancadMcpClientConfig(url: url, token: token);
}

/// Listens on localhost and writes the lock file the MCP stdio proxy reads.
class FanCadOpsHost {
  FanCadOpsHost({
    required this.workspace,
    required this.lockPaths,
    this.port = defaultMcpPort,
    this.bindHost = '127.0.0.1',
    this.allowlist = const [],
    String? token,
  }) : token = token ?? randomMcpToken();

  final Workspace workspace;
  final List<String> lockPaths;
  final int port;
  final String bindHost;
  final List<String> allowlist;
  final String token;

  McpHttpServer? _server;

  String get url =>
      _server?.url ?? fancadMcpUrl(host: bindHost, port: port);

  OperationCatalog catalog() => OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: workspace.commands,
        execute: (id, args) => workspace.runHeadless(
          id,
          args: args,
          source: ChangeSource.mcp,
        ),
      ),
    )
    ..addProvider(
      HostOperationProvider(bundledHostTools(bundledSkillRegistry())),
    );

  Future<void> start() async {
    await stop();
    final dispatcher = OpsDispatcher(catalog());
    final session = McpSession(
      dispatch: (request) async {
        final intercepted = await _approve(dispatcher.catalog, request);
        return intercepted ?? await dispatcher.dispatch(request);
      },
    );
    final server = McpHttpServer(
      session: session,
      token: token,
      allowlist: allowlist,
    );
    _server = server;
    final bound = await server.start(host: bindHost, port: port);
    final lock = McpLock(
      port: bound,
      token: token,
      pid: pid,
    );
    for (final path in lockPaths) {
      await McpLock.write(path, lock);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
    for (final path in lockPaths) {
      await McpLock.remove(path);
    }
  }

  Future<Map<String, Object?>?> _approve(
    OperationCatalog catalog,
    OpsRequest request,
  ) async {
    if (request.action != OpsAction.run || !request.hasPath) return null;
    final operation = catalog.find(request.path);
    if (operation == null) return null;
    if (operation.risk != CommandRisk.destructive) return null;
    final allowed = await workspace.requestApprovalFor(
      'Allow ${operation.title}?',
      operation.description.isEmpty ? operation.id : operation.description,
      highlightIdsOf(request.args),
    );
    if (allowed) return null;
    return {
      'status': 'cancelled',
      'message': 'The user declined this change.',
    };
  }
}
