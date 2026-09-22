import 'package:freezed_annotation/freezed_annotation.dart';

part 'sidebar.freezed.dart';

/// Default and permitted width of the left sidebar.
abstract final class SidebarLayout {
  static const double defaultWidth = 240;
  static const double minWidth = 180;
  static const double maxWidth = 560;
}

/// Which sidebar view is showing, and whether the sidebar is open at all.
@freezed
abstract class SidebarModel with _$SidebarModel {
  const factory SidebarModel({
    @Default('layers') String viewId,
    @Default(true) bool isOpen,
    @Default(SidebarLayout.defaultWidth) double width,
  }) = _SidebarModel;
}
