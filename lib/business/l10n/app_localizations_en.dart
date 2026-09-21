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
  String get theme_system => 'System';

  @override
  String get appearance_dark_tooltip =>
      'Appearance — Dark. Choose Light, Dark or System';

  @override
  String get appearance_light_tooltip =>
      'Appearance — Light. Choose Light, Dark or System';

  @override
  String get settings => 'Settings';

  @override
  String get settings_tooltip => 'Settings. Theme, language and assistant';

  @override
  String get settings_tab_general => 'General';

  @override
  String get settings_tab_assistant => 'Assistant';

  @override
  String get settings_tab_models => 'Models';

  @override
  String get settings_tab_mcp => 'MCP';

  @override
  String get settings_appearance => 'Appearance';

  @override
  String get settings_mcp => 'MCP';

  @override
  String get settings_mcp_enable => 'Network';

  @override
  String get settings_mcp_on =>
      'Cursor and Claude Desktop connect at the URL below';

  @override
  String get settings_mcp_off => 'External MCP clients cannot attach';

  @override
  String get settings_mcp_url => 'URL';

  @override
  String get settings_mcp_local => 'Local only';

  @override
  String get settings_mcp_local_on => 'Only this computer can connect';

  @override
  String get settings_mcp_local_off =>
      'Other machines can connect; the allowlist is optional';

  @override
  String get settings_mcp_port => 'Port';

  @override
  String get settings_mcp_allowlist => 'Allowlist';

  @override
  String get settings_mcp_allowlist_hint => 'Optional, comma-separated IPs';

  @override
  String get settings_current_model => 'Current model';

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
  String get new_tab => 'New tab';

  @override
  String get start_tab => 'Start';

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
  String get empty_github => 'FanCAD on GitHub';

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
  String get copy_to_clipboard => 'Copy to clipboard';

  @override
  String get copy_with_base => 'Copy with base point';

  @override
  String get cut => 'Cut';

  @override
  String get paste => 'Paste';

  @override
  String get paste_to_original => 'Paste to original coordinates';

  @override
  String get paste_as_block => 'Paste as block';

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
  String get assistant_canvas_locked =>
      'The assistant is working. The drawing cannot be edited.';

  @override
  String get empty_drawing_title => 'This drawing is empty';

  @override
  String get empty_drawing_hint =>
      'Start a command from the toolbar, or type an alias such as L or C.';

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
  String get justify => 'Justify';

  @override
  String get width_factor => 'Width factor';

  @override
  String get oblique => 'Oblique';

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
  String get assistant_profiles => 'Models';

  @override
  String get add_assistant_profile => 'Add model';

  @override
  String get remove_assistant_profile => 'Remove model';

  @override
  String get settings_test_model => 'Test connection';

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
  String get ask_other => 'Other…';

  @override
  String get ask_questions => 'Questions';

  @override
  String get ask_skip => 'Skip';

  @override
  String get pin_selection => 'Add selection to chat';

  @override
  String get mention_drawing => 'Mention a drawing';

  @override
  String get no_open_drawings => 'No open drawings';

  @override
  String get pin_into_chat => 'Add to chat';

  @override
  String get ask_assistant => 'Ask the assistant  Enter to send';

  @override
  String get ask_assistant_unavailable =>
      'Model unavailable. Configure it in Settings.';

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
  String get command_annot_textstyle => 'Text Style';

  @override
  String get command_edit_erase => 'Erase';

  @override
  String get command_edit_overkill => 'Overkill';

  @override
  String get command_edit_move => 'Move';

  @override
  String get command_edit_copy => 'Copy';

  @override
  String get command_edit_copy_clip => 'Copy to Clipboard';

  @override
  String get command_edit_copy_base => 'Copy with Base Point';

  @override
  String get command_edit_cut_clip => 'Cut';

  @override
  String get command_edit_paste_clip => 'Paste';

  @override
  String get command_edit_paste_orig => 'Paste to Original Coordinates';

  @override
  String get command_edit_paste_block => 'Paste as Block';

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
  String get command_edit_text_object => 'Edit Text Object';

  @override
  String edit_text_object_window(String entity) {
    return 'Edit $entity';
  }

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
  String get command_file_list => 'List Drawings';

  @override
  String get command_file_activate => 'Activate Drawing';

  @override
  String get command_draw_attdef => 'Attribute Definition';

  @override
  String get command_edit_attedit => 'Edit Attributes';

  @override
  String get command_view_units => 'Units';

  @override
  String get command_file_new_desc => 'Creates an empty drawing in a new tab.';

  @override
  String get command_file_open_desc => 'Opens a DWG or DXF file.';

  @override
  String get command_file_save_desc =>
      'Saves the drawing this command is targeting, asking for a path when it has never been saved.';

  @override
  String get command_file_save_as_desc =>
      'Saves the drawing this command is targeting to a new file.';

  @override
  String get command_file_close_desc =>
      'Closes the drawing this command is targeting.';

  @override
  String get command_file_open_recent_desc => 'Reopens a recently used file.';

  @override
  String get command_file_audit_desc =>
      'Writes the drawing to a temp DXF and reports anything a round trip would lose.';

  @override
  String get command_file_list_desc =>
      'Lists every open drawing tab: id, title, path, dirty, whether it is active, entity count, and the current layout. Use the id as the fancad tab selector to operate on a drawing without switching the UI.';

  @override
  String get command_file_activate_desc =>
      'Brings an open drawing to the front. Pass id from file.list, or a unique path or title.';

  @override
  String get command_draw_line_desc =>
      'Draws one or more connected straight line segments. Supply start and end to draw a single segment non-interactively.';

  @override
  String get command_draw_polyline_desc =>
      'Draws a connected sequence of segments as one polyline entity. Pass a points array to create it non-interactively.';

  @override
  String get command_draw_spline_desc =>
      'Draws a clamped B-spline. Control-point mode pulls the curve toward the clicks and only guarantees the ends. Fit mode interpolates every point. Pass a points array to create it non-interactively.';

  @override
  String get command_draw_rectangle_desc =>
      'Draws an axis-aligned rectangle as a closed polyline.';

  @override
  String get command_draw_circle_desc =>
      'Draws a circle from a centre point and a radius.';

  @override
  String get command_draw_circle_2p_desc =>
      'Draws a circle whose diameter is the segment between two points.';

  @override
  String get command_draw_circle_3p_desc =>
      'Draws the unique circle that passes through three specified points.';

  @override
  String get command_draw_circle_ttr_desc =>
      'Draws a circle of a given radius tangent to two lines, circles or arcs. The pick on each object chooses the side (and, for a circle, external versus internal tangent).';

  @override
  String get command_draw_donut_desc =>
      'Draws a filled ring from an inside and outside diameter. A zero inside diameter is a filled disk. The result is a closed wide polyline, which is how DWG stores a donut.';

  @override
  String get command_draw_arc_desc =>
      'Draws a circular arc through three points: start, a point on the arc, and end.';

  @override
  String get command_draw_polygon_desc =>
      'Draws a regular polygon inscribed in a circle.';

  @override
  String get command_draw_ellipse_desc =>
      'Draws an ellipse from a centre, one axis endpoint, and the distance to the other axis.';

  @override
  String get command_draw_xline_desc =>
      'Draws an infinite construction line through a point in a given direction. The second point only sets the angle; both sides extend without end.';

  @override
  String get command_draw_ray_desc =>
      'Draws a semi-infinite ray from a start point through a second point. Unlike XLINE, it has a beginning.';

  @override
  String get command_draw_point_desc => 'Places a point marker.';

  @override
  String get command_draw_divide_desc =>
      'Places point markers that split a line, polyline, arc or circle into equal segments. Open objects leave the endpoints unmarked; a circle or closed polyline places a marker at every interval. A bulge is followed as its arc, not the chord.';

  @override
  String get command_draw_measure_desc =>
      'Places point markers at a fixed spacing along a line, polyline, arc or circle. Open objects start from the nearer end; a circle starts at the pick. Endpoints are not marked. A bulge is followed as its arc, not the chord.';

  @override
  String get command_draw_text_desc =>
      'Places a single line of text. Style defaults to the current TEXTSTYLE. Justify is Left, Center, Right or a corner code such as TL.';

  @override
  String get command_draw_mtext_desc =>
      'Places multiline text. Newlines become \\P. Width 0 does not wrap. Justify is TL…BR or attachment 1–9 (1 is top-left).';

  @override
  String get command_draw_attdef_desc =>
      'Places an attribute definition. Include it in a BLOCK so INSERT and ATTEDIT can fill the tag — title blocks and schedules.';

  @override
  String get command_draw_leader_desc =>
      'Draws a leader from an arrow tip through one or more vertices. Optional annotation text sits on a horizontal landing at the last point, the same way AutoCAD LEADER places a callout.';

  @override
  String get command_draw_hatch_desc =>
      'Fills the area around an internal point, or around selected closed boundaries. Four lines that meet still count as a boundary.';

  @override
  String get command_draw_dim_linear_desc =>
      'Places a horizontal or vertical dimension. The dimension-line pick chooses the axis: above or below the origins measures width; left or right measures height. A line can stand in for the two origins.';

  @override
  String get command_draw_dim_aligned_desc =>
      'Places a dimension parallel to the two origins. The text is the true distance, not the horizontal or vertical component. A line can stand in for the two origins.';

  @override
  String get command_draw_dim_radius_desc =>
      'Places a radius dimension on a circle or arc. The second pick is the arrow tip; the text is the radius, prefixed with R.';

  @override
  String get command_draw_dim_diameter_desc =>
      'Places a diameter dimension on a circle or arc. The second pick is the arrow tip; the text is the diameter, prefixed with Ø.';

  @override
  String get command_draw_center_mark_desc =>
      'Draws a centre mark on selected circles or arcs. A short cross sits on the centre; optional extensions continue past the circumference, the usual shop-drawing DIMCENTER.';

  @override
  String get command_draw_center_line_desc =>
      'Draws a centreline between two parallel lines, or through the centres of two circles or arcs. The line spans both objects and extends a little past each end.';

  @override
  String get command_draw_dim_angular_desc =>
      'Places an angular dimension. Pick an arc and its centre is the vertex; pick two lines and their intersection is the vertex; the last pick sits on the dimension arc and chooses which sector is labelled. Three points still work when a vertex is supplied.';

  @override
  String get command_draw_dim_continue_desc =>
      'Places the next linear or aligned dimension from the previous second origin, on the same dimension line. Chain several next points to walk a row of features.';

  @override
  String get command_draw_dim_baseline_desc =>
      'Places the next linear or aligned dimension from the same first origin, on a dimension line stepped outward. Chain several next points to stack overall lengths.';

  @override
  String get command_annot_dimstyle_desc =>
      'Creates or edits a dimension style. Regenerated dimensions read text height, arrow size, extension offsets, scale and decimal places from the named style. Omit the name to list styles or to edit the current one.';

  @override
  String get command_annot_textstyle_desc =>
      'Creates or edits a text style. New TEXT and MTEXT read the font, fixed height, width factor and oblique from the named style. Omit the name to list styles or to edit the current one.';

  @override
  String get command_edit_erase_desc => 'Deletes the selected objects.';

  @override
  String get command_edit_overkill_desc =>
      'Deletes exact geometric duplicates and folds overlapping or abutting collinear lines into one stroke. The first copy is kept and stretched to the union. Omitted ids means the whole current space, so a leftover selection cannot hide the rest of the duplicates.';

  @override
  String get command_edit_move_desc =>
      'Moves the selected objects by a displacement.';

  @override
  String get command_edit_copy_desc =>
      'Copies the selected objects to one or more locations. Each second point is another copy from the same base; Escape finishes.';

  @override
  String get command_edit_copy_clip_desc =>
      'Copies the selected objects to the clipboard. The lower-left of the selection is the paste base. Paste in this drawing or another tab with PASTECLIP.';

  @override
  String get command_edit_copy_base_desc =>
      'Copies the selected objects to the clipboard with a base point you pick, so PASTECLIP can land that point on the insertion.';

  @override
  String get command_edit_cut_clip_desc =>
      'Copies the selected objects to the clipboard and deletes them from the drawing. Objects on a locked layer stay; the clipboard still holds a copy.';

  @override
  String get command_edit_paste_clip_desc =>
      'Pastes clipboard objects at an insertion point. The stored base point lands on that click.';

  @override
  String get command_edit_paste_orig_desc =>
      'Pastes clipboard objects at the coordinates they had in the source drawing, without asking for an insertion point.';

  @override
  String get command_edit_paste_block_desc =>
      'Pastes clipboard objects as one anonymous block reference. The stored base point lands on the insertion point you pick.';

  @override
  String get command_edit_stretch_desc =>
      'Moves vertices inside a crossing window and leaves the rest anchored. Objects wholly captured by the window move as a body.';

  @override
  String get command_edit_rotate_desc =>
      'Rotates the selected objects about a base point. The angle is in degrees, counter-clockwise.';

  @override
  String get command_edit_scale_desc =>
      'Scales the selected objects uniformly about a base point.';

  @override
  String get command_edit_mirror_desc =>
      'Mirrors the selected objects across a line.';

  @override
  String get command_edit_align_desc =>
      'Moves the selection so a source point lands on a destination point. A second pair rotates to match the two directions; an optional scale matches the two lengths.';

  @override
  String get command_edit_array_desc =>
      'Creates a rectangular grid of copies of the selected objects.';

  @override
  String get command_edit_polar_array_desc =>
      'Creates copies of the selected objects rotated about a centre. A fill of 360° spaces items around the full circle; a smaller fill spaces them from the original through that angle, inclusive.';

  @override
  String get command_edit_offset_desc =>
      'Creates parallel copies of lines, arcs, circles and polylines at a fixed distance.';

  @override
  String get command_edit_trim_desc =>
      'Shortens a line, polyline or arc back to where it crosses the selected cutting edges. The part containing the pick point is removed. A closed polyline opens; a bulge is cut on the arc, not the chord.';

  @override
  String get command_edit_extend_desc =>
      'Lengthens a line, open polyline or arc until it meets the selected boundary edges. A bulge grows along its circle. On a polyline or arc the pick chooses which end moves.';

  @override
  String get command_edit_fillet_desc =>
      'Rounds the corner between two lines, or vertices of a polyline, with an arc of a given radius. Pass all=true to fillet every straight corner of a polyline. A radius of zero trims or extends two lines to a sharp corner.';

  @override
  String get command_edit_chamfer_desc =>
      'Cuts a straight bevel between two lines, or at vertices of a polyline. Pass all=true to chamfer every straight corner. The two distances are measured from the corner back along each segment; omit the second to use the same length on both.';

  @override
  String get command_edit_break_desc =>
      'Splits a line, polyline or arc at a point, or removes the portion between two points. A bulge is split into two smaller arcs. A circle needs two points and keeps the counter-clockwise remnant from the second pick back to the first. Omit the second point to only split (arcs and open chains).';

  @override
  String get command_edit_lengthen_desc =>
      'Changes the length of a line, open polyline or arc by moving the end you pick. A bulge grows or shrinks along its arc. Supply a total length, or a signed delta to add to the current length. An arc cannot be closed into a full circle.';

  @override
  String get command_edit_explode_desc =>
      'Breaks polylines into their segments, block references into copies of their contents, and dimensions into the lines, arrows and text they draw.';

  @override
  String get command_edit_block_desc =>
      'Defines a named block from selected objects and replaces them with one insert at the base point, so the drawing looks the same and the definition can be inserted again.';

  @override
  String get command_edit_insert_desc =>
      'Places one or more references to a named block. Scale is uniform; rotation is in degrees. Pass a points array to stamp the same block at several locations.';

  @override
  String get command_edit_minsert_desc =>
      'Places a rectangular array of a named block as one insert. The copies stay one object, so moving the insert moves the whole grid.';

  @override
  String get command_block_purge_desc =>
      'Deletes named block definitions that no insert references. Nested unused definitions are removed in the same pass, so a block that only existed inside another unused block is cleared too. Xrefs and layout blocks are left alone.';

  @override
  String get command_block_rename_desc =>
      'Renames a block definition and every insert that still points at the old name. Layout blocks, anonymous blocks and xrefs cannot be renamed.';

  @override
  String get command_edit_join_desc =>
      'Joins selected lines, arcs and open polylines whose endpoints meet into a single polyline. A piece is reversed when that is how it touches the chain; a loop whose ends meet is stored closed.';

  @override
  String get command_edit_close_desc =>
      'Closes the selected open polylines by connecting the last vertex back to the first. Already-closed polylines are left alone.';

  @override
  String get command_edit_open_desc =>
      'Opens the selected closed polylines by dropping the closing segment. The vertices stay; only the loop is broken.';

  @override
  String get command_edit_polyline_width_desc =>
      'Sets the constant width of selected polylines. Zero is a hairline; a donut is the same field, so this is how a wide stroke is edited after it is drawn.';

  @override
  String get command_edit_hatch_desc =>
      'Changes the pattern, scale or angle of selected hatches. Omit a field to leave it. Angle is in degrees.';

  @override
  String get command_edit_to_polyline_desc =>
      'Turns selected lines into two-vertex polylines so they can be closed, opened or reversed as a chain.';

  @override
  String get command_edit_reverse_desc =>
      'Reverses the direction of selected lines and polylines. The drawn shape stays the same; start and end swap, which matters for linetypes and for commands that follow a chain.';

  @override
  String get command_edit_undo_desc => 'Reverses the most recent change.';

  @override
  String get command_edit_redo_desc =>
      'Re-applies the most recently undone change.';

  @override
  String get command_edit_change_layer_desc =>
      'Moves the selected objects onto a different layer.';

  @override
  String get command_edit_change_color_desc =>
      'Sets the colour of the selected objects. Accepts an AutoCAD Color Index (1-255), a #rrggbb value, or ByLayer.';

  @override
  String get command_edit_change_linetype_desc =>
      'Sets the linetype of the selected objects. Stock names (DASHED, HIDDEN, CENTER, PHANTOM, DOT, DASHDOT, DIVIDE, Continuous) are added to the drawing if they are not there yet. ByLayer and ByBlock inherit instead.';

  @override
  String get command_edit_change_lineweight_desc =>
      'Sets the lineweight of the selected objects. Accepts a millimetre value (0.25), hundredths (25), ByLayer, ByBlock, Default or hairline.';

  @override
  String get command_edit_dimension_text_desc =>
      'Overrides the text of selected dimensions. Empty restores the measured value; <> stands for that value; a single space hides the text.';

  @override
  String get command_edit_dim_tedit_desc =>
      'Moves the text of selected dimensions to a new point. On a linear dimension the dimension line follows without flipping width and height; aligned, radial and angular dimensions keep their type.';

  @override
  String get command_edit_text_content_desc =>
      'Changes the content of selected text, mtext, dimensions, attributes or leaders. On a dimension, empty restores the measured value and <> stands for that value, same as DIMEDIT.';

  @override
  String get command_edit_text_object_desc =>
      'Updates content, height, colour, justification, rotation, style, column width, width factor or oblique of selected text, mtext, attributes or leaders in one undo. Dimension text height is a dimstyle property and is ignored.';

  @override
  String get command_edit_justify_text_desc =>
      'Changes the justification of selected text or mtext and moves the insertion point so the letters stay where they are. Align and Fit are not offered; they need a second point.';

  @override
  String get command_edit_match_prop_desc =>
      'Copies layer, colour, linetype, lineweight and the other display properties from a source object onto the destination objects. Visibility is left alone so isolate and hide stay intact.';

  @override
  String get command_edit_attedit_desc =>
      'Changes the values on a block reference. Constant tags stay as the definition wrote them.';

  @override
  String get command_view_zoom_extents_desc =>
      'Fits the whole drawing in the window.';

  @override
  String get command_view_zoom_window_desc =>
      'Zooms to a rectangle you specify.';

  @override
  String get command_view_zoom_in_desc =>
      'Magnifies the view about its centre.';

  @override
  String get command_view_zoom_out_desc => 'Shrinks the view about its centre.';

  @override
  String get command_view_zoom_selected_desc =>
      'Fits the selected objects in the window.';

  @override
  String get command_view_regen_desc =>
      'Rebuilds the display list, discarding cached curve tessellations.';

  @override
  String get command_view_units_desc =>
      'Sets the drawing insertion units written to \$INSUNITS. Coordinates stay in these units; the value is what importers and queries use to convert.';

  @override
  String get command_workbench_preferences_desc =>
      'Opens the application settings dialog.';

  @override
  String get command_select_all_desc =>
      'Selects every selectable object in the current space.';

  @override
  String get command_select_none_desc => 'Clears the selection.';

  @override
  String get command_select_invert_desc =>
      'Selects everything that is not currently selected.';

  @override
  String get command_select_similar_desc =>
      'Extends the selection to every object of the same type and layer.';

  @override
  String get command_select_by_layer_desc =>
      'Selects every object on a named layer.';

  @override
  String get command_select_by_color_desc =>
      'Selects every object whose stored colour matches an ACI, #rrggbb, ByLayer or ByBlock. Layer-inherited red is not the same as ACI 1.';

  @override
  String get command_select_by_linetype_desc =>
      'Selects every object whose stored linetype matches a name, ByLayer or ByBlock. Layer-inherited DASHED is not the same as DASHED.';

  @override
  String get command_select_by_lineweight_desc =>
      'Selects every object whose stored lineweight matches a millimetre value, hundredths, ByLayer, ByBlock, Default or hairline. Layer-inherited 0.25 mm is not the same as 25.';

  @override
  String get command_select_by_type_desc =>
      'Selects every object of one entity kind in the current space. LINE, CIRCLE, INSERT, DIMENSION and the other FanCAD kinds work; LWPOLYLINE and BLOCK are accepted as polyline and insert.';

  @override
  String get command_select_by_block_desc =>
      'Selects every insert of a named block in the current space. The name is case-insensitive, the same way INSERT and RENAME look it up.';

  @override
  String get command_view_isolate_objects_desc =>
      'Hides every object in the current space except the selection, so the rest of the drawing is out of the way without being deleted.';

  @override
  String get command_view_hide_objects_desc =>
      'Hides the selected objects without deleting them.';

  @override
  String get command_view_unisolate_objects_desc =>
      'Shows every object that Isolate or Hide had turned off in the current space.';

  @override
  String get command_layer_new_desc => 'Creates a layer and makes it current.';

  @override
  String get command_layer_set_current_desc =>
      'Chooses the layer new objects are created on.';

  @override
  String get command_layer_toggle_visible_desc => 'Turns a layer on or off.';

  @override
  String get command_layer_isolate_desc =>
      'Turns off every layer except the named one.';

  @override
  String get command_layer_show_all_desc => 'Turns every layer back on.';

  @override
  String get command_layer_toggle_lock_desc =>
      'Locks or unlocks a layer. Objects on a locked layer stay visible but cannot be modified.';

  @override
  String get command_layer_delete_desc =>
      'Deletes a layer and everything on it. The layer named 0 cannot be deleted.';

  @override
  String get command_layer_purge_desc =>
      'Deletes layers that no object uses. Layer 0 is kept, and if the current layer is empty it is switched back to 0 before the purge.';

  @override
  String get command_query_summary_desc =>
      'Returns a compact statistical summary of the drawing: extents, entity counts by type, and per-layer counts. Use this first to understand a drawing before querying its contents.';

  @override
  String get command_query_list_desc =>
      'Reports the full properties of the selected objects.';

  @override
  String get command_query_entities_desc =>
      'Finds entities matching optional filters and returns their ids and properties. Use layer, kind and a bounding window to narrow a large drawing to the part you care about.';

  @override
  String get command_query_selection_desc =>
      'Returns the current selection as structured records (id, kind, layer, bounds, short geometry). Use this instead of guessing ids. An empty selection is a successful empty list, not a prompt.';

  @override
  String get command_query_viewport_desc =>
      'Returns the active camera: centre, scale and visible window as [minX, minY, maxX, maxY]. Pass that window to query.entities to list what the user is looking at.';

  @override
  String get command_query_id_desc =>
      'Reports the X and Y coordinates of a point. Use this when you need a location, not a distance between two locations.';

  @override
  String get command_query_distance_desc =>
      'Measures the distance and angle between two points.';

  @override
  String get command_query_angle_desc =>
      'Measures the angle at a vertex between two rays. The first point is the vertex; the next two define the sides.';

  @override
  String get command_query_area_desc =>
      'Reports the area and perimeter of the selected closed objects.';

  @override
  String get command_query_layers_desc =>
      'Returns every layer with its state and object count.';

  @override
  String get command_layout_list_desc =>
      'Lists model and paper-space layouts and their viewports.';

  @override
  String get command_layout_set_desc =>
      'Switches the active layout (Model or a paper tab).';

  @override
  String get command_layout_new_desc =>
      'Adds a paper-space layout tab and opens it. The sheet defaults to A4 landscape; pass width and height in millimetres to override.';

  @override
  String get command_layout_delete_desc =>
      'Removes a paper-space layout tab and the entities on that sheet. Model cannot be deleted. Omit the name to delete the current tab.';

  @override
  String get command_layout_copy_desc =>
      'Duplicates a paper layout: sheet size, viewports, and the entities on that sheet. Model cannot be copied.';

  @override
  String get command_layout_rename_desc =>
      'Renames a paper layout tab. The sheet, viewports and paper entities stay put. Model cannot be renamed.';

  @override
  String get command_layout_order_desc =>
      'Moves a paper tab in the layout strip. Model stays first. index is the destination among paper tabs (0 = first paper). Or pass before / after another tab name.';

  @override
  String get command_layout_pagesetup_desc =>
      'Changes the paper size of a layout, in millimetres, the plot rotation (0, 90, 180 or 270), scale or fit-to-sheet, an offset, and an optional plot window. Omit the name to edit the current paper tab. Model has no sheet.';

  @override
  String get command_layout_mview_desc =>
      'Cuts a window on the current paper layout that looks into model space. The model is framed in the rectangle unless a scale is supplied.';

  @override
  String get command_layout_vpscale_desc =>
      'Sets the scale of a paper viewport (model units per paper unit). Pass fit=true to frame the model again. A locked viewport is refused.';

  @override
  String get command_layout_vplock_desc =>
      'Locks or unlocks a paper viewport so VPSCALE cannot change the view. Omit locked to toggle. The window frame can still move.';

  @override
  String get command_layout_vpon_desc =>
      'Turns a paper viewport on or off. An off window keeps its frame but hides the model and is skipped when plotting. Omit on to toggle.';

  @override
  String get command_layout_vplayer_desc =>
      'Freezes or thaws layers in one paper viewport. Other windows and model space keep their own visibility. Omit freeze to freeze.';

  @override
  String get command_layout_vpmax_desc =>
      'Opens model space framed to a paper viewport so the model can be edited through that window. VPMIN returns to the sheet.';

  @override
  String get command_layout_vpmin_desc =>
      'Returns to the paper layout left by VPMAX and frames the sheet.';

  @override
  String get command_print_export_svg_desc =>
      'Plots a layout to an SVG file. Omit the layout name to plot the current tab. A .pdf path writes a vector PDF instead. Pass corner1 and corner2 to plot a window; otherwise the layout\'s stored plot window or the full sheet is used.';

  @override
  String get command_print_export_pdf_desc =>
      'Plots a layout to a vector PDF. Omit the layout name to plot the current tab. Paper size becomes the page MediaBox; viewports are clipped. Pass corner1 and corner2 to plot a window.';

  @override
  String get command_xref_attach_desc =>
      'Loads another drawing as an external reference and places it in model space. Reload by attaching the same path again; existing inserts keep their position.';

  @override
  String get command_xref_reload_desc =>
      'Re-reads attached external references from their stored paths. Omit the name to reload the selected xref, or the only xref in the drawing.';

  @override
  String get command_xref_detach_desc =>
      'Removes an external reference and every insert that shows it. Omit the name to detach the selected xref, or the only xref in the drawing.';

  @override
  String get command_xref_bind_desc =>
      'Turns an external reference into a local block so the drawing no longer depends on that file. Inserts stay where they are. Omit the name to bind the selected xref, or the only xref in the drawing.';

  @override
  String get command_plugins_list_desc =>
      'Lists installed extensions with their state, version and the commands they contribute.';

  @override
  String get command_plugins_reload_desc =>
      'Re-reads an extension from disk and re-evaluates it, picking up both code and manifest changes without restarting.';

  @override
  String get command_plugins_enable_desc =>
      'Loads an extension so it can contribute commands again.';

  @override
  String get command_plugins_disable_desc =>
      'Unloads an extension and stops it activating again until enabled.';

  @override
  String get command_plugins_logs_desc =>
      'Prints what an extension logged, for diagnosing a failure.';

  @override
  String get command_plugins_scaffold_desc =>
      'Writes a new extension folder with a manifest and a working main.js, then loads it. Returns the paths written.';

  @override
  String get command_plugins_write_desc =>
      'Overwrites one file inside an extension folder. Paths are confined to that folder.';

  @override
  String get command_plugins_read_desc =>
      'Reads one file from an extension folder.';

  @override
  String get command_plugins_typings_desc =>
      'Regenerates fancad.d.ts from the live command registry, so editors and models see the real API surface.';

  @override
  String get command_plugins_edit_desc =>
      'Opens an extension file in the built-in editor so a person can review or change what the AI authoring loop wrote.';

  @override
  String get command_plugins_eval_desc =>
      'Runs a JavaScript expression inside an extension scope. For debugging; it can do anything the extension can.';

  @override
  String command_step(String verb, String step) {
    return '$verb  $step';
  }

  @override
  String get prompt_specify_first_point => 'Specify first point:';

  @override
  String get prompt_specify_next_point_esc =>
      'Specify next point (Escape to finish):';

  @override
  String get prompt_specify_second_point => 'Specify second point:';

  @override
  String get prompt_specify_second_point_esc =>
      'Specify second point (Escape to finish):';

  @override
  String get prompt_specify_base_point => 'Specify base point:';

  @override
  String get prompt_select_objects => 'Select objects:';

  @override
  String get prompt_specify_center => 'Specify center:';

  @override
  String get prompt_specify_center_point => 'Specify center point:';

  @override
  String get prompt_specify_radius => 'Specify radius:';

  @override
  String get prompt_specify_first_corner => 'Specify first corner:';

  @override
  String get prompt_specify_opposite_corner => 'Specify opposite corner:';

  @override
  String get prompt_specify_insertion_point => 'Specify insertion point:';

  @override
  String get prompt_specify_next_insertion_esc =>
      'Specify next insertion point (Escape to finish):';

  @override
  String get prompt_specify_height => 'Specify height:';

  @override
  String get prompt_specify_start_point => 'Specify start point:';

  @override
  String get prompt_specify_through_point => 'Specify through point:';

  @override
  String get prompt_specify_end_point => 'Specify end point:';

  @override
  String get prompt_specify_a_point => 'Specify a point:';

  @override
  String get prompt_specify_a_location => 'Specify a location:';

  @override
  String get prompt_specify_point => 'Specify point:';

  @override
  String get prompt_specify_vertex => 'Specify vertex:';

  @override
  String get prompt_specify_dim_line => 'Specify dimension line location:';

  @override
  String get prompt_specify_first_ext_origin =>
      'Specify first extension line origin:';

  @override
  String get prompt_specify_second_ext_origin =>
      'Specify second extension line origin:';

  @override
  String get prompt_specify_next_ext_origin =>
      'Specify next extension line origin:';

  @override
  String get prompt_specify_second_ext_origin_alt =>
      'Specify a second extension line origin:';

  @override
  String get prompt_specify_dim_arc => 'Specify dimension arc location:';

  @override
  String get prompt_specify_rotation_angle => 'Specify rotation angle:';

  @override
  String get prompt_specify_new_height => 'Specify new height:';

  @override
  String get prompt_specify_width_factor => 'Specify width factor:';

  @override
  String get prompt_specify_oblique => 'Specify oblique angle:';

  @override
  String get prompt_specify_column_width => 'Specify column width:';

  @override
  String get prompt_specify_attachment_point => 'Specify attachment point:';

  @override
  String get prompt_specify_scale_factor =>
      'Specify scale factor (or pick a distance):';

  @override
  String get prompt_specify_offset_distance => 'Specify offset distance:';

  @override
  String get prompt_specify_offset_side =>
      'Specify a point on the side to offset:';

  @override
  String get prompt_specify_fillet_radius => 'Specify fillet radius:';

  @override
  String get prompt_specify_inside_diameter => 'Specify inside diameter:';

  @override
  String get prompt_specify_outside_diameter => 'Specify outside diameter:';

  @override
  String get prompt_specify_center_of_donut => 'Specify center of donut:';

  @override
  String get prompt_specify_total_length => 'Specify total length:';

  @override
  String get prompt_specify_segment_length => 'Specify segment length:';

  @override
  String get prompt_specify_stretch_point => 'Specify stretch point:';

  @override
  String get prompt_idle_select => 'Select objects or specify a command:';

  @override
  String get prompt_enter_layer_name => 'Enter layer name:';

  @override
  String get prompt_enter_a_layer_name => 'Enter a layer name:';

  @override
  String get prompt_extension_id => 'Extension id:';

  @override
  String get prompt_enter_block_name => 'Enter block name:';

  @override
  String get prompt_enter_text => 'Enter the text:';

  @override
  String get prompt_select_closed_objects => 'Select closed objects:';

  @override
  String get prompt_select_viewport => 'Select viewport:';

  @override
  String get prompt_selected_viewport => 'Selected viewport';

  @override
  String get prompt_enter_colour =>
      'Enter a colour (1-255, #rrggbb or ByLayer):';

  @override
  String get prompt_javascript => 'JavaScript:';

  @override
  String get prompt_svg_path => 'SVG path:';

  @override
  String get prompt_pdf_path => 'PDF path:';

  @override
  String get prompt_layout_name => 'Layout name:';

  @override
  String get prompt_layout_to_copy => 'Layout to copy:';

  @override
  String get prompt_layout_to_delete => 'Layout to delete:';

  @override
  String get prompt_layout_to_move => 'Layout to move:';

  @override
  String get prompt_layout_to_rename => 'Layout to rename:';

  @override
  String get prompt_drawing_to_attach => 'Drawing to attach:';

  @override
  String get prompt_file_to_write => 'File to write:';

  @override
  String get prompt_file_to_read => 'File to read:';

  @override
  String get prompt_select_objects_to_erase => 'Select objects to erase:';

  @override
  String get prompt_select_objects_to_array => 'Select objects to array:';

  @override
  String get prompt_select_objects_to_align => 'Select objects to align:';

  @override
  String get prompt_select_objects_to_rotate => 'Select objects to rotate:';

  @override
  String get prompt_select_objects_to_scale => 'Select objects to scale:';

  @override
  String get prompt_select_objects_to_mirror => 'Select objects to mirror:';

  @override
  String get prompt_select_objects_to_offset => 'Select objects to offset:';

  @override
  String get prompt_select_objects_to_explode => 'Select objects to explode:';

  @override
  String get prompt_select_objects_to_hide => 'Select objects to hide:';

  @override
  String get prompt_select_objects_keep_visible =>
      'Select objects to keep visible:';

  @override
  String get prompt_select_objects_recolour => 'Select objects to recolour:';

  @override
  String get prompt_select_objects_change_layer =>
      'Select objects to move to another layer:';

  @override
  String get prompt_select_text_objects => 'Select text objects:';

  @override
  String get prompt_textobject_options =>
      'Specify text, height, colour, justification, rotation, style, column width, width factor or oblique:';

  @override
  String prompt_place_n_points(int count) {
    return 'Place $count point(s)?';
  }

  @override
  String prompt_specify_first_kind_point(String kind) {
    return 'Specify first $kind point:';
  }

  @override
  String prompt_specify_next_kind_point_esc(String kind) {
    return 'Specify next $kind point (Escape to finish):';
  }

  @override
  String prompt_selected_object(String entity, String layer) {
    return 'Selected $entity on layer $layer';
  }

  @override
  String prompt_objects_selected(int count) {
    return '$count objects selected';
  }

  @override
  String prompt_selection_found(String message, int count) {
    return '$message ($count found, Enter to accept)';
  }

  @override
  String get prompt_enter_annotation_none => 'Enter annotation text <none>:';

  @override
  String get prompt_enter_attribute_tag => 'Enter attribute tag:';

  @override
  String get prompt_enter_block_name_to_change => 'Enter block name to change:';

  @override
  String get prompt_enter_default_value => 'Enter default value:';

  @override
  String get prompt_enter_dimension_text =>
      'Enter dimension text (<> = measured):';

  @override
  String get prompt_enter_justification =>
      'Enter justification [Left/Center/Right/TL/TC/TR/ML/MC/MR/BL/BC/BR]:';

  @override
  String get prompt_enter_layer_names => 'Enter layer name(s):';

  @override
  String get prompt_enter_spline_method => 'Enter method [Control/Fit]:';

  @override
  String get prompt_enter_linetype_name =>
      'Enter name (DASHED, HIDDEN, CENTER, ByLayer):';

  @override
  String get prompt_enter_new_block_name => 'Enter new block name:';

  @override
  String get prompt_enter_new_text => 'Enter new text:';

  @override
  String get prompt_enter_columns => 'Enter number of columns:';

  @override
  String get prompt_enter_items => 'Enter number of items:';

  @override
  String get prompt_enter_rows => 'Enter number of rows:';

  @override
  String get prompt_enter_sides => 'Enter number of sides:';

  @override
  String get prompt_enter_object_type =>
      'Enter object type (LINE, CIRCLE, INSERT, …):';

  @override
  String get prompt_enter_attribute_prompt => 'Enter prompt:';

  @override
  String get prompt_enter_fill_angle => 'Enter the angle to fill:';

  @override
  String get prompt_enter_column_spacing => 'Enter the column spacing:';

  @override
  String get prompt_enter_segments => 'Enter the number of segments:';

  @override
  String get prompt_enter_row_spacing => 'Enter the row spacing:';

  @override
  String get prompt_enter_lineweight => 'Enter weight (0.25 mm, 25, ByLayer):';

  @override
  String get prompt_fillet_vertex_all => 'Fillet [Vertex/All]:';

  @override
  String get prompt_chamfer_vertex_all => 'Chamfer [Vertex/All]:';

  @override
  String get prompt_select_block_reference => 'Select a block reference:';

  @override
  String get prompt_select_line_pline_arc => 'Select a line, polyline or arc:';

  @override
  String get prompt_select_linear_aligned_dim =>
      'Select a linear or aligned dimension:';

  @override
  String get prompt_select_arc_or_circle => 'Select arc or circle:';

  @override
  String get prompt_select_arc_or_first_line => 'Select arc or first line:';

  @override
  String get prompt_select_boundary_edges => 'Select boundary edges:';

  @override
  String get prompt_select_circles_or_arcs => 'Select circles or arcs:';

  @override
  String get prompt_select_closed_boundaries => 'Select closed boundaries:';

  @override
  String get prompt_select_cutting_edges => 'Select cutting edges:';

  @override
  String get prompt_select_destination_objects => 'Select destination objects:';

  @override
  String get prompt_select_dimensions => 'Select dimensions:';

  @override
  String get prompt_select_first_line_circle_arc =>
      'Select first line, circle or arc:';

  @override
  String get prompt_select_first_object => 'Select first object:';

  @override
  String get prompt_select_first_tangent => 'Select first tangent object:';

  @override
  String get prompt_select_hatch_objects => 'Select hatch objects:';

  @override
  String get prompt_select_lines_or_plines => 'Select lines or polylines:';

  @override
  String get prompt_select_lines_to_convert => 'Select lines to convert:';

  @override
  String get prompt_select_join_objects =>
      'Select lines, arcs or polylines to join:';

  @override
  String get prompt_select_object_to_break => 'Select object to break:';

  @override
  String get prompt_select_object_to_divide => 'Select object to divide:';

  @override
  String get prompt_select_object_to_measure => 'Select object to measure:';

  @override
  String get prompt_select_plines_to_close => 'Select polylines to close:';

  @override
  String get prompt_select_plines_to_open => 'Select polylines to open:';

  @override
  String get prompt_select_plines_width => 'Select polylines to set width:';

  @override
  String get prompt_select_second_line_circle_arc =>
      'Select second line, circle or arc:';

  @override
  String get prompt_select_second_line => 'Select second line:';

  @override
  String get prompt_select_second_tangent => 'Select second tangent object:';

  @override
  String get prompt_select_source_object => 'Select source object:';

  @override
  String get prompt_select_text_mtext_dim =>
      'Select text, mtext or a dimension:';

  @override
  String get prompt_specify_nearer_end =>
      'Specify a point nearer the end to change:';

  @override
  String get prompt_specify_first_ray_point =>
      'Specify a point on the first ray:';

  @override
  String get prompt_specify_second_ray_point =>
      'Specify a point on the second ray:';

  @override
  String get prompt_specify_second_point_on_arc =>
      'Specify a second point on the arc:';

  @override
  String get prompt_specify_vertex_to_bevel => 'Specify a vertex to bevel:';

  @override
  String get prompt_specify_vertex_to_round => 'Specify a vertex to round:';

  @override
  String get prompt_specify_column_distance =>
      'Specify distance between columns:';

  @override
  String get prompt_specify_row_distance => 'Specify distance between rows:';

  @override
  String get prompt_specify_other_axis_distance =>
      'Specify distance to other axis:';

  @override
  String get prompt_specify_axis_endpoint => 'Specify endpoint of axis:';

  @override
  String get prompt_specify_first_break => 'Specify first break point:';

  @override
  String get prompt_specify_first_chamfer => 'Specify first chamfer distance:';

  @override
  String get prompt_specify_crossing_first_corner =>
      'Specify first corner of crossing window:';

  @override
  String get prompt_specify_first_dest => 'Specify first destination point:';

  @override
  String get prompt_specify_first_diameter_end =>
      'Specify first end of diameter:';

  @override
  String get prompt_specify_first_leader_point => 'Specify first leader point:';

  @override
  String get prompt_specify_mirror_first =>
      'Specify first point of mirror line:';

  @override
  String get prompt_specify_first_on_circle => 'Specify first point on circle:';

  @override
  String get prompt_specify_first_source => 'Specify first source point:';

  @override
  String get prompt_specify_insertion_base => 'Specify insertion base point:';

  @override
  String get prompt_hatch_internal_or_select =>
      'Specify internal point or [Select]:';

  @override
  String get prompt_specify_dim_text_location =>
      'Specify new location for dimension text:';

  @override
  String get prompt_specify_polyline_width =>
      'Specify new width for all segments:';

  @override
  String get prompt_specify_second_break_esc =>
      'Specify second break point (Escape to split):';

  @override
  String get prompt_specify_second_chamfer =>
      'Specify second chamfer distance:';

  @override
  String get prompt_specify_second_dest => 'Specify second destination point:';

  @override
  String get prompt_specify_second_diameter_end =>
      'Specify second end of diameter:';

  @override
  String get prompt_specify_mirror_second =>
      'Specify second point of mirror line:';

  @override
  String get prompt_specify_second_on_circle =>
      'Specify second point on circle:';

  @override
  String get prompt_specify_second_source_or_enter =>
      'Specify second source point or press Enter:';

  @override
  String get prompt_specify_third_on_circle => 'Specify third point on circle:';

  @override
  String prompt_enter_units(String current) {
    return 'Enter insertion units <$current>:';
  }

  @override
  String get prompt_enter_text_style_name => 'Enter text style name:';

  @override
  String get prompt_enter_layer_to_delete => 'Enter layer to delete:';

  @override
  String get prompt_enter_layer_to_isolate => 'Enter layer to isolate:';

  @override
  String get prompt_enter_linetype => 'Enter a linetype (DASHED, ByLayer, …):';

  @override
  String get prompt_enter_a_lineweight =>
      'Enter a lineweight (0.25 mm, 25, ByLayer):';

  @override
  String get prompt_select_object_to_trim =>
      'Select an object to trim (Escape to finish):';

  @override
  String get prompt_select_object_to_extend =>
      'Select an object to extend (Escape to finish):';

  @override
  String get prompt_scale_objects_align =>
      'Scale objects based on alignment points?';

  @override
  String get prompt_sheet_width => 'Sheet width (mm):';

  @override
  String get prompt_sheet_height => 'Sheet height (mm):';

  @override
  String get prompt_viewport_scale => 'Viewport scale (model / paper):';

  @override
  String get prompt_new_layout_name => 'New layout name:';

  @override
  String get prompt_open_recent => 'Open recent:';

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
