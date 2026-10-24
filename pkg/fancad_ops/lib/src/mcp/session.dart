import 'dart:convert';

import '../encode.dart';
import '../json.dart';
import '../request.dart';
import '../rpc.dart';
import '../tool.dart';

/// One CLI tool on an MCP session. Each tool has its own catalog.
class McpCliTool {
  const McpCliTool({
    required this.name,
    required this.description,
    required this.parameters,
    required this.dispatch,
  });

  final String name;
  final String description;
  final Map<String, Object?> parameters;
  final Future<Map<String, Object?>> Function(OpsRequest request) dispatch;

  Map<String, Object?> definition() => {
    'name': name,
    'description': description,
    'inputSchema': parameters,
  };

  /// The drawing CLI, used when a session advertises only [fancadToolName].
  static McpCliTool fancad(
    Future<Map<String, Object?>> Function(OpsRequest request) dispatch,
  ) => McpCliTool(
    name: fancadToolName,
    description: fancadToolDescription,
    parameters: fancadToolParameters,
    dispatch: dispatch,
  );
}

/// MCP tools-only session. Transport-agnostic so tests do not open stdio.
class McpSession {
  /// Advertises only the drawing CLI. The app passes [McpSession.tools] when
  /// the script CLI is available too.
  McpSession({
    required Future<Map<String, Object?>> Function(OpsRequest request) dispatch,
  }) : tools = [McpCliTool.fancad(dispatch)];

  McpSession.tools(this.tools);

  final List<McpCliTool> tools;

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
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': {'name': 'fancad', 'version': '0.1.0'},
        });
      case 'ping':
        return JsonRpcMessage.resultOf(message.id, const {});
      case 'tools/list':
        return JsonRpcMessage.resultOf(message.id, {
          'tools': [for (final tool in tools) tool.definition()],
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
    final tool = _toolNamed(name);
    if (tool == null) {
      final known = tools.map((each) => each.name).join(' or ');
      return {
        'content': [
          {'type': 'text', 'text': 'Unknown tool: $name. Use $known.'},
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
                '${tool.name} requires action=list|help|schema|run. '
                'Call help with no path to see groups.',
          },
        ],
        'isError': true,
      };
    }
    try {
      final payload = await tool.dispatch(request);
      final image = takeCommandImage(payload);
      final failed = image.payload['status'] == 'failed';
      final text = const JsonEncoder.withIndent('  ').convert(image.payload);
      final bytes = image.bytes;
      return {
        'content': [
          {'type': 'text', 'text': text},
          if (bytes != null)
            {
              'type': 'image',
              'data': base64Encode(bytes),
              'mimeType': image.mime ?? 'image/png',
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

  McpCliTool? _toolNamed(String name) {
    if (name.isEmpty) return tools.length == 1 ? tools.single : null;
    for (final tool in tools) {
      if (tool.name == name) return tool;
    }
    return null;
  }
}
