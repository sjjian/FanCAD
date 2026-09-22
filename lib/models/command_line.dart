import 'package:freezed_annotation/freezed_annotation.dart';

part 'command_line.freezed.dart';

/// Heights of the command-line pane.
///
/// Collapse is the splitter plus the input row. History is given no pixels,
/// so a stored height below that still looks like a single command line.
abstract final class CommandLineLayout {
  /// Hit area for pane splitters. Wider than the 1px rule so it can be grabbed.
  static const double splitterHit = 7;

  static const double commandLineHeight = 24;

  /// Splitter plus the input row. History is given no pixels, so collapse
  /// looks like a single command line rather than a half-empty console.
  static const double collapsedHeight = splitterHit + commandLineHeight;

  /// Input plus two or three history lines — enough to read a prompt.
  static const double defaultHeight = 84;

  /// Tall enough to reread an import warning, short enough to keep the canvas.
  static const double expandedHeight = 200;

  static const double minHeight = collapsedHeight;
  static const double maxHeight = 420;
}

/// Height of the command line pane, and whether the history is expanded.
@freezed
abstract class CommandPaneModel with _$CommandPaneModel {
  const factory CommandPaneModel({
    @Default(CommandLineLayout.defaultHeight) double height,
    @Default(false) bool isExpanded,
  }) = _CommandPaneModel;
}

/// The command line pane: history plus the in-flight typed prompt, if any.
///
/// [pane] and [paletteOpen] are the layout of this pane. The palette is not
/// written to settings; it only lasts for the session.
@freezed
abstract class CommandLineModel with _$CommandLineModel {
  const factory CommandLineModel({
    @Default([]) List<HistoryLineModel> lines,
    CommandPromptModel? prompt,
    @Default('') String status,
    String? offeredInput,
    @Default([]) List<String> entered,
    @Default(CommandPaneModel()) CommandPaneModel pane,
    @Default(false) bool paletteOpen,
  }) = _CommandLineModel;
}

/// The severity of a command-history line, which decides its colour.
enum HistoryLevel { normal, prompt, success, warning, error }

/// One line in the command history pane.
@freezed
abstract class HistoryLineModel with _$HistoryLineModel {
  const factory HistoryLineModel(
    String text, {
    @Default(HistoryLevel.normal) HistoryLevel level,
  }) = _HistoryLineModel;
}

/// What the command line shows while a verb waits for a typed value.
@freezed
abstract class CommandPromptModel with _$CommandPromptModel {
  const factory CommandPromptModel({
    required String message,
    @Default([]) List<String> keywords,
    @Default(false) bool allowEmpty,
  }) = _CommandPromptModel;
}
