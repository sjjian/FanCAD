import 'dart:io';

import 'package:fancad/fancad.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:fancad_test/fancad_test.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ops host lock lets a client list and run on the open drawing', () async {
    final app = Headless(
      files: (workspace) => FileCommands(
        openFile: (_) async => false,
        newDocument: workspace.newDocument,
        closeActive: (session, {bool force = false}) => false,
        saveActive: (session, _) async => null,
        recentFiles: () => const <String>[],
      ),
    );
    final workspace = app.workspace;

    final dir = tempDir(prefix: 'fancad-mcp');
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
}
