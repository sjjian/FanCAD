import 'dart:async';
import 'dart:io';

import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late IoHttpTransport transport;
  late Directory temp;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = IoHttpTransport(
      allowInsecure: true,
      idleTimeout: const Duration(seconds: 5),
      connectTimeout: const Duration(seconds: 2),
    );
    temp = await Directory.systemTemp.createTemp('fancad-transport-test');
  });

  tearDown(() async {
    transport.close();
    await server.close(force: true);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Uri serve(void Function(HttpRequest request) handler) {
    server.listen(handler);
    return Uri.parse('http://127.0.0.1:${server.port}');
  }

  test('reads a response body and headers', () async {
    final base = serve((request) {
      request.response.headers.set('x-test', 'yes');
      request.response.write('{"ok":true}');
      unawaited(request.response.close());
    });

    final response = await transport.get(base.resolve('/release'));

    expect(response.statusCode, 200);
    expect(response.isSuccess, isTrue);
    expect(response.text, '{"ok":true}');
    expect(response.headers['x-test'], 'yes');
  });

  test('follows a redirect', () async {
    final base = serve((request) {
      if (request.uri.path == '/old') {
        unawaited(request.response.redirect(Uri.parse('/new')));
        return;
      }
      request.response.write('moved');
      unawaited(request.response.close());
    });

    final response = await transport.get(base.resolve('/old'));

    expect(response.statusCode, 200);
    expect(response.text, 'moved');
  });

  test('refuses plain HTTP when insecure mode is off', () async {
    final strict = IoHttpTransport();
    addTearDown(strict.close);
    expect(
      strict.get(Uri.parse('http://127.0.0.1:1/release')),
      throwsA(isA<UpdateTransportException>()),
    );
  });

  test('caps the response size', () async {
    final base = serve((request) {
      request.response.write('x' * 100);
      unawaited(request.response.close());
    });
    final small = IoHttpTransport(
      allowInsecure: true,
      maxResponseBytes: 8,
      idleTimeout: const Duration(seconds: 5),
    );
    addTearDown(small.close);

    expect(
      small.get(base.resolve('/big')),
      throwsA(isA<UpdateTransportException>()),
    );
  });

  test('streams a download to disk with progress', () async {
    final bytes = List<int>.generate(4096, (index) => index % 256);
    final base = serve((request) {
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      unawaited(request.response.close());
    });
    final destination = File('${temp.path}/installer.dmg');
    final progress = <int>[];

    final written = await transport.download(
      base.resolve('/asset'),
      destination: destination,
      onProgress: (received, total) => progress.add(received),
    );

    expect(written, bytes.length);
    expect(await destination.readAsBytes(), bytes);
    expect(progress.last, bytes.length);
  });

  test('reports a refused connection as a transport error', () async {
    expect(
      transport.get(Uri.parse('http://127.0.0.1:1/release')),
      throwsA(isA<UpdateTransportException>()),
    );
  });
}
