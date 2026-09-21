import 'package:fancad_ops/fancad_ops.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp.freezed.dart';

/// Application-layer store of MCP bind settings.
@freezed
abstract class McpModel with _$McpModel {
  const McpModel._();

  const factory McpModel({
    required McpBindModel bind,
    @Default('') String token,
  }) = _McpModel;

  McpClientEndpointModel get endpoint => McpClientEndpointModel(
    url: fancadMcpUrl(host: bind.advertisedHost, port: bind.port),
    token: token,
  );
}

/// Bind settings the MCP tab writes and the host reads.
@freezed
abstract class McpBindModel with _$McpBindModel {
  const McpBindModel._();

  const factory McpBindModel({
    required bool enabled,
    required int port,
    required bool local,
    required List<String> allowlist,
  }) = _McpBindModel;

  String get bindHost => local ? '127.0.0.1' : '0.0.0.0';

  /// Cursor on this machine always uses loopback; remote clients replace the host.
  String get advertisedHost => '127.0.0.1';
}

/// URL and token a Cursor MCP config should use.
@freezed
abstract class McpClientEndpointModel with _$McpClientEndpointModel {
  const McpClientEndpointModel._();

  const factory McpClientEndpointModel({
    required String url,
    required String token,
  }) = _McpClientEndpointModel;

  String get clientConfig => fancadMcpClientConfig(url: url, token: token);
}
