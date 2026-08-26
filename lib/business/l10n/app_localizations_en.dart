// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get theme_dark => 'Dark';

  @override
  String get theme_light => 'Light';

  @override
  String get appearance_dark_tooltip =>
      'Appearance — Dark. Choose Light or Dark';

  @override
  String get appearance_light_tooltip =>
      'Appearance — Light. Choose Light or Dark';

  @override
  String get settings => 'Settings';

  @override
  String get settings_tooltip => 'Settings. Theme, language and assistant';

  @override
  String get settings_tab_general => 'General';

  @override
  String get settings_tab_assistant => 'Assistant';

  @override
  String get settings_appearance => 'Appearance';

  @override
  String get settings_connection => 'Connection';

  @override
  String get settings_api_key => 'API key';

  @override
  String get settings_api_key_env => 'API key environment variable';

  @override
  String get open_settings => 'Open settings';

  @override
  String get new_drawing => 'New drawing';

  @override
  String get open => 'Open';

  @override
  String get open_ellipsis => 'Open…';

  @override
  String get save => 'Save';

  @override
  String get save_as => 'Save As…';

  @override
  String get save_unsaved_changes => 'Save unsaved changes';

  @override
  String get save_this_drawing => 'Save this drawing';

  @override
  String saved_write_again(String shortcut) {
    return 'Saved — $shortcut to write again';
  }

  @override
  String get close_drawing => 'Close drawing';

  @override
  String get command_palette => 'Command palette';

  @override
  String get hide_assistant => 'Hide assistant';

  @override
  String get show_assistant => 'Show assistant';

  @override
  String get nothing_to_undo => 'Nothing to undo';

  @override
  String get nothing_to_redo => 'Nothing to redo';

  @override
  String undo_named(String label) {
    return 'Undo $label';
  }

  @override
  String redo_named(String label) {
    return 'Redo $label';
  }

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get more_file_actions => 'More file actions';

  @override
  String get recent => 'Recent';

  @override
  String get remove_missing => 'Remove missing';

  @override
  String get clear_recent => 'Clear recent';

  @override
  String get recent_all_on_disk => 'Every recent file is still on disk.';

  @override
  String get recent_removed_one => 'Removed 1 missing file from Recent.';

  @override
  String recent_removed_many(int count) {
    return 'Removed $count missing files from Recent.';
  }

  @override
  String missing_path(String path) {
    return 'Missing — $path';
  }

  @override
  String missing_folder(String folder) {
    return 'Missing · $folder';
  }

  @override
  String get show_in_finder => 'Show in Finder';

  @override
  String get show_in_explorer => 'Show in Explorer';

  @override
  String get show_in_folder => 'Show in folder';

  @override
  String could_not_reveal(String path, String error) {
    return 'Could not reveal $path: $error';
  }

  @override
  String could_not_open(String path, String error) {
    return 'Could not open $path: $error';
  }

  @override
  String copied_path(String path) {
    return 'Copied $path';
  }

  @override
  String open_drawings(int count) {
    return 'Open drawings ($count)';
  }

  @override
  String import_warnings_tooltip(int count) {
    return '$count import warning(s) — click to read';
  }

  @override
  String get unsaved_drawing => 'Unsaved drawing';

  @override
  String unsaved_changes_path(String path) {
    return 'Unsaved changes — $path';
  }

  @override
  String get close => 'Close';

  @override
  String get close_unsaved => 'Close — unsaved changes';

  @override
  String get close_others => 'Close others';

  @override
  String get close_all => 'Close all';

  @override
  String get copy_path => 'Copy path';

  @override
  String import_warnings(int count) {
    return 'Import warnings ($count)';
  }

  @override
  String get import_warning_title_one => '1 import warning';

  @override
  String import_warning_title_many(int count) {
    return '$count import warnings';
  }

  @override
  String copied_warnings(int count) {
    return 'Copied $count warning(s)';
  }

  @override
  String get copy_all => 'Copy all';

  @override
  String get minimise => 'Minimise';

  @override
  String get restore => 'Restore';

  @override
  String get maximise => 'Maximise';

  @override
  String get close_window => 'Close window';

  @override
  String get layers => 'Layers';

  @override
  String get properties => 'Properties';

  @override
  String get layouts => 'Layouts';

  @override
  String get commands => 'Commands';

  @override
  String get extensions => 'Extensions';

  @override
  String get re_editor => 'Re-Editor';

  @override
  String get assistant => 'Assistant';

  @override
  String get view_layers_hint => 'Current layer, visibility and lock';

  @override
  String get view_properties_hint => 'Inspect and change the selection';

  @override
  String get view_layouts_hint => 'Model and paper space tabs';

  @override
  String get view_commands_hint => 'Everything the application can run';

  @override
  String get view_history_hint => 'Commands that have already run';

  @override
  String get view_extensions_hint => 'Installed plugins and their errors';

  @override
  String get view_editor_hint => 'Review extension source';

  @override
  String hide_view(String label) {
    return 'Hide $label';
  }

  @override
  String get show_sidebar => 'Show the sidebar';

  @override
  String get hide_sidebar => 'Hide the sidebar';

  @override
  String get resize_reset_width =>
      'Drag to resize · double-click to reset width';

  @override
  String get resize_collapse => 'Drag to resize · double-click to collapse';

  @override
  String get resize_expand => 'Drag to resize · double-click to expand';

  @override
  String get cancel => 'Cancel';

  @override
  String get dont_save => 'Don\'t save';

  @override
  String get continue_action => 'Continue';

  @override
  String get filter_commands => 'Filter by name, alias or category';

  @override
  String get clear_filter => 'Clear filter';

  @override
  String get no_commands_registered => 'No commands are registered.';

  @override
  String no_commands_match(String query) {
    return 'No commands match “$query”.';
  }

  @override
  String get last_used => 'Last used';

  @override
  String get commands_count_one => '1 command';

  @override
  String commands_count_many(int count) {
    return '$count commands';
  }

  @override
  String get commands_matching => ' matching';

  @override
  String alias_named(String alias) {
    return 'Alias $alias';
  }

  @override
  String get copy_and_dismiss => 'Click to copy and dismiss';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get search_commands => 'Search commands, aliases or categories';

  @override
  String get clear_search => 'Clear search';

  @override
  String get start_typing_command => 'Start typing to find a command.';

  @override
  String get try_alias_or_category =>
      'Try an alias such as L, C or M, or a category like Draw.';

  @override
  String get palette_hints => '↑↓  move   Enter  run   Esc  close';

  @override
  String get last_badge => 'Last';

  @override
  String get empty_tagline => 'An AI-native, plugin-everything 2D CAD';

  @override
  String get open_drawing_file => 'Open a DWG, DXF or FCB file';

  @override
  String get show_all_commands => 'Show all commands';

  @override
  String get command_history_hint =>
      'Command history will appear here. Click a line to reuse it, or press ↑ to recall the last thing you typed.';

  @override
  String get collapse_history => 'Collapse command history';

  @override
  String get expand_history => 'Expand command history';

  @override
  String get copied_history => 'Copied command history';

  @override
  String get hint_click_or_type => 'Click in the drawing, or type a value';

  @override
  String get hint_type_command => 'Type a command';

  @override
  String get command_history => 'Command history';

  @override
  String get copy_history => 'Copy history';

  @override
  String get clear_history => 'Clear history';

  @override
  String get snap => 'SNAP';

  @override
  String get ortho => 'ORTHO';

  @override
  String get polar => 'POLAR';

  @override
  String get grid => 'GRID';

  @override
  String get snap_tooltip =>
      'Object snapping (F3). Right-click to choose Endpoint, Midpoint…';

  @override
  String get ortho_tooltip => 'Constrain to horizontal and vertical (F8)';

  @override
  String polar_tooltip(int degrees) {
    return 'Polar tracking (F10) — $degrees°. Right-click to change the increment';
  }

  @override
  String get grid_tooltip => 'Reference grid (F7)';

  @override
  String selected_count(int count) {
    return '$count selected';
  }

  @override
  String get nothing_selected => 'Nothing selected';

  @override
  String get open_properties_selection => 'Open properties for the selection';

  @override
  String objects_count(int count) {
    return '$count objects';
  }

  @override
  String get drawing_empty => 'The drawing is empty';

  @override
  String get select_every_object => 'Select every object';

  @override
  String get zoom_extents_tooltip =>
      'Zoom extents — fit the drawing in the window';

  @override
  String get scene_stats_tooltip =>
      'Batches drawn / entities visible in the viewport';

  @override
  String draw_calls_visible(int calls, int visible) {
    return '$calls draw calls · $visible visible';
  }

  @override
  String get restore_defaults => 'Restore defaults';

  @override
  String get layer_hidden => 'hidden';

  @override
  String get layer_locked => 'locked';

  @override
  String current_layer_named(String name) {
    return 'Current layer \"$name\"';
  }

  @override
  String get current_layer_hint =>
      'Click to manage layers. Right-click to turn on or unlock';

  @override
  String get turn_layer_on => 'Turn layer on';

  @override
  String get turn_layer_off => 'Turn layer off';

  @override
  String get unlock_layer => 'Unlock layer';

  @override
  String get lock_layer => 'Lock layer';

  @override
  String get manage_layers => 'Manage layers';

  @override
  String get cursor => 'Cursor';

  @override
  String use_as_next_point(String text) {
    return 'Use $text as the next point';
  }

  @override
  String copy_text(String text) {
    return 'Copy $text';
  }

  @override
  String copied_text(String text) {
    return 'Copied $text';
  }

  @override
  String cancel_named(String name) {
    return 'Cancel $name';
  }

  @override
  String get erase => 'Erase';

  @override
  String get move => 'Move';

  @override
  String get copy => 'Copy';

  @override
  String get isolate => 'Isolate';

  @override
  String get hide => 'Hide';

  @override
  String get deselect => 'Deselect';

  @override
  String get select_all => 'Select all';

  @override
  String get zoom_extents => 'Zoom extents';

  @override
  String get zoom_window => 'Zoom window';

  @override
  String get zoom_to_selection => 'Zoom to selection';

  @override
  String get show_hidden_objects => 'Show hidden objects';

  @override
  String get no_hidden_objects => 'No hidden objects';

  @override
  String get one_object_hidden => '1 object is hidden';

  @override
  String many_objects_hidden(int count) {
    return '$count objects are hidden';
  }

  @override
  String get show_all => 'Show all';

  @override
  String get one_layer_off => '1 layer is off';

  @override
  String many_layers_off(int count) {
    return '$count layers are off';
  }

  @override
  String get show_all_layers => 'Show all layers';

  @override
  String current_layer_locked(String name) {
    return 'Current layer \"$name\" is locked';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get empty_drawing_title => 'This drawing is empty';

  @override
  String get empty_drawing_hint =>
      'Start a command from the toolbar, type an alias such as L or C, or pick one below.';

  @override
  String get line_alias => 'Line  L';

  @override
  String get rectangle_alias => 'Rectangle  REC';

  @override
  String get circle_alias => 'Circle  C';

  @override
  String get restore_viewport => 'Restore viewport';

  @override
  String get rename => 'Rename';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get delete => 'Delete';

  @override
  String get new_layout => 'New layout';

  @override
  String get model_space => 'Model space';

  @override
  String paper_size_mm(String width, String height) {
    return '$width × $height mm';
  }

  @override
  String get viewport_one => '1 viewport';

  @override
  String viewport_many(int count) {
    return '$count viewports';
  }

  @override
  String get viewport_maximised => 'Viewport maximised — click to restore';

  @override
  String get layout_right_click =>
      'Right-click for rename, duplicate or delete';

  @override
  String get delete_layout => 'Delete layout';

  @override
  String get new_paper_layout => 'New paper layout';

  @override
  String click_to_change(String label) {
    return 'Click to change $label';
  }

  @override
  String click_to_copy_label(String label) {
    return 'Click to copy $label';
  }

  @override
  String get layers_empty_workspace => 'Open a drawing to see its layers.';

  @override
  String get layouts_empty_workspace => 'Open a drawing to see its layouts.';

  @override
  String get new_layer_current => 'New layer (made current)';

  @override
  String get all_layers_on => 'All layers are on';

  @override
  String get show_hidden_layers_one => 'Show 1 hidden layer';

  @override
  String show_hidden_layers_many(int count) {
    return 'Show $count hidden layers';
  }

  @override
  String get filter_layers => 'Filter layers';

  @override
  String get no_layers => 'This drawing has no layers.';

  @override
  String no_layers_match(String query) {
    return 'No layers match “$query”.';
  }

  @override
  String get already_current => 'Already current';

  @override
  String get set_as_current => 'Set as current';

  @override
  String get isolate_layer => 'Isolate layer';

  @override
  String get no_objects_on_layer => 'No objects on this layer';

  @override
  String get select_objects_one => 'Select 1 object';

  @override
  String select_objects_many(int count) {
    return 'Select $count objects';
  }

  @override
  String get layer_0_cannot_delete => 'Layer 0 cannot be deleted';

  @override
  String get delete_layer => 'Delete layer';

  @override
  String get current_layer_row_hint =>
      'Current layer — double-click to isolate, right-click for more';

  @override
  String get make_current_row_hint =>
      'Click to make current — double-click to isolate';

  @override
  String get properties_empty_workspace =>
      'Open a drawing to inspect its objects.';

  @override
  String get clear_selection => 'Clear selection';

  @override
  String get list_selection => 'List the selection in the command history';

  @override
  String get geometry => 'Geometry';

  @override
  String get measurements => 'Measurements';

  @override
  String get layer => 'Layer';

  @override
  String get colour => 'Colour';

  @override
  String get line_type => 'Line type';

  @override
  String get lineweight => 'Lineweight';

  @override
  String get start => 'Start';

  @override
  String get length => 'Length';

  @override
  String get angle => 'Angle';

  @override
  String get centre => 'Centre';

  @override
  String get radius => 'Radius';

  @override
  String get diameter => 'Diameter';

  @override
  String get circumference => 'Circumference';

  @override
  String get start_angle => 'Start angle';

  @override
  String get end_angle => 'End angle';

  @override
  String get total_angle => 'Total angle';

  @override
  String get vertices => 'Vertices';

  @override
  String get closed => 'Closed';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get contents => 'Contents';

  @override
  String get position => 'Position';

  @override
  String get height => 'Height';

  @override
  String get rotation => 'Rotation';

  @override
  String get style => 'Style';

  @override
  String get column_width => 'Column width';

  @override
  String get block => 'Block';

  @override
  String get scale => 'Scale';

  @override
  String get pattern => 'Pattern';

  @override
  String get solid_fill => 'Solid fill';

  @override
  String get boundaries => 'Boundaries';

  @override
  String get measurement => 'Measurement';

  @override
  String get text => 'Text';

  @override
  String get total_length => 'Total length';

  @override
  String get total_area => 'Total area';

  @override
  String get size => 'Size';

  @override
  String get by_layer => 'ByLayer';

  @override
  String get by_block => 'ByBlock';

  @override
  String get default_value => 'Default';

  @override
  String get hairline => 'Hairline';

  @override
  String get drawing_empty_inspect => 'This drawing is empty.';

  @override
  String get click_object_inspect =>
      'Click an object on the canvas to inspect it.';

  @override
  String get nothing_to_clear => 'Nothing to clear';

  @override
  String get clear_conversation => 'Clear conversation';

  @override
  String get new_chat => 'New chat';

  @override
  String get chat_history => 'Chats';

  @override
  String get click_to_change_model => 'Click to change the model or endpoint';

  @override
  String get assistant_profiles => 'Configurations';

  @override
  String get add_assistant_profile => 'Add configuration';

  @override
  String get remove_assistant_profile => 'Remove configuration';

  @override
  String get assistant_profile_name => 'Display name';

  @override
  String get ask_follow_up => 'Add a follow-up';

  @override
  String context_used(String used, String window) {
    return '$used / $window';
  }

  @override
  String get context_waiting => 'Context size appears after the first reply';

  @override
  String get auto_approve => 'Auto-approve deletes';

  @override
  String get edits_without_asking => 'Deletes run without asking';

  @override
  String get ask_before_edits => 'Ask before the assistant deletes objects';

  @override
  String get custom_model => 'Custom model…';

  @override
  String get endpoint_ellipsis => 'Endpoint…';

  @override
  String get model => 'Model';

  @override
  String get model_id => 'Any model id, for example deepseek-chat';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get assistant_empty_configured =>
      'Ask about the drawing, or ask the assistant to change it. It uses the same commands you do, and one reply is one undo step.';

  @override
  String get assistant_empty_unconfigured =>
      'Paste an API key in Settings to talk to a model, or point the endpoint at a local server.';

  @override
  String get try_section => 'Try';

  @override
  String get prompt_object_count => 'How many objects are in this drawing?';

  @override
  String get prompt_square => 'Draw a 100 mm square at the origin';

  @override
  String get prompt_list_selection => 'List what is selected';

  @override
  String get click_to_copy => 'Click to copy';

  @override
  String get working => 'Working…';

  @override
  String get thinking => 'Thinking';

  @override
  String allow_one_change(String title) {
    return 'Allow $title?';
  }

  @override
  String allow_n_changes(int count) {
    return 'Allow $count changes?';
  }

  @override
  String affects_n_objects(int count) {
    return 'Affects $count object(s).';
  }

  @override
  String get ask_assistant => 'Ask the assistant  Enter to send';

  @override
  String get stop => 'Stop';

  @override
  String get send_enter => 'Send  Enter';

  @override
  String get open_extensions_folder => 'Open extensions folder';

  @override
  String get create_extension => 'Create extension';

  @override
  String get reload_all_extensions => 'Reload all extensions';

  @override
  String get extensions_unavailable =>
      'Extensions are unavailable: no extensions folder was configured for this session.';

  @override
  String get no_extensions_installed =>
      'No extensions are installed. Create one, or drop a folder with fancad.plugin.json into the extensions directory.';

  @override
  String get edit_source => 'Edit source';

  @override
  String get enable_extension => 'Enable extension';

  @override
  String get disable_extension => 'Disable extension';

  @override
  String get reload => 'Reload';

  @override
  String get state => 'State';

  @override
  String get folder => 'Folder';

  @override
  String get permissions => 'Permissions';

  @override
  String get log => 'Log';

  @override
  String get plugin_running => 'Running';

  @override
  String get plugin_starting => 'Starting';

  @override
  String get plugin_failed => 'Failed';

  @override
  String get plugin_disabled => 'Disabled';

  @override
  String get plugin_installed => 'Installed';

  @override
  String get unsaved_editor_changes => 'Unsaved editor changes';

  @override
  String editor_file_dirty(String name) {
    return '\"$name\" has edits that have not been written.';
  }

  @override
  String get nothing_to_save => 'Nothing to save';

  @override
  String get save_and_reload => 'Save and reload';

  @override
  String get saved => 'Saved';

  @override
  String get extension => 'Extension';

  @override
  String get editor_unavailable =>
      'Extensions are unavailable: no extensions folder was configured.';

  @override
  String get create_extension_first =>
      'Create an extension first, then open it here.';

  @override
  String get choose_extension =>
      'Choose an extension above, or use Edit source from the Extensions panel.';

  @override
  String no_such_file(String name) {
    return 'No such file: $name';
  }

  @override
  String plugin_not_installed(String id) {
    return '$id is not installed';
  }

  @override
  String get snap_endpoint => 'Endpoint';

  @override
  String get snap_midpoint => 'Midpoint';

  @override
  String get snap_center => 'Center';

  @override
  String get snap_quadrant => 'Quadrant';

  @override
  String get snap_intersection => 'Intersection';

  @override
  String get snap_perpendicular => 'Perpendicular';

  @override
  String get snap_tangent => 'Tangent';

  @override
  String get snap_node => 'Node';

  @override
  String get snap_nearest => 'Nearest';

  @override
  String get category_file => 'File';

  @override
  String get category_draw => 'Draw';

  @override
  String get category_modify => 'Modify';

  @override
  String get category_view => 'View';

  @override
  String get category_select => 'Select';

  @override
  String get category_layers => 'Layers';

  @override
  String get category_inquiry => 'Inquiry';

  @override
  String get category_output => 'Output';

  @override
  String get category_extensions => 'Extensions';

  @override
  String get command_file_new => 'New Drawing';

  @override
  String get command_file_open => 'Open...';

  @override
  String get command_file_save => 'Save';

  @override
  String get command_file_save_as => 'Save As...';

  @override
  String get command_file_close => 'Close Drawing';

  @override
  String get command_file_open_recent => 'Open Recent';

  @override
  String get command_file_audit => 'Fidelity Audit';

  @override
  String get command_draw_line => 'Line';

  @override
  String get command_draw_polyline => 'Polyline';

  @override
  String get command_draw_spline => 'Spline';

  @override
  String get command_draw_rectangle => 'Rectangle';

  @override
  String get command_draw_circle => 'Circle';

  @override
  String get command_draw_circle_2p => 'Circle (2 Points)';

  @override
  String get command_draw_circle_3p => 'Circle (3 Points)';

  @override
  String get command_draw_circle_ttr => 'Circle (Tan Tan Radius)';

  @override
  String get command_draw_donut => 'Donut';

  @override
  String get command_draw_arc => 'Arc';

  @override
  String get command_draw_polygon => 'Polygon';

  @override
  String get command_draw_ellipse => 'Ellipse';

  @override
  String get command_draw_xline => 'Construction Line';

  @override
  String get command_draw_ray => 'Ray';

  @override
  String get command_draw_point => 'Point';

  @override
  String get command_draw_divide => 'Divide';

  @override
  String get command_draw_measure => 'Measure';

  @override
  String get command_draw_text => 'Text';

  @override
  String get command_draw_mtext => 'MText';

  @override
  String get command_draw_leader => 'Leader';

  @override
  String get command_draw_hatch => 'Hatch';

  @override
  String get command_draw_dim_linear => 'Linear Dimension';

  @override
  String get command_draw_dim_aligned => 'Aligned Dimension';

  @override
  String get command_draw_dim_radius => 'Radius Dimension';

  @override
  String get command_draw_dim_diameter => 'Diameter Dimension';

  @override
  String get command_draw_center_mark => 'Center Mark';

  @override
  String get command_draw_center_line => 'Centerline';

  @override
  String get command_draw_dim_angular => 'Angular Dimension';

  @override
  String get command_draw_dim_continue => 'Continue Dimension';

  @override
  String get command_draw_dim_baseline => 'Baseline Dimension';

  @override
  String get command_annot_dimstyle => 'Dimension Style';

  @override
  String get command_edit_erase => 'Erase';

  @override
  String get command_edit_overkill => 'Overkill';

  @override
  String get command_edit_move => 'Move';

  @override
  String get command_edit_copy => 'Copy';

  @override
  String get command_edit_stretch => 'Stretch';

  @override
  String get command_edit_rotate => 'Rotate';

  @override
  String get command_edit_scale => 'Scale';

  @override
  String get command_edit_mirror => 'Mirror';

  @override
  String get command_edit_align => 'Align';

  @override
  String get command_edit_array => 'Rectangular Array';

  @override
  String get command_edit_polar_array => 'Polar Array';

  @override
  String get command_edit_offset => 'Offset';

  @override
  String get command_edit_trim => 'Trim';

  @override
  String get command_edit_extend => 'Extend';

  @override
  String get command_edit_fillet => 'Fillet';

  @override
  String get command_edit_chamfer => 'Chamfer';

  @override
  String get command_edit_break => 'Break';

  @override
  String get command_edit_lengthen => 'Lengthen';

  @override
  String get command_edit_explode => 'Explode';

  @override
  String get command_edit_block => 'Block';

  @override
  String get command_edit_insert => 'Insert';

  @override
  String get command_edit_minsert => 'MInsert';

  @override
  String get command_block_purge => 'Purge Unused Blocks';

  @override
  String get command_block_rename => 'Rename Block';

  @override
  String get command_edit_join => 'Join';

  @override
  String get command_edit_close => 'Close Polyline';

  @override
  String get command_edit_open => 'Open Polyline';

  @override
  String get command_edit_polyline_width => 'Polyline Width';

  @override
  String get command_edit_hatch => 'Hatch Edit';

  @override
  String get command_edit_to_polyline => 'Convert to Polyline';

  @override
  String get command_edit_reverse => 'Reverse';

  @override
  String get command_edit_undo => 'Undo';

  @override
  String get command_edit_redo => 'Redo';

  @override
  String get command_edit_change_layer => 'Change Layer';

  @override
  String get command_edit_change_color => 'Change Colour';

  @override
  String get command_edit_change_linetype => 'Change Linetype';

  @override
  String get command_edit_change_lineweight => 'Change Lineweight';

  @override
  String get command_edit_dimension_text => 'Dimension Text';

  @override
  String get command_edit_dim_tedit => 'Move Dimension Text';

  @override
  String get command_edit_text_content => 'Edit Text';

  @override
  String get command_edit_justify_text => 'Justify Text';

  @override
  String get command_edit_match_prop => 'Match Properties';

  @override
  String get command_view_zoom_extents => 'Zoom Extents';

  @override
  String get command_view_zoom_window => 'Zoom Window';

  @override
  String get command_view_zoom_in => 'Zoom In';

  @override
  String get command_view_zoom_out => 'Zoom Out';

  @override
  String get command_view_zoom_selected => 'Zoom to Selection';

  @override
  String get command_view_regen => 'Regenerate';

  @override
  String get command_workbench_preferences => 'Settings...';

  @override
  String get command_select_all => 'Select All';

  @override
  String get command_select_none => 'Deselect All';

  @override
  String get command_select_invert => 'Invert Selection';

  @override
  String get command_select_similar => 'Select Similar';

  @override
  String get command_select_by_layer => 'Select by Layer';

  @override
  String get command_select_by_color => 'Select by Colour';

  @override
  String get command_select_by_linetype => 'Select by Linetype';

  @override
  String get command_select_by_lineweight => 'Select by Lineweight';

  @override
  String get command_select_by_type => 'Select by Type';

  @override
  String get command_select_by_block => 'Select by Block';

  @override
  String get command_view_isolate_objects => 'Isolate Objects';

  @override
  String get command_view_hide_objects => 'Hide Objects';

  @override
  String get command_view_unisolate_objects => 'Unisolate Objects';

  @override
  String get command_layer_new => 'New Layer';

  @override
  String get command_layer_set_current => 'Set Current Layer';

  @override
  String get command_layer_toggle_visible => 'Toggle Layer Visibility';

  @override
  String get command_layer_isolate => 'Isolate Layer';

  @override
  String get command_layer_show_all => 'Show All Layers';

  @override
  String get command_layer_toggle_lock => 'Toggle Layer Lock';

  @override
  String get command_layer_delete => 'Delete Layer';

  @override
  String get command_layer_purge => 'Purge Unused Layers';

  @override
  String get command_query_summary => 'Drawing Summary';

  @override
  String get command_query_list => 'List';

  @override
  String get command_query_entities => 'Query Entities';

  @override
  String get command_query_selection => 'Query Selection';

  @override
  String get command_query_viewport => 'Query Viewport';

  @override
  String get command_query_id => 'ID Point';

  @override
  String get command_query_distance => 'Distance';

  @override
  String get command_query_angle => 'Angle';

  @override
  String get command_query_area => 'Area';

  @override
  String get command_query_layers => 'List Layers';

  @override
  String get command_layout_list => 'List Layouts';

  @override
  String get command_layout_set => 'Set Layout';

  @override
  String get command_layout_new => 'New Layout';

  @override
  String get command_layout_delete => 'Delete Layout';

  @override
  String get command_layout_copy => 'Copy Layout';

  @override
  String get command_layout_rename => 'Rename Layout';

  @override
  String get command_layout_order => 'Layout Order';

  @override
  String get command_layout_pagesetup => 'Page Setup';

  @override
  String get command_layout_mview => 'Make Viewport';

  @override
  String get command_layout_vpscale => 'Viewport Scale';

  @override
  String get command_layout_vplock => 'Viewport Lock';

  @override
  String get command_layout_vpon => 'Viewport On';

  @override
  String get command_layout_vplayer => 'Viewport Layer Freeze';

  @override
  String get command_layout_vpmax => 'Maximize Viewport';

  @override
  String get command_layout_vpmin => 'Minimize Viewport';

  @override
  String get command_print_export_svg => 'Export SVG';

  @override
  String get command_print_export_pdf => 'Export PDF';

  @override
  String get command_xref_attach => 'Attach Xref';

  @override
  String get command_xref_reload => 'Reload Xref';

  @override
  String get command_xref_detach => 'Detach Xref';

  @override
  String get command_xref_bind => 'Bind Xref';

  @override
  String get command_plugins_list => 'List Extensions';

  @override
  String get command_plugins_reload => 'Reload Extension';

  @override
  String get command_plugins_enable => 'Enable Extension';

  @override
  String get command_plugins_disable => 'Disable Extension';

  @override
  String get command_plugins_logs => 'Show Extension Log';

  @override
  String get command_plugins_scaffold => 'Create Extension';

  @override
  String get command_plugins_write => 'Write Extension File';

  @override
  String get command_plugins_read => 'Read Extension File';

  @override
  String get command_plugins_typings => 'Write Plugin API Typings';

  @override
  String get command_plugins_edit => 'Edit Extension File';

  @override
  String get command_plugins_eval => 'Evaluate In Extension';

  @override
  String get end => 'End';

  @override
  String get min => 'Min';

  @override
  String get max => 'Max';

  @override
  String get objects_in_drawing_one => '1 object in this drawing.';

  @override
  String get use => 'Use';

  @override
  String objects_in_drawing_many(int count) {
    return '$count objects in this drawing.';
  }
}
