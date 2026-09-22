import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin.freezed.dart';

/// Extension file `plugins.edit` asked the built-in editor to open.
@freezed
abstract class PluginEditorTargetModel with _$PluginEditorTargetModel {
  const factory PluginEditorTargetModel({
    required String id,
    required String relative,
  }) = _PluginEditorTargetModel;
}

/// Store for the built-in extension editor.
@freezed
abstract class PluginEditorModel with _$PluginEditorModel {
  const factory PluginEditorModel({
    PluginEditorTargetModel? target,
    @Default(0) int request,
  }) = _PluginEditorModel;
}

/// One contributed command on a discovered extension.
@freezed
abstract class PluginCommandRefModel with _$PluginCommandRefModel {
  const factory PluginCommandRefModel({
    required String id,
    @Default('') String title,
  }) = _PluginCommandRefModel;
}

/// Snapshot of one installed extension. The pkg [PluginHost] stays on the
/// notifier; this is what the panel selects.
@freezed
abstract class PluginRefModel with _$PluginRefModel {
  const factory PluginRefModel({
    required String id,
    @Default('') String name,
    @Default('') String version,
    @Default('installed') String state,
    String? error,
    @Default('') String description,
    @Default('') String directory,
    @Default('main.js') String entryPoint,
    @Default([]) List<String> permissions,
    @Default([]) List<PluginCommandRefModel> commands,
    @Default([]) List<String> log,
  }) = _PluginRefModel;
}

/// Store for discovered extensions: the list and a tick for host changes.
///
/// Each extension's log lives on [PluginRefModel.log], copied from the host.
@freezed
abstract class PluginModel with _$PluginModel {
  const factory PluginModel({
    @Default(false) bool started,
    @Default('') String directory,
    @Default([]) List<PluginRefModel> plugins,
    @Default(0) int epoch,
  }) = _PluginModel;
}
