import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
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
