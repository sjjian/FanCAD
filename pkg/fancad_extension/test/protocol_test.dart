import 'package:fancad_extension/fancad_extension.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher invalid(String message) => isA<RpcException>()
      .having((error) => error.code, 'code', RpcErrorCode.invalidRequest)
      .having((error) => error.message, 'message', contains(message));

  test('a malformed request is invalidRequest, not a cast error', () {
    expect(
      () => RpcRequest.fromJson(const {'method': 'm', 'id': 'one'}),
      throwsA(invalid('"id"')),
    );
    expect(
      () => RpcRequest.fromJson(const {'method': 'm', 'params': 3}),
      throwsA(invalid('"params"')),
    );
    expect(
      () => RpcRequest.fromJson(const {'id': 1}),
      throwsA(invalid('"method"')),
    );

    final request = RpcRequest.fromJson({
      'method': 'm',
      'id': 2,
      'params': <Object?, Object?>{'a': 1},
    });
    expect(request.params, {'a': 1});
    expect(request.id, 2);
  });

  test('the peer answers a bad request and ignores a bad response', () async {
    final sent = <Map<String, Object?>>[];
    final peer = RpcPeer(send: sent.add, handle: (_) async => null);

    await peer.accept(const {'method': 'm', 'id': 7, 'params': 'x'});
    expect(sent.single['id'], 7);
    expect((sent.single['error']! as Map)['code'], RpcErrorCode.invalidRequest);

    await peer.accept(const {'method': 'm', 'id': 'seven'});
    expect(sent, hasLength(1));

    await peer.accept(const {
      'id': 'x',
      'error': {'code': 'bad', 'message': 3},
    });
    expect(peer.pendingCount, 0);
  });
}
