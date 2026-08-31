import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ops host lock lets a client list and run on the open drawing', () async {
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(SettingsStore.inMemory()),
    );
    addTearDown(workspace.dispose);
    workspace.newDocument(title: 'MCP');
    registerBuiltinCommands(
      workspace.commands,
      fileCommands: FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: ({bool force = false}) => false,
        saveActive: (_) async => null,
        recentFiles: () => const <String>[],
      ),
    );

    final dir = Directory.systemTemp.createTempSync('fancad-mcp');
    addTearDown(() => dir.deleteSync(recursive: true));
    final lockPath = '${dir.path}${Platform.pathSeparator}mcp.lock';
    final host = FanCadOpsHost(
      workspace: workspace,
      lockPaths: [lockPath],
      port: 0,
    );
    await host.start();
    addTearDown(host.stop);

    final lock = McpLock.readSync(lockPath);
    expect(lock, isNotNull);
    expect(lock!.token, isNotEmpty);
    expect(lock.url, host.url);

    final listed = await postMcpJsonRpc(
      lock.mcpUri,
      token: lock.token,
      message: const JsonRpcMessage(
        id: 1,
        method: 'tools/call',
        params: {
          'name': 'fancad',
          'arguments': {'action': 'help'},
        },
      ),
    );
    expect('${listed!.result}', contains('draw'));

    final drawn = await postMcpJsonRpc(
      lock.mcpUri,
      token: lock.token,
      message: const JsonRpcMessage(
        id: 2,
        method: 'tools/call',
        params: {
          'name': 'fancad',
          'arguments': {
            'action': 'run',
            'path': 'draw.line',
            'args': {
              'start': [0, 0],
              'end': [8, 0],
            },
          },
        },
      ),
    );
    expect('${drawn!.result}', contains('ok'));
    expect(workspace.active!.document.entityCount, 1);
  });

  test('mcp settings default on, local, and can be turned off', () {
    final store = SettingsStore.inMemory();
    final settings = McpSettings(store);
    expect(settings.enabled, isTrue);
    expect(settings.local, isTrue);
    expect(settings.port, defaultMcpPort);
    expect(settings.allowlist, isEmpty);
    settings.setEnabled(false);
    settings.setLocal(false);
    settings.setPort(19000);
    settings.setAllowlist(['10.0.0.2']);
    expect(settings.enabled, isFalse);
    expect(settings.local, isFalse);
    expect(settings.port, 19000);
    expect(settings.allowlist, ['10.0.0.2']);
    expect(store.getBool(SettingsKeys.mcpEnabled), isFalse);

    final leftover = McpSettings(
      SettingsStore.inMemory({SettingsKeys.mcpAllowlist: '8.8.8.8 1.1.1.1'}),
    );
    expect(leftover.allowlist, ['8.8.8.8', '1.1.1.1']);
  });

  test('MCP client config is a URL, not a spawn command', () {
    expect(fancadMcpUrl(), 'http://127.0.0.1:17830/mcp');
    final config = fancadMcpClientConfig(
      url: fancadMcpUrl(),
      token: 'secret',
    );
    expect(config, contains('"url": "http://127.0.0.1:17830/mcp"'));
    expect(config, contains('Bearer secret'));
    expect(config, isNot(contains('dart run')));
  });
}
