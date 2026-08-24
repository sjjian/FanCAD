import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';
export 'locale.dart';

/// Looks up [AppLocalizations] the way OpenHare does, with English as the
/// leftover when no delegate is in the tree (headless tests, a forgotten wrap).
extension FanCadL10nContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('en'));
}

extension FanCadL10nLookups on AppLocalizations {
  String commandTitle(String id, String fallback) {
    return switch (id) {
      'file.new' => command_file_new,
      'file.open' => command_file_open,
      'file.save' => command_file_save,
      'file.saveAs' => command_file_save_as,
      'file.close' => command_file_close,
      'file.openRecent' => command_file_open_recent,
      'file.audit' => command_file_audit,
      'draw.line' => command_draw_line,
      'draw.polyline' => command_draw_polyline,
      'draw.spline' => command_draw_spline,
      'draw.rectangle' => command_draw_rectangle,
      'draw.circle' => command_draw_circle,
      'draw.circle2p' => command_draw_circle_2p,
      'draw.circle3p' => command_draw_circle_3p,
      'draw.circleTtr' => command_draw_circle_ttr,
      'draw.donut' => command_draw_donut,
      'draw.arc' => command_draw_arc,
      'draw.polygon' => command_draw_polygon,
      'draw.ellipse' => command_draw_ellipse,
      'draw.xline' => command_draw_xline,
      'draw.ray' => command_draw_ray,
      'draw.point' => command_draw_point,
      'draw.divide' => command_draw_divide,
      'draw.measure' => command_draw_measure,
      'draw.text' => command_draw_text,
      'draw.mtext' => command_draw_mtext,
      'draw.leader' => command_draw_leader,
      'draw.hatch' => command_draw_hatch,
      'draw.dimLinear' => command_draw_dim_linear,
      'draw.dimAligned' => command_draw_dim_aligned,
      'draw.dimRadius' => command_draw_dim_radius,
      'draw.dimDiameter' => command_draw_dim_diameter,
      'draw.centerMark' => command_draw_center_mark,
      'draw.centerLine' => command_draw_center_line,
      'draw.dimAngular' => command_draw_dim_angular,
      'draw.dimContinue' => command_draw_dim_continue,
      'draw.dimBaseline' => command_draw_dim_baseline,
      'annot.dimstyle' => command_annot_dimstyle,
      'edit.erase' => command_edit_erase,
      'edit.overkill' => command_edit_overkill,
      'edit.move' => command_edit_move,
      'edit.copy' => command_edit_copy,
      'edit.stretch' => command_edit_stretch,
      'edit.rotate' => command_edit_rotate,
      'edit.scale' => command_edit_scale,
      'edit.mirror' => command_edit_mirror,
      'edit.align' => command_edit_align,
      'edit.array' => command_edit_array,
      'edit.polarArray' => command_edit_polar_array,
      'edit.offset' => command_edit_offset,
      'edit.trim' => command_edit_trim,
      'edit.extend' => command_edit_extend,
      'edit.fillet' => command_edit_fillet,
      'edit.chamfer' => command_edit_chamfer,
      'edit.break' => command_edit_break,
      'edit.lengthen' => command_edit_lengthen,
      'edit.explode' => command_edit_explode,
      'edit.block' => command_edit_block,
      'edit.insert' => command_edit_insert,
      'edit.minsert' => command_edit_minsert,
      'block.purge' => command_block_purge,
      'block.rename' => command_block_rename,
      'edit.join' => command_edit_join,
      'edit.close' => command_edit_close,
      'edit.open' => command_edit_open,
      'edit.polylineWidth' => command_edit_polyline_width,
      'edit.hatch' => command_edit_hatch,
      'edit.toPolyline' => command_edit_to_polyline,
      'edit.reverse' => command_edit_reverse,
      'edit.undo' => command_edit_undo,
      'edit.redo' => command_edit_redo,
      'edit.changeLayer' => command_edit_change_layer,
      'edit.changeColor' => command_edit_change_color,
      'edit.changeLinetype' => command_edit_change_linetype,
      'edit.changeLineweight' => command_edit_change_lineweight,
      'edit.dimensionText' => command_edit_dimension_text,
      'edit.dimTedit' => command_edit_dim_tedit,
      'edit.textContent' => command_edit_text_content,
      'edit.justifyText' => command_edit_justify_text,
      'edit.matchProp' => command_edit_match_prop,
      'view.zoomExtents' => command_view_zoom_extents,
      'view.zoomWindow' => command_view_zoom_window,
      'view.zoomIn' => command_view_zoom_in,
      'view.zoomOut' => command_view_zoom_out,
      'view.zoomSelected' => command_view_zoom_selected,
      'view.regen' => command_view_regen,
      'select.all' => command_select_all,
      'select.none' => command_select_none,
      'select.invert' => command_select_invert,
      'select.similar' => command_select_similar,
      'select.byLayer' => command_select_by_layer,
      'select.byColor' => command_select_by_color,
      'select.byLinetype' => command_select_by_linetype,
      'select.byLineweight' => command_select_by_lineweight,
      'select.byType' => command_select_by_type,
      'select.byBlock' => command_select_by_block,
      'view.isolateObjects' => command_view_isolate_objects,
      'view.hideObjects' => command_view_hide_objects,
      'view.unisolateObjects' => command_view_unisolate_objects,
      'layer.new' => command_layer_new,
      'layer.setCurrent' => command_layer_set_current,
      'layer.toggleVisible' => command_layer_toggle_visible,
      'layer.isolate' => command_layer_isolate,
      'layer.showAll' => command_layer_show_all,
      'layer.toggleLock' => command_layer_toggle_lock,
      'layer.delete' => command_layer_delete,
      'layer.purge' => command_layer_purge,
      'query.summary' => command_query_summary,
      'query.list' => command_query_list,
      'query.entities' => command_query_entities,
      'query.id' => command_query_id,
      'query.distance' => command_query_distance,
      'query.angle' => command_query_angle,
      'query.area' => command_query_area,
      'query.layers' => command_query_layers,
      'layout.list' => command_layout_list,
      'layout.set' => command_layout_set,
      'layout.new' => command_layout_new,
      'layout.delete' => command_layout_delete,
      'layout.copy' => command_layout_copy,
      'layout.rename' => command_layout_rename,
      'layout.order' => command_layout_order,
      'layout.pagesetup' => command_layout_pagesetup,
      'layout.mview' => command_layout_mview,
      'layout.vpscale' => command_layout_vpscale,
      'layout.vplock' => command_layout_vplock,
      'layout.vpon' => command_layout_vpon,
      'layout.vplayer' => command_layout_vplayer,
      'layout.vpmax' => command_layout_vpmax,
      'layout.vpmin' => command_layout_vpmin,
      'print.exportSvg' => command_print_export_svg,
      'print.exportPdf' => command_print_export_pdf,
      'xref.attach' => command_xref_attach,
      'xref.reload' => command_xref_reload,
      'xref.detach' => command_xref_detach,
      'xref.bind' => command_xref_bind,
      'plugins.list' => command_plugins_list,
      'plugins.reload' => command_plugins_reload,
      'plugins.enable' => command_plugins_enable,
      'plugins.disable' => command_plugins_disable,
      'plugins.logs' => command_plugins_logs,
      'plugins.scaffold' => command_plugins_scaffold,
      'plugins.write' => command_plugins_write,
      'plugins.read' => command_plugins_read,
      'plugins.typings' => command_plugins_typings,
      'plugins.edit' => command_plugins_edit,
      'plugins.eval' => command_plugins_eval,
      _ => fallback,
    };
  }

  /// Leftover unknown categories keep the registry English name.
  String commandCategory(String name) {
    return switch (name) {
      'File' => category_file,
      'Draw' => category_draw,
      'Modify' => category_modify,
      'View' => category_view,
      'Select' => category_select,
      'Layers' => category_layers,
      'Inquiry' => category_inquiry,
      'Output' => category_output,
      'Extensions' => category_extensions,
      _ => name,
    };
  }

  String snapModeLabel(SnapMode mode) {
    return switch (mode) {
      SnapMode.endpoint => snap_endpoint,
      SnapMode.midpoint => snap_midpoint,
      SnapMode.center => snap_center,
      SnapMode.quadrant => snap_quadrant,
      SnapMode.intersection => snap_intersection,
      SnapMode.perpendicular => snap_perpendicular,
      SnapMode.tangent => snap_tangent,
      SnapMode.node => snap_node,
      SnapMode.nearest => snap_nearest,
    };
  }

  String revealInFolder() {
    if (Platform.isMacOS) return show_in_finder;
    if (Platform.isWindows) return show_in_explorer;
    return show_in_folder;
  }

  String commandCount(int count) =>
      count == 1 ? commands_count_one : commands_count_many(count);

  String importWarningTitle(int count) => count == 1
      ? import_warning_title_one
      : import_warning_title_many(count);
}

/// Registry search plus leftover Chinese titles the English index cannot see.
List<CommandDescriptor> searchCommandsLocalized(
  CommandRegistry registry,
  String query,
  AppLocalizations l10n, {
  int limit = 60,
}) {
  final fromRegistry = registry.search(query, limit: limit);
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return fromRegistry;
  final seen = {for (final descriptor in fromRegistry) descriptor.id};
  final extra = <CommandDescriptor>[];
  for (final descriptor in registry.all) {
    if (seen.contains(descriptor.id)) continue;
    final title = l10n.commandTitle(descriptor.id, descriptor.title).toLowerCase();
    final category = l10n.commandCategory(descriptor.category).toLowerCase();
    if (title.contains(needle) || category.contains(needle)) {
      extra.add(descriptor);
    }
  }
  if (extra.isEmpty) return fromRegistry;
  return [...fromRegistry, ...extra].take(limit).toList();
}
