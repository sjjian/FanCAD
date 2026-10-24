import 'package:freezed_annotation/freezed_annotation.dart';

part 'extension.freezed.dart';

/// Store for saved extensions: the folder and a tick for list changes.
@freezed
abstract class ExtensionModel with _$ExtensionModel {
  const factory ExtensionModel({
    @Default('') String directory,
    @Default(0) int epoch,
  }) = _ExtensionModel;
}
