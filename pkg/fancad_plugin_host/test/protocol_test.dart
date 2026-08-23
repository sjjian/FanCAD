import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RpcRequest', () {
    test('a request round-trips and a notification omits the id', () {
      const request = RpcRequest(
        method: WorkerMethod.invoke,
        params: {'pluginId': 'demo'},
        id: 7,
      );
      final again = RpcRequest.fromJson(request.toJson());
      expect(again.method, WorkerMethod.invoke);
      expect(again.params, {'pluginId': 'demo'});
      expect(again.id, 7);
      expect(again.isNotification, isFalse);

      const note = RpcRequest.notification(WorkerMethod.event, {'a': 1});
      final encoded = note.toJson();
      expect(encoded.containsKey('id'), isFalse);
      expect(RpcRequest.fromJson(encoded).isNotification, isTrue);
    });

    test('a missing method is an invalid request, not a silent no-op', () {
      expect(
        () => RpcRequest.fromJson(const {'id': 1}),
        throwsA(
          isA<RpcException>()
              .having(
                (error) => error.code,
                'code',
                RpcErrorCode.invalidRequest,
              )
              .having((error) => error.message, 'message', contains('method')),
        ),
      );
    });

    test('non-object params become an empty map rather than throwing', () {
      final request = RpcRequest.fromJson(const {
        'method': 'plugin/ping',
        'params': 'nope',
      });
      expect(request.params, isEmpty);
    });
  });

  group('RpcResponse', () {
    test('success and failure survive a JSON hop', () {
      const ok = RpcResponse.success(3, {'value': 1});
      final okAgain = RpcResponse.fromJson(ok.toJson());
      expect(okAgain.isError, isFalse);
      expect(okAgain.id, 3);
      expect(okAgain.result, {'value': 1});

      const fail = RpcResponse.failure(
        4,
        RpcError(RpcErrorCode.pluginError, 'boom', data: {'stack': 'x'}),
      );
      final failAgain = RpcResponse.fromJson(fail.toJson());
      expect(failAgain.isError, isTrue);
      expect(failAgain.error!.code, RpcErrorCode.pluginError);
      expect(failAgain.error!.message, 'boom');
      expect(failAgain.error!.data, {'stack': 'x'});
    });

    test(
      'a missing id becomes -1 so a late reply cannot hit another request',
      () {
        final response = RpcResponse.fromJson(const {'result': true});
        expect(response.id, -1);
        expect(response.result, isTrue);
      },
    );
  });

  group('RpcError', () {
    test('a truncated payload falls back instead of throwing', () {
      final error = RpcError.fromJson(const {});
      expect(error.code, RpcErrorCode.internalError);
      expect(error.message, 'Unknown error');
      expect(error.toString(), contains('Unknown error'));
    });

    test('an RpcException keeps its code when turned into a payload', () {
      const thrown = RpcException(
        RpcErrorCode.permissionDenied,
        'no write',
        data: 'document.write',
      );
      expect(thrown.toError().code, RpcErrorCode.permissionDenied);
      expect(thrown.toString(), contains('no write'));
    });
  });
}
