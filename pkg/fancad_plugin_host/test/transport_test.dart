import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a closed local transport refuses requests and ignores notifies',
    () async {
      final transport = LocalTransport();
      expect(transport.isAlive, isFalse);
      await expectLater(
        transport.request(WorkerMethod.ping),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.workerDead)
              .having((error) => error.message, 'message', contains('closed')),
        ),
      );
      transport.notify(WorkerMethod.event);
    },
  );

  test('start answers ping and dispose stops further work', () async {
    final transport = LocalTransport();
    await transport.start((pluginId, method, params) async => null);
    addTearDown(transport.dispose);

    expect(transport.isAlive, isTrue);
    final pong = await transport.request(WorkerMethod.ping);
    expect(pong, {'loaded': <String>[]});

    await transport.dispose();
    expect(transport.isAlive, isFalse);
    await expectLater(
      transport.request(WorkerMethod.ping),
      throwsA(isA<RpcException>()),
    );
    await transport.dispose();
  });

  test('an immediate dispose skips asking the runtime to unload', () async {
    final transport = LocalTransport();
    await transport.start((pluginId, method, params) async => null);
    await transport.dispose(immediate: true);
    expect(transport.isAlive, isFalse);
    await expectLater(
      transport.request(WorkerMethod.stats),
      throwsA(isA<RpcException>()),
    );
  });
}
