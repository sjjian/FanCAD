import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin.freezed.dart';

/// Store for saved extensions: the folder and a tick for list changes.
@freezed
abstract class PluginModel with _$PluginModel {
  const factory PluginModel({
    @Default('') String directory,
    @Default(0) int epoch,
  }) = _PluginModel;
}
