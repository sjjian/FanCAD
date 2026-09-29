import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';

/// Application-layer shape of the tabbed canvas workspace.
@freezed
abstract class WorkspaceModel with _$WorkspaceModel {
  const WorkspaceModel._();

  const factory WorkspaceModel({
    @Default([]) List<WorkspaceSessionModel> sessions,
    @Default(-1) int activeIndex,
    @Default([]) List<NoticeModel> notices,
    ApprovalRequestModel? approval,
    @Default(false) bool assistantBusy,
    String? runningCommand,
    @Default(true) bool snapEnabled,
    @Default(false) bool ortho,
    @Default(true) bool polar,
    @Default([]) List<String> snapModes,
    @Default([]) List<String> recentFiles,

    /// Last geometry the human or the assistant created or changed.
    @Default([]) List<int> lastCreatedIds,
    @Default([]) List<int> lastModifiedIds,
    @Default(0) int collectedPointCount,
  }) = _WorkspaceModel;

  /// Open drawing sessions, skipping start pages.
  List<String> get sessionIds => [
    for (final session in sessions)
      if (!session.isStartPage) session.id,
  ];

  WorkspaceSessionModel? get active =>
      activeIndex >= 0 && activeIndex < sessions.length
      ? sessions[activeIndex]
      : null;

  String? get activeSessionId {
    final session = active;
    if (session == null || session.isStartPage) return null;
    return session.id;
  }

  /// Tab strip: ids / title / dirty, not hover or flash.
  WorkspaceSessionsModel get tabStrip => WorkspaceSessionsModel(
    sessions: [
      for (final session in sessions)
        WorkspaceTabRefModel(
          id: session.id,
          isStartPage: session.isStartPage,
          title: session.title,
          isDirty: session.isDirty,
          diagnosticCount: session.diagnostics.length,
        ),
    ],
    activeIndex: activeIndex,
  );

  /// Entities the canvas should highlight while an approval is pending.
  ///
  /// Approval ids stay on [approval]. Held / flash / hover live on the active
  /// session.
  List<int> get highlightIds => [
    ...?approval?.highlightIds,
    ...?active?.heldIds,
    ...?active?.flashIds,
    ...?active?.hoverIds,
  ];

  /// Open export pane for [id]. A closed pane keeps its choices on the
  /// session, and the canvas only follows a pane that is open.
  ExportStateModel? openExportOf(String id) {
    for (final session in sessions) {
      if (session.id != id) continue;
      final export = session.export;
      return export.open ? export : null;
    }
    return null;
  }
}

/// Tab-strip slice: which sessions are open and the chrome the strip paints.
///
/// Hover / flash / held stay off this type so a canvas highlight does not
/// rebuild the strip.
@freezed
abstract class WorkspaceSessionsModel with _$WorkspaceSessionsModel {
  const factory WorkspaceSessionsModel({
    @Default([]) List<WorkspaceTabRefModel> sessions,
    @Default(-1) int activeIndex,
  }) = _WorkspaceSessionsModel;
}

/// One tab in the strip. Hover and flash stay on [WorkspaceSessionModel].
@freezed
abstract class WorkspaceTabRefModel with _$WorkspaceTabRefModel {
  const factory WorkspaceTabRefModel({
    required String id,
    @Default(false) bool isStartPage,
    @Default('') String title,
    @Default(false) bool isDirty,
    @Default(0) int diagnosticCount,
  }) = _WorkspaceTabRefModel;
}

/// One open canvas session in the workspace, not a tab-strip DTO.
///
/// [title] and [isDirty] are mirrored from the drawing session so the tab-strip
/// slice can change when a drawing is saved or dirtied, without listening to
/// the tab (which also fires on pan).
@freezed
abstract class WorkspaceSessionModel with _$WorkspaceSessionModel {
  const factory WorkspaceSessionModel({
    required String id,
    @Default(false) bool isStartPage,
    @Default('') String title,
    @Default(false) bool isDirty,
    @Default(true) bool showGrid,
    Set<String>? isolatedLayers,
    @Default([]) List<String> diagnostics,
    @Default([]) List<int> heldIds,
    @Default([]) List<int> flashIds,
    @Default([]) List<int> hoverIds,

    /// Format, scope, and region for this drawing. Not shared, not persisted.
    @Default(ExportStateModel()) ExportStateModel export,
  }) = _WorkspaceSessionModel;
}

/// A toast-style notification.
@freezed
abstract class NoticeModel with _$NoticeModel {
  const factory NoticeModel(
    String message, {
    @Default(false) bool isError,
    required DateTime at,
  }) = _NoticeModel;
}

/// File encoding for one export. The picture is the same for every value.
enum ExportFormat {
  svg,
  pdf,
  png,
  jpg;

  static ExportFormat? tryParse(String raw) =>
      switch (raw.trim().toLowerCase()) {
        'svg' => svg,
        'pdf' => pdf,
        'png' => png,
        'jpg' || 'jpeg' => jpg,
        _ => null,
      };

  String get extension => switch (this) {
    svg => 'svg',
    pdf => 'pdf',
    png => 'png',
    jpg => 'jpg',
  };

  String get label => switch (this) {
    svg => 'SVG',
    pdf => 'PDF',
    png => 'PNG',
    jpg => 'JPG',
  };
}

/// What the export window covers. Selection never writes the layout's plot window.
enum ExportScope {
  extents,
  selection,
  view,
  window;

  static ExportScope? tryParse(String raw) =>
      switch (raw.trim().toLowerCase()) {
        'extents' => extents,
        'selection' => selection,
        'view' => view,
        'window' => window,
        _ => null,
      };
}

/// A dragged export region, in drawing units. Not the layout plot window.
@freezed
abstract class ExportWindowModel with _$ExportWindowModel {
  const factory ExportWindowModel({
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) = _ExportWindowModel;
}

/// One drawing's export choices. Not persisted, so a new process starts over.
///
/// [open] is the pane, the canvas status, and the region drag. Format, scope,
/// and [window] stay when the pane hides, so the next entry on this drawing
/// restores them. Cancel clears [window]. [sidebarWasOpen] is how the pane
/// was found, so cancel can put the sidebar back.
@freezed
abstract class ExportStateModel with _$ExportStateModel {
  const factory ExportStateModel({
    @Default(ExportFormat.svg) ExportFormat format,
    @Default(ExportScope.extents) ExportScope scope,
    ExportWindowModel? window,
    @Default(false) bool open,
    @Default(true) bool sidebarWasOpen,
  }) = _ExportStateModel;
}

/// A request for the user to approve a set of pending changes.
///
/// Raised as data rather than by showing a dialog directly, so the approval gate
/// works identically whether the caller is a plugin, an AI turn, or a test.
/// This is not persisted. The one-shot reply lives on the service handshake.
@freezed
abstract class ApprovalRequestModel with _$ApprovalRequestModel {
  const factory ApprovalRequestModel({
    required String title,
    required String details,

    /// Entities the change would touch, highlighted on the canvas while the user
    /// decides. Seeing what is about to change is most of what makes an approval
    /// gate worth having.
    @Default([]) List<int> highlightIds,
  }) = _ApprovalRequestModel;
}

/// Per-tab Riverpod state: the in-flight tool prompt and content generations.
///
/// Camera and tools stay on the viewport controller so a pan does not write
/// this store. [contentEpoch] moves when the drawing or its tables change.
/// [selectionEpoch] moves when the pick changes. Screens select one of them
/// instead of listening to the tab.
@freezed
abstract class DocumentTabModel with _$DocumentTabModel {
  const factory DocumentTabModel({
    @Default('') String prompt,
    @Default(0) int contentEpoch,
    @Default(0) int selectionEpoch,
  }) = _DocumentTabModel;
}
