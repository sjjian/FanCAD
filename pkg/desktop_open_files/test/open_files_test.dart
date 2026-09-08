import 'package:desktop_open_files/desktop_open_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('argv leftovers keep files and drop flags', () {
    expect(
      DesktopOpenFiles.fromArguments([
        '--enable-checked-mode',
        '',
        '  ',
        '--',
        r'C:\drawings\part.dwg',
        'file:///tmp/sheet.dxf',
        r'C:\drawings\part.dwg',
      ]),
      [r'C:\drawings\part.dwg', '/tmp/sheet.dxf'],
    );
    expect(DesktopOpenFiles.normalize('-NSDocumentRevisionsDebugMode'), isNull);
  });

  test('a leftover native queue is drained then later opens stream', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(openFilesChannelName);
    final queued = <String>['/tmp/first.dwg'];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'listen') return List<String>.from(queued);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final opens = DesktopOpenFiles(channel: channel);
    addTearDown(opens.dispose);

    expect(await opens.pending(), ['/tmp/first.dwg']);

    final later = expectLater(
      opens.incoming,
      emits(['/tmp/second.dxf', '/tmp/third.fcb']),
    );
    await messenger.handlePlatformMessage(
      openFilesChannelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('open', ['/tmp/second.dxf', '/tmp/third.fcb']),
      ),
      (_) {},
    );
    await later;
  });

  test('missing native host is an empty leftover queue', () async {
    final opens = DesktopOpenFiles(
      channel: const MethodChannel('desktop_open_files/missing'),
    );
    addTearDown(opens.dispose);
    expect(await opens.pending(), isEmpty);
  });
}
