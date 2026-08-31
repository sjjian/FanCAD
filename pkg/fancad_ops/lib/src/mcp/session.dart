import 'dart:convert';

import '../json.dart';
import '../request.dart';
import '../rpc.dart';
import '../tool.dart';

/// MCP tools-only session. Transport-agnostic so tests do not open stdio.
class McpSession {
  McpSession({required this.dispatch});

  final Future<Map<String, Object?>> Function(OpsRequest request) dispatch;

  /// Returns a JSON-RPC response, or null for a notification.
  Future<JsonRpcMessage?> handle(JsonRpcMessage message) async {
    final method = message.method;
    if (method == null) return null;
    if (message.isNotification) {
      return null;
    }
    switch (method) {
      case 'initialize':
        return JsonRpcMessage.resultOf(message.id, {
          'protocolVersion': '2024-11-05',
          'capabilities': {
            'tools': <String, Object?>{},
          },
          'serverInfo': {
            'name': 'fancad',
            'version': '0.1.0',
          },
        });
      case 'ping':
        return JsonRpcMessage.resultOf(message.id, const {});
      case 'tools/list':
        return JsonRpcMessage.resultOf(message.id, {
          'tools': [fancadMcpTool()],
        });
      case 'tools/call':
        return JsonRpcMessage.resultOf(message.id, await _call(message.params));
      default:
        return JsonRpcMessage.errorOf(
          message.id,
          code: -32601,
          message: 'Unknown method: $method',
        );
    }
  }

  Future<Map<String, Object?>> _call(Map<String, Object?>? params) async {
    final name = '${params?['name'] ?? ''}';
    if (name.isNotEmpty && name != fancadToolName) {
      return {
        'content': [
          {'type': 'text', 'text': 'Unknown tool: $name. Use $fancadToolName.'},
        ],
        'isError': true,
      };
    }
    final raw = asObjectMap(params?['arguments']);
    final request = OpsRequest.tryParse(raw);
    if (request == null) {
      return {
        'content': [
          {
            'type': 'text',
            'text':
                'fancad requires action=list|help|schema|run. '
                'Call help with no path to see groups.',
          },
        ],
        'isError': true,
      };
    }
    try {
      final payload = await dispatch(request);
      final failed = payload['status'] == 'failed';
      return {
        'content': [
          {
            'type': 'text',
            'text': const JsonEncoder.withIndent('  ').convert(payload),
          },
        ],
        'isError': failed,
      };
    } catch (error) {
      return {
        'content': [
          {'type': 'text', 'text': '$error'},
        ],
        'isError': true,
      };
    }
  }
}
