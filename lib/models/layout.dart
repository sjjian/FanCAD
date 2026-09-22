import 'package:freezed_annotation/freezed_annotation.dart';

import 'assistant.dart';
import 'command_line.dart';
import 'sidebar.dart';

part 'layout.freezed.dart';

/// Workbench chrome: which panes are open, which sidebar view is showing,
/// and the three pane sizes.
///
/// This is state, not appearance or drafting settings.
@freezed
abstract class LayoutModel with _$LayoutModel {
  const factory LayoutModel({
    @Default('layers') String sidebarView,
    @Default(true) bool sidebarOpen,
    @Default(false) bool assistantOpen,
    @Default(SidebarLayout.defaultWidth) double sidebarWidth,
    @Default(AssistantPaneLayout.defaultWidth) double assistantWidth,
    @Default(CommandLineLayout.defaultHeight) double commandHeight,
  }) = _LayoutModel;
}
