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
}
