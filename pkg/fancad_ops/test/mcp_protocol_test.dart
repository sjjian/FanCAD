import 'dart:convert';
import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
  test('tools/list advertises only fancad', () async {
    final session = McpSession(
      dispatch: (request) async => {'status': 'ok', 'echo': request.action.name},
    );
    final reply = await session.handle(
      const JsonRpcMessage(id: 1, method: 'tools/list'),
    );
    final result = asObjectMap(reply!.result);
    final tools = result['tools'] as List<Object?>;
    expect(tools, hasLength(1));
    expect((tools.single as Map)['name'], fancadToolName);
  });

  test('tools/call maps onto ops.dispatch', () async {
    OpsRequest? seen;
    final session = McpSession(
      dispatch: (request) async {
        seen = request;
        return {'status': 'ok', 'path': request.path};
      },
    );
    final reply = await session.handle(
      JsonRpcMessage(
        id: 2,
        method: 'tools/call',
        params: {
          'name': 'fancad',
          'arguments': {'action': 'help', 'path': 'draw'},
        },
      ),
    );
    expect(seen!.action, OpsAction.help);
    expect(seen!.path, 'draw');
    final result = asObjectMap(reply!.result);
    expect(result['isError'], isFalse);
    expect('${result['content']}', contains('draw'));
  });

  test('initialize and ping succeed; notifications stay silent', () async {
    final session = McpSession(dispatch: (_) async => {'status': 'ok'});
    final init = await session.handle(
      const JsonRpcMessage(id: 1, method: 'initialize'),
    );
    expect(asObjectMap(init!.result)['protocolVersion'], '2024-11-05');
    expect(
      await session.handle(
        const JsonRpcMessage(method: 'notifications/initialized'),
      ),
      isNull,
    );
    final ping = await session.handle(const JsonRpcMessage(id: 3, method: 'ping'));
    expect(ping!.result, isNotNull);
  });

  test('HTTP MCP serves tools/call at /mcp with a bearer token', () async {
    final catalog = OperationCatalog()
      ..register(
        Operation(
          id: 'query.summary',
          group: 'query',
          title: 'Summary',
          risk: CommandRisk.readOnly,
          execute: (_) async => {'status': 'ok', 'n': 1},
        ),
      );
    final session = McpSession(
      dispatch: OpsDispatcher(catalog).dispatch,
    );
    final server = McpHttpServer(session: session, token: 'secret');
    final port = await server.start();
    addTearDown(server.stop);
    expect(server.url, 'http://127.0.0.1:$port/mcp');

    await expectLater(
      postMcpJsonRpc(
        Uri.parse(server.url),
        token: 'wrong',
        message: const JsonRpcMessage(id: 1, method: 'ping'),
      ),
      throwsStateError,
    );

    final listed = await postMcpJsonRpc(
      Uri.parse(server.url),
      token: 'secret',
      message: const JsonRpcMessage(id: 1, method: 'tools/list'),
    );
    expect('${listed!.result}', contains(fancadToolName));

    final called = await postMcpJsonRpc(
      Uri.parse(server.url),
      token: 'secret',
      message: const JsonRpcMessage(
        id: 2,
        method: 'tools/call',
        params: {
          'name': 'fancad',
          'arguments': {'action': 'run', 'path': 'query.summary'},
        },
      ),
    );
    expect('${called!.result}', contains('"n": 1'));

    expect(
      await _postStatus(
        Uri.parse('http://127.0.0.1:$port/'),
        headers: {'Authorization': 'Bearer secret'},
      ),
      HttpStatus.notFound,
    );
    expect(
      await _postStatus(
        Uri.parse('http://127.0.0.1:$port/mcp?token=secret'),
      ),
      HttpStatus.unauthorized,
    );
  });

  test('allowlist rejects a foreign peer and still accepts loopback', () {
    expect(parseMcpAllowlist(' 10.0.0.2, 10.0.0.3\n10.0.0.4 '), [
      '10.0.0.2',
      '10.0.0.3',
      '10.0.0.4',
    ]);
    expect(mcpPeerAllowed('127.0.0.1', ['10.0.0.2']), isTrue);
    expect(mcpPeerAllowed('::1', ['10.0.0.2']), isTrue);
    expect(mcpPeerAllowed('10.0.0.2', ['10.0.0.2']), isTrue);
    expect(mcpPeerAllowed('::ffff:10.0.0.2', ['10.0.0.2']), isTrue);
    expect(mcpPeerAllowed('10.0.0.9', ['10.0.0.2']), isFalse);
    expect(mcpPeerAllowed('10.0.0.9', const []), isTrue);
    expect(parseMcpPort('65536'), defaultMcpPort);
    expect(parseMcpPort('19001'), 19001);
  });
}

Future<int> _postStatus(
  Uri url, {
  Map<String, String> headers = const {},
}) async {
  const body = '{"jsonrpc":"2.0","id":1,"method":"ping"}';
  final bytes = utf8.encode(body);
  final path = url.hasQuery ? '${url.path}?${url.query}' : url.path;
  final socket = await Socket.connect(url.host, url.port);
  try {
    final extra = [
      for (final entry in headers.entries) '${entry.key}: ${entry.value}\r\n',
    ].join();
    socket.write(
      'POST $path HTTP/1.1\r\n'
      'Host: ${url.host}:${url.port}\r\n'
      '$extra'
      'Content-Type: application/json\r\n'
      'Content-Length: ${bytes.length}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    socket.add(bytes);
    await socket.flush();
    final raw = await utf8.decoder.bind(socket).join();
    final parts = raw.split('\r\n').first.split(' ');
    return parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  } finally {
    await socket.close();
  }
}
