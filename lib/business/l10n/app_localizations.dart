import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// theme
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// theme dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get theme_dark;

  /// theme light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get theme_light;

  /// theme follow operating system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get theme_system;

  /// appearance dark tooltip
  ///
  /// In en, this message translates to:
  /// **'Appearance — Dark. Choose Light, Dark or System'**
  String get appearance_dark_tooltip;

  /// appearance light tooltip
  ///
  /// In en, this message translates to:
  /// **'Appearance — Light. Choose Light, Dark or System'**
  String get appearance_light_tooltip;

  /// settings dialog title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// settings title-bar tooltip
  ///
  /// In en, this message translates to:
  /// **'Settings. Theme, language and assistant'**
  String get settings_tooltip;

  /// settings general tab
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settings_tab_general;

  /// settings assistant tab
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get settings_tab_assistant;

  /// settings MCP tab
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get settings_tab_mcp;

  /// settings appearance section
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_appearance;

  /// settings MCP section
  ///
  /// In en, this message translates to:
  /// **'MCP'**
  String get settings_mcp;

  /// settings MCP enable toggle
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settings_mcp_enable;

  /// settings MCP enabled hint
  ///
  /// In en, this message translates to:
  /// **'Cursor and Claude Desktop connect at the URL below'**
  String get settings_mcp_on;

  /// settings MCP disabled hint
  ///
  /// In en, this message translates to:
  /// **'External MCP clients cannot attach'**
  String get settings_mcp_off;

  /// settings MCP URL label
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get settings_mcp_url;

  /// settings MCP local-only toggle
  ///
  /// In en, this message translates to:
  /// **'Local only'**
  String get settings_mcp_local;

  /// settings MCP local enabled hint
  ///
  /// In en, this message translates to:
  /// **'Only this computer can connect'**
  String get settings_mcp_local_on;

  /// settings MCP local disabled hint
  ///
  /// In en, this message translates to:
  /// **'Other machines can connect; the allowlist is optional'**
  String get settings_mcp_local_off;

  /// settings MCP port
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settings_mcp_port;

  /// settings MCP IP allowlist
  ///
  /// In en, this message translates to:
  /// **'Allowlist'**
  String get settings_mcp_allowlist;

  /// settings MCP allowlist hint
  ///
  /// In en, this message translates to:
  /// **'Optional, comma-separated IPs'**
  String get settings_mcp_allowlist_hint;

  /// settings assistant connection section
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settings_connection;

  /// settings api key
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get settings_api_key;

  /// settings api key env var
  ///
  /// In en, this message translates to:
  /// **'API key environment variable'**
  String get settings_api_key_env;

  /// open settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get open_settings;

  /// new drawing
  ///
  /// In en, this message translates to:
  /// **'New drawing'**
  String get new_drawing;

  /// open
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// open ellipsis
  ///
  /// In en, this message translates to:
  /// **'Open…'**
  String get open_ellipsis;

  /// save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// save as
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get save_as;

  /// save unsaved changes
  ///
  /// In en, this message translates to:
  /// **'Save unsaved changes'**
  String get save_unsaved_changes;

  /// save this drawing
  ///
  /// In en, this message translates to:
  /// **'Save this drawing'**
  String get save_this_drawing;

  /// saved write again
  ///
  /// In en, this message translates to:
  /// **'Saved — {shortcut} to write again'**
  String saved_write_again(String shortcut);

  /// close drawing
  ///
  /// In en, this message translates to:
  /// **'Close drawing'**
  String get close_drawing;

  /// command palette
  ///
  /// In en, this message translates to:
  /// **'Command palette'**
  String get command_palette;

  /// hide assistant
  ///
  /// In en, this message translates to:
  /// **'Hide assistant'**
  String get hide_assistant;

  /// show assistant
  ///
  /// In en, this message translates to:
  /// **'Show assistant'**
  String get show_assistant;

  /// nothing to undo
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get nothing_to_undo;

  /// nothing to redo
  ///
  /// In en, this message translates to:
  /// **'Nothing to redo'**
  String get nothing_to_redo;

  /// undo named
  ///
  /// In en, this message translates to:
  /// **'Undo {label}'**
  String undo_named(String label);

  /// redo named
  ///
  /// In en, this message translates to:
  /// **'Redo {label}'**
  String redo_named(String label);

  /// undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// redo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// more file actions
  ///
  /// In en, this message translates to:
  /// **'More file actions'**
  String get more_file_actions;

  /// recent
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// remove missing
  ///
  /// In en, this message translates to:
  /// **'Remove missing'**
  String get remove_missing;

  /// clear recent
  ///
  /// In en, this message translates to:
  /// **'Clear recent'**
  String get clear_recent;

  /// recent all on disk
  ///
  /// In en, this message translates to:
  /// **'Every recent file is still on disk.'**
  String get recent_all_on_disk;

  /// recent removed one
  ///
  /// In en, this message translates to:
  /// **'Removed 1 missing file from Recent.'**
  String get recent_removed_one;

  /// recent removed many
  ///
  /// In en, this message translates to:
  /// **'Removed {count} missing files from Recent.'**
  String recent_removed_many(int count);

  /// missing path
  ///
  /// In en, this message translates to:
  /// **'Missing — {path}'**
  String missing_path(String path);

  /// missing folder
  ///
  /// In en, this message translates to:
  /// **'Missing · {folder}'**
  String missing_folder(String folder);

  /// show in finder
  ///
  /// In en, this message translates to:
  /// **'Show in Finder'**
  String get show_in_finder;

  /// show in explorer
  ///
  /// In en, this message translates to:
  /// **'Show in Explorer'**
  String get show_in_explorer;

  /// show in folder
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get show_in_folder;

  /// could not reveal
  ///
  /// In en, this message translates to:
  /// **'Could not reveal {path}: {error}'**
  String could_not_reveal(String path, String error);

  /// could not open
  ///
  /// In en, this message translates to:
  /// **'Could not open {path}: {error}'**
  String could_not_open(String path, String error);

  /// copied path
  ///
  /// In en, this message translates to:
  /// **'Copied {path}'**
  String copied_path(String path);

  /// open drawings
  ///
  /// In en, this message translates to:
  /// **'Open drawings ({count})'**
  String open_drawings(int count);

  /// import warnings tooltip
  ///
  /// In en, this message translates to:
  /// **'{count} import warning(s) — click to read'**
  String import_warnings_tooltip(int count);

  /// unsaved drawing
  ///
  /// In en, this message translates to:
  /// **'Unsaved drawing'**
  String get unsaved_drawing;

  /// unsaved changes path
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes — {path}'**
  String unsaved_changes_path(String path);

  /// close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// close unsaved
  ///
  /// In en, this message translates to:
  /// **'Close — unsaved changes'**
  String get close_unsaved;

  /// close others
  ///
  /// In en, this message translates to:
  /// **'Close others'**
  String get close_others;

  /// close all
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get close_all;

  /// copy path
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copy_path;

  /// import warnings
  ///
  /// In en, this message translates to:
  /// **'Import warnings ({count})'**
  String import_warnings(int count);

  /// import warning title one
  ///
  /// In en, this message translates to:
  /// **'1 import warning'**
  String get import_warning_title_one;

  /// import warning title many
  ///
  /// In en, this message translates to:
  /// **'{count} import warnings'**
  String import_warning_title_many(int count);

  /// copied warnings
  ///
  /// In en, this message translates to:
  /// **'Copied {count} warning(s)'**
  String copied_warnings(int count);

  /// copy all
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copy_all;

  /// minimise
  ///
  /// In en, this message translates to:
  /// **'Minimise'**
  String get minimise;

  /// restore
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// maximise
  ///
  /// In en, this message translates to:
  /// **'Maximise'**
  String get maximise;

  /// close window
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get close_window;

  /// layers
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layers;

  /// properties
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get properties;

  /// layouts
  ///
  /// In en, this message translates to:
  /// **'Layouts'**
  String get layouts;

  /// commands
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// extensions
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get extensions;

  /// re editor
  ///
  /// In en, this message translates to:
  /// **'Re-Editor'**
  String get re_editor;

  /// assistant
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get assistant;

  /// view layers hint
  ///
  /// In en, this message translates to:
  /// **'Current layer, visibility and lock'**
  String get view_layers_hint;

  /// view properties hint
  ///
  /// In en, this message translates to:
  /// **'Inspect and change the selection'**
  String get view_properties_hint;

  /// view layouts hint
  ///
  /// In en, this message translates to:
  /// **'Model and paper space tabs'**
  String get view_layouts_hint;

  /// view commands hint
  ///
  /// In en, this message translates to:
  /// **'Everything the application can run'**
  String get view_commands_hint;

  /// view history hint
  ///
  /// In en, this message translates to:
  /// **'Commands that have already run'**
  String get view_history_hint;

  /// view extensions hint
  ///
  /// In en, this message translates to:
  /// **'Installed plugins and their errors'**
  String get view_extensions_hint;

  /// view editor hint
  ///
  /// In en, this message translates to:
  /// **'Review extension source'**
  String get view_editor_hint;

  /// hide view
  ///
  /// In en, this message translates to:
  /// **'Hide {label}'**
  String hide_view(String label);

  /// show sidebar
  ///
  /// In en, this message translates to:
  /// **'Show the sidebar'**
  String get show_sidebar;

  /// hide sidebar
  ///
  /// In en, this message translates to:
  /// **'Hide the sidebar'**
  String get hide_sidebar;

  /// resize reset width
  ///
  /// In en, this message translates to:
  /// **'Drag to resize · double-click to reset width'**
  String get resize_reset_width;

  /// resize collapse
  ///
  /// In en, this message translates to:
  /// **'Drag to resize · double-click to collapse'**
  String get resize_collapse;

  /// resize expand
  ///
  /// In en, this message translates to:
  /// **'Drag to resize · double-click to expand'**
  String get resize_expand;

  /// cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// dont save
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get dont_save;

  /// continue action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continue_action;

  /// filter commands
  ///
  /// In en, this message translates to:
  /// **'Filter by name, alias or category'**
  String get filter_commands;

  /// clear filter
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get clear_filter;

  /// no commands registered
  ///
  /// In en, this message translates to:
  /// **'No commands are registered.'**
  String get no_commands_registered;

  /// no commands match
  ///
  /// In en, this message translates to:
  /// **'No commands match “{query}”.'**
  String no_commands_match(String query);

  /// last used
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get last_used;

  /// commands count one
  ///
  /// In en, this message translates to:
  /// **'1 command'**
  String get commands_count_one;

  /// commands count many
  ///
  /// In en, this message translates to:
  /// **'{count} commands'**
  String commands_count_many(int count);

  /// commands matching
  ///
  /// In en, this message translates to:
  /// **' matching'**
  String get commands_matching;

  /// alias named
  ///
  /// In en, this message translates to:
  /// **'Alias {alias}'**
  String alias_named(String alias);

  /// copy and dismiss
  ///
  /// In en, this message translates to:
  /// **'Click to copy and dismiss'**
  String get copy_and_dismiss;

  /// dismiss
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// search commands
  ///
  /// In en, this message translates to:
  /// **'Search commands, aliases or categories'**
  String get search_commands;

  /// clear search
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clear_search;

  /// start typing command
  ///
  /// In en, this message translates to:
  /// **'Start typing to find a command.'**
  String get start_typing_command;

  /// try alias or category
  ///
  /// In en, this message translates to:
  /// **'Try an alias such as L, C or M, or a category like Draw.'**
  String get try_alias_or_category;

  /// palette hints
  ///
  /// In en, this message translates to:
  /// **'↑↓  move   Enter  run   Esc  close'**
  String get palette_hints;

  /// last badge
  ///
  /// In en, this message translates to:
  /// **'Last'**
  String get last_badge;

  /// empty tagline
  ///
  /// In en, this message translates to:
  /// **'An AI-native, plugin-everything 2D CAD'**
  String get empty_tagline;

  /// open drawing file
  ///
  /// In en, this message translates to:
  /// **'Open a DWG, DXF or FCB file'**
  String get open_drawing_file;

  /// show all commands
  ///
  /// In en, this message translates to:
  /// **'Show all commands'**
  String get show_all_commands;

  /// command history hint
  ///
  /// In en, this message translates to:
  /// **'Command history will appear here. Click a line to reuse it, or press ↑ to recall the last thing you typed.'**
  String get command_history_hint;

  /// collapse history
  ///
  /// In en, this message translates to:
  /// **'Collapse command history'**
  String get collapse_history;

  /// expand history
  ///
  /// In en, this message translates to:
  /// **'Expand command history'**
  String get expand_history;

  /// copied history
  ///
  /// In en, this message translates to:
  /// **'Copied command history'**
  String get copied_history;

  /// hint click or type
  ///
  /// In en, this message translates to:
  /// **'Click in the drawing, or type a value'**
  String get hint_click_or_type;

  /// hint type command
  ///
  /// In en, this message translates to:
  /// **'Type a command'**
  String get hint_type_command;

  /// command history
  ///
  /// In en, this message translates to:
  /// **'Command history'**
  String get command_history;

  /// copy history
  ///
  /// In en, this message translates to:
  /// **'Copy history'**
  String get copy_history;

  /// clear history
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clear_history;

  /// snap
  ///
  /// In en, this message translates to:
  /// **'SNAP'**
  String get snap;

  /// ortho
  ///
  /// In en, this message translates to:
  /// **'ORTHO'**
  String get ortho;

  /// polar
  ///
  /// In en, this message translates to:
  /// **'POLAR'**
  String get polar;

  /// grid
  ///
  /// In en, this message translates to:
  /// **'GRID'**
  String get grid;

  /// snap tooltip
  ///
  /// In en, this message translates to:
  /// **'Object snapping (F3). Right-click to choose Endpoint, Midpoint…'**
  String get snap_tooltip;

  /// ortho tooltip
  ///
  /// In en, this message translates to:
  /// **'Constrain to horizontal and vertical (F8)'**
  String get ortho_tooltip;

  /// polar tooltip
  ///
  /// In en, this message translates to:
  /// **'Polar tracking (F10) — {degrees}°. Right-click to change the increment'**
  String polar_tooltip(int degrees);

  /// grid tooltip
  ///
  /// In en, this message translates to:
  /// **'Reference grid (F7)'**
  String get grid_tooltip;

  /// selected count
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selected_count(int count);

  /// nothing selected
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get nothing_selected;

  /// open properties selection
  ///
  /// In en, this message translates to:
  /// **'Open properties for the selection'**
  String get open_properties_selection;

  /// objects count
  ///
  /// In en, this message translates to:
  /// **'{count} objects'**
  String objects_count(int count);

  /// drawing empty
  ///
  /// In en, this message translates to:
  /// **'The drawing is empty'**
  String get drawing_empty;

  /// select every object
  ///
  /// In en, this message translates to:
  /// **'Select every object'**
  String get select_every_object;

  /// zoom extents tooltip
  ///
  /// In en, this message translates to:
  /// **'Zoom extents — fit the drawing in the window'**
  String get zoom_extents_tooltip;

  /// scene stats tooltip
  ///
  /// In en, this message translates to:
  /// **'Batches drawn / entities visible in the viewport'**
  String get scene_stats_tooltip;

  /// draw calls visible
  ///
  /// In en, this message translates to:
  /// **'{calls} draw calls · {visible} visible'**
  String draw_calls_visible(int calls, int visible);

  /// restore defaults
  ///
  /// In en, this message translates to:
  /// **'Restore defaults'**
  String get restore_defaults;

  /// layer hidden
  ///
  /// In en, this message translates to:
  /// **'hidden'**
  String get layer_hidden;

  /// layer locked
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get layer_locked;

  /// current layer named
  ///
  /// In en, this message translates to:
  /// **'Current layer \"{name}\"'**
  String current_layer_named(String name);

  /// current layer hint
  ///
  /// In en, this message translates to:
  /// **'Click to manage layers. Right-click to turn on or unlock'**
  String get current_layer_hint;

  /// turn layer on
  ///
  /// In en, this message translates to:
  /// **'Turn layer on'**
  String get turn_layer_on;

  /// turn layer off
  ///
  /// In en, this message translates to:
  /// **'Turn layer off'**
  String get turn_layer_off;

  /// unlock layer
  ///
  /// In en, this message translates to:
  /// **'Unlock layer'**
  String get unlock_layer;

  /// lock layer
  ///
  /// In en, this message translates to:
  /// **'Lock layer'**
  String get lock_layer;

  /// manage layers
  ///
  /// In en, this message translates to:
  /// **'Manage layers'**
  String get manage_layers;

  /// cursor
  ///
  /// In en, this message translates to:
  /// **'Cursor'**
  String get cursor;

  /// use as next point
  ///
  /// In en, this message translates to:
  /// **'Use {text} as the next point'**
  String use_as_next_point(String text);

  /// copy text
  ///
  /// In en, this message translates to:
  /// **'Copy {text}'**
  String copy_text(String text);

  /// copied text
  ///
  /// In en, this message translates to:
  /// **'Copied {text}'**
  String copied_text(String text);

  /// cancel named
  ///
  /// In en, this message translates to:
  /// **'Cancel {name}'**
  String cancel_named(String name);

  /// erase
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get erase;

  /// move
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get move;

  /// copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// copy to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copy_to_clipboard;

  /// copy with base point
  ///
  /// In en, this message translates to:
  /// **'Copy with base point'**
  String get copy_with_base;

  /// cut
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get cut;

  /// paste
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// paste to original coordinates
  ///
  /// In en, this message translates to:
  /// **'Paste to original coordinates'**
  String get paste_to_original;

  /// paste as block
  ///
  /// In en, this message translates to:
  /// **'Paste as block'**
  String get paste_as_block;

  /// isolate
  ///
  /// In en, this message translates to:
  /// **'Isolate'**
  String get isolate;

  /// hide
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// deselect
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get deselect;

  /// select all
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get select_all;

  /// zoom extents
  ///
  /// In en, this message translates to:
  /// **'Zoom extents'**
  String get zoom_extents;

  /// zoom window
  ///
  /// In en, this message translates to:
  /// **'Zoom window'**
  String get zoom_window;

  /// zoom to selection
  ///
  /// In en, this message translates to:
  /// **'Zoom to selection'**
  String get zoom_to_selection;

  /// show hidden objects
  ///
  /// In en, this message translates to:
  /// **'Show hidden objects'**
  String get show_hidden_objects;

  /// no hidden objects
  ///
  /// In en, this message translates to:
  /// **'No hidden objects'**
  String get no_hidden_objects;

  /// one object hidden
  ///
  /// In en, this message translates to:
  /// **'1 object is hidden'**
  String get one_object_hidden;

  /// many objects hidden
  ///
  /// In en, this message translates to:
  /// **'{count} objects are hidden'**
  String many_objects_hidden(int count);

  /// show all
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get show_all;

  /// one layer off
  ///
  /// In en, this message translates to:
  /// **'1 layer is off'**
  String get one_layer_off;

  /// many layers off
  ///
  /// In en, this message translates to:
  /// **'{count} layers are off'**
  String many_layers_off(int count);

  /// show all layers
  ///
  /// In en, this message translates to:
  /// **'Show all layers'**
  String get show_all_layers;

  /// current layer locked
  ///
  /// In en, this message translates to:
  /// **'Current layer \"{name}\" is locked'**
  String current_layer_locked(String name);

  /// unlock
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// empty drawing title
  ///
  /// In en, this message translates to:
  /// **'This drawing is empty'**
  String get empty_drawing_title;

  /// empty drawing hint
  ///
  /// In en, this message translates to:
  /// **'Start a command from the toolbar, or type an alias such as L or C.'**
  String get empty_drawing_hint;

  /// line alias
  ///
  /// In en, this message translates to:
  /// **'Line  L'**
  String get line_alias;

  /// rectangle alias
  ///
  /// In en, this message translates to:
  /// **'Rectangle  REC'**
  String get rectangle_alias;

  /// circle alias
  ///
  /// In en, this message translates to:
  /// **'Circle  C'**
  String get circle_alias;

  /// restore viewport
  ///
  /// In en, this message translates to:
  /// **'Restore viewport'**
  String get restore_viewport;

  /// rename
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// duplicate
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// new layout
  ///
  /// In en, this message translates to:
  /// **'New layout'**
  String get new_layout;

  /// model space
  ///
  /// In en, this message translates to:
  /// **'Model space'**
  String get model_space;

  /// paper size mm
  ///
  /// In en, this message translates to:
  /// **'{width} × {height} mm'**
  String paper_size_mm(String width, String height);

  /// viewport one
  ///
  /// In en, this message translates to:
  /// **'1 viewport'**
  String get viewport_one;

  /// viewport many
  ///
  /// In en, this message translates to:
  /// **'{count} viewports'**
  String viewport_many(int count);

  /// viewport maximised
  ///
  /// In en, this message translates to:
  /// **'Viewport maximised — click to restore'**
  String get viewport_maximised;

  /// layout right click
  ///
  /// In en, this message translates to:
  /// **'Right-click for rename, duplicate or delete'**
  String get layout_right_click;

  /// delete layout
  ///
  /// In en, this message translates to:
  /// **'Delete layout'**
  String get delete_layout;

  /// new paper layout
  ///
  /// In en, this message translates to:
  /// **'New paper layout'**
  String get new_paper_layout;

  /// click to change
  ///
  /// In en, this message translates to:
  /// **'Click to change {label}'**
  String click_to_change(String label);

  /// click to copy label
  ///
  /// In en, this message translates to:
  /// **'Click to copy {label}'**
  String click_to_copy_label(String label);

  /// layers empty workspace
  ///
  /// In en, this message translates to:
  /// **'Open a drawing to see its layers.'**
  String get layers_empty_workspace;

  /// layouts empty workspace
  ///
  /// In en, this message translates to:
  /// **'Open a drawing to see its layouts.'**
  String get layouts_empty_workspace;

  /// new layer current
  ///
  /// In en, this message translates to:
  /// **'New layer (made current)'**
  String get new_layer_current;

  /// all layers on
  ///
  /// In en, this message translates to:
  /// **'All layers are on'**
  String get all_layers_on;

  /// show hidden layers one
  ///
  /// In en, this message translates to:
  /// **'Show 1 hidden layer'**
  String get show_hidden_layers_one;

  /// show hidden layers many
  ///
  /// In en, this message translates to:
  /// **'Show {count} hidden layers'**
  String show_hidden_layers_many(int count);

  /// filter layers
  ///
  /// In en, this message translates to:
  /// **'Filter layers'**
  String get filter_layers;

  /// no layers
  ///
  /// In en, this message translates to:
  /// **'This drawing has no layers.'**
  String get no_layers;

  /// no layers match
  ///
  /// In en, this message translates to:
  /// **'No layers match “{query}”.'**
  String no_layers_match(String query);

  /// already current
  ///
  /// In en, this message translates to:
  /// **'Already current'**
  String get already_current;

  /// set as current
  ///
  /// In en, this message translates to:
  /// **'Set as current'**
  String get set_as_current;

  /// isolate layer
  ///
  /// In en, this message translates to:
  /// **'Isolate layer'**
  String get isolate_layer;

  /// no objects on layer
  ///
  /// In en, this message translates to:
  /// **'No objects on this layer'**
  String get no_objects_on_layer;

  /// select objects one
  ///
  /// In en, this message translates to:
  /// **'Select 1 object'**
  String get select_objects_one;

  /// select objects many
  ///
  /// In en, this message translates to:
  /// **'Select {count} objects'**
  String select_objects_many(int count);

  /// layer 0 cannot delete
  ///
  /// In en, this message translates to:
  /// **'Layer 0 cannot be deleted'**
  String get layer_0_cannot_delete;

  /// delete layer
  ///
  /// In en, this message translates to:
  /// **'Delete layer'**
  String get delete_layer;

  /// current layer row hint
  ///
  /// In en, this message translates to:
  /// **'Current layer — double-click to isolate, right-click for more'**
  String get current_layer_row_hint;

  /// make current row hint
  ///
  /// In en, this message translates to:
  /// **'Click to make current — double-click to isolate'**
  String get make_current_row_hint;

  /// properties empty workspace
  ///
  /// In en, this message translates to:
  /// **'Open a drawing to inspect its objects.'**
  String get properties_empty_workspace;

  /// clear selection
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clear_selection;

  /// list selection
  ///
  /// In en, this message translates to:
  /// **'List the selection in the command history'**
  String get list_selection;

  /// geometry
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get geometry;

  /// measurements
  ///
  /// In en, this message translates to:
  /// **'Measurements'**
  String get measurements;

  /// layer
  ///
  /// In en, this message translates to:
  /// **'Layer'**
  String get layer;

  /// colour
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get colour;

  /// line type
  ///
  /// In en, this message translates to:
  /// **'Line type'**
  String get line_type;

  /// lineweight
  ///
  /// In en, this message translates to:
  /// **'Lineweight'**
  String get lineweight;

  /// start
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// length
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// angle
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get angle;

  /// centre
  ///
  /// In en, this message translates to:
  /// **'Centre'**
  String get centre;

  /// radius
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get radius;

  /// diameter
  ///
  /// In en, this message translates to:
  /// **'Diameter'**
  String get diameter;

  /// circumference
  ///
  /// In en, this message translates to:
  /// **'Circumference'**
  String get circumference;

  /// start angle
  ///
  /// In en, this message translates to:
  /// **'Start angle'**
  String get start_angle;

  /// end angle
  ///
  /// In en, this message translates to:
  /// **'End angle'**
  String get end_angle;

  /// total angle
  ///
  /// In en, this message translates to:
  /// **'Total angle'**
  String get total_angle;

  /// vertices
  ///
  /// In en, this message translates to:
  /// **'Vertices'**
  String get vertices;

  /// closed
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// no
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// contents
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get contents;

  /// position
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// height
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// rotation
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get rotation;

  /// style
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get style;

  /// justify
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get justify;

  /// width factor
  ///
  /// In en, this message translates to:
  /// **'Width factor'**
  String get width_factor;

  /// oblique
  ///
  /// In en, this message translates to:
  /// **'Oblique'**
  String get oblique;

  /// column width
  ///
  /// In en, this message translates to:
  /// **'Column width'**
  String get column_width;

  /// block
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// scale
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get scale;

  /// pattern
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get pattern;

  /// solid fill
  ///
  /// In en, this message translates to:
  /// **'Solid fill'**
  String get solid_fill;

  /// boundaries
  ///
  /// In en, this message translates to:
  /// **'Boundaries'**
  String get boundaries;

  /// measurement
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get measurement;

  /// text
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// total length
  ///
  /// In en, this message translates to:
  /// **'Total length'**
  String get total_length;

  /// total area
  ///
  /// In en, this message translates to:
  /// **'Total area'**
  String get total_area;

  /// size
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// by layer
  ///
  /// In en, this message translates to:
  /// **'ByLayer'**
  String get by_layer;

  /// by block
  ///
  /// In en, this message translates to:
  /// **'ByBlock'**
  String get by_block;

  /// default value
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get default_value;

  /// hairline
  ///
  /// In en, this message translates to:
  /// **'Hairline'**
  String get hairline;

  /// drawing empty inspect
  ///
  /// In en, this message translates to:
  /// **'This drawing is empty.'**
  String get drawing_empty_inspect;

  /// click object inspect
  ///
  /// In en, this message translates to:
  /// **'Click an object on the canvas to inspect it.'**
  String get click_object_inspect;

  /// nothing to clear
  ///
  /// In en, this message translates to:
  /// **'Nothing to clear'**
  String get nothing_to_clear;

  /// clear conversation
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get clear_conversation;

  /// new chat
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get new_chat;

  /// chat history
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chat_history;

  /// click to change model
  ///
  /// In en, this message translates to:
  /// **'Click to change the model or endpoint'**
  String get click_to_change_model;

  /// assistant profiles
  ///
  /// In en, this message translates to:
  /// **'Configurations'**
  String get assistant_profiles;

  /// add assistant profile
  ///
  /// In en, this message translates to:
  /// **'Add configuration'**
  String get add_assistant_profile;

  /// remove assistant profile
  ///
  /// In en, this message translates to:
  /// **'Remove configuration'**
  String get remove_assistant_profile;

  /// assistant profile name
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get assistant_profile_name;

  /// ask follow up
  ///
  /// In en, this message translates to:
  /// **'Add a follow-up'**
  String get ask_follow_up;

  /// context used
  ///
  /// In en, this message translates to:
  /// **'{used} / {window}'**
  String context_used(String used, String window);

  /// context waiting
  ///
  /// In en, this message translates to:
  /// **'Context size appears after the first reply'**
  String get context_waiting;

  /// auto approve
  ///
  /// In en, this message translates to:
  /// **'Auto-approve deletes'**
  String get auto_approve;

  /// edits without asking
  ///
  /// In en, this message translates to:
  /// **'Deletes run without asking'**
  String get edits_without_asking;

  /// ask before edits
  ///
  /// In en, this message translates to:
  /// **'Ask before the assistant deletes objects'**
  String get ask_before_edits;

  /// custom model
  ///
  /// In en, this message translates to:
  /// **'Custom model…'**
  String get custom_model;

  /// endpoint ellipsis
  ///
  /// In en, this message translates to:
  /// **'Endpoint…'**
  String get endpoint_ellipsis;

  /// model
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// model id
  ///
  /// In en, this message translates to:
  /// **'Any model id, for example deepseek-chat'**
  String get model_id;

  /// endpoint
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// assistant empty configured
  ///
  /// In en, this message translates to:
  /// **'Ask about the drawing, or ask the assistant to change it. It uses the same commands you do, and one reply is one undo step.'**
  String get assistant_empty_configured;

  /// assistant empty unconfigured
  ///
  /// In en, this message translates to:
  /// **'Paste an API key in Settings to talk to a model, or point the endpoint at a local server.'**
  String get assistant_empty_unconfigured;

  /// try section
  ///
  /// In en, this message translates to:
  /// **'Try'**
  String get try_section;

  /// prompt object count
  ///
  /// In en, this message translates to:
  /// **'How many objects are in this drawing?'**
  String get prompt_object_count;

  /// prompt square
  ///
  /// In en, this message translates to:
  /// **'Draw a 100 mm square at the origin'**
  String get prompt_square;

  /// prompt list selection
  ///
  /// In en, this message translates to:
  /// **'List what is selected'**
  String get prompt_list_selection;

  /// click to copy
  ///
  /// In en, this message translates to:
  /// **'Click to copy'**
  String get click_to_copy;

  /// working
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get working;

  /// thinking
  ///
  /// In en, this message translates to:
  /// **'Thinking'**
  String get thinking;

  /// allow one change
  ///
  /// In en, this message translates to:
  /// **'Allow {title}?'**
  String allow_one_change(String title);

  /// allow n changes
  ///
  /// In en, this message translates to:
  /// **'Allow {count} changes?'**
  String allow_n_changes(int count);

  /// affects n objects
  ///
  /// In en, this message translates to:
  /// **'Affects {count} object(s).'**
  String affects_n_objects(int count);

  /// ask assistant
  ///
  /// In en, this message translates to:
  /// **'Ask the assistant  Enter to send'**
  String get ask_assistant;

  /// stop
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// send enter
  ///
  /// In en, this message translates to:
  /// **'Send  Enter'**
  String get send_enter;

  /// open extensions folder
  ///
  /// In en, this message translates to:
  /// **'Open extensions folder'**
  String get open_extensions_folder;

  /// create extension
  ///
  /// In en, this message translates to:
  /// **'Create extension'**
  String get create_extension;

  /// reload all extensions
  ///
  /// In en, this message translates to:
  /// **'Reload all extensions'**
  String get reload_all_extensions;

  /// extensions unavailable
  ///
  /// In en, this message translates to:
  /// **'Extensions are unavailable: no extensions folder was configured for this session.'**
  String get extensions_unavailable;

  /// no extensions installed
  ///
  /// In en, this message translates to:
  /// **'No extensions are installed. Create one, or drop a folder with fancad.plugin.json into the extensions directory.'**
  String get no_extensions_installed;

  /// edit source
  ///
  /// In en, this message translates to:
  /// **'Edit source'**
  String get edit_source;

  /// enable extension
  ///
  /// In en, this message translates to:
  /// **'Enable extension'**
  String get enable_extension;

  /// disable extension
  ///
  /// In en, this message translates to:
  /// **'Disable extension'**
  String get disable_extension;

  /// reload
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// state
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// folder
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// permissions
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// log
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get log;

  /// plugin running
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get plugin_running;

  /// plugin starting
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get plugin_starting;

  /// plugin failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get plugin_failed;

  /// plugin disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get plugin_disabled;

  /// plugin installed
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get plugin_installed;

  /// unsaved editor changes
  ///
  /// In en, this message translates to:
  /// **'Unsaved editor changes'**
  String get unsaved_editor_changes;

  /// editor file dirty
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" has edits that have not been written.'**
  String editor_file_dirty(String name);

  /// nothing to save
  ///
  /// In en, this message translates to:
  /// **'Nothing to save'**
  String get nothing_to_save;

  /// save and reload
  ///
  /// In en, this message translates to:
  /// **'Save and reload'**
  String get save_and_reload;

  /// saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// extension
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get extension;

  /// editor unavailable
  ///
  /// In en, this message translates to:
  /// **'Extensions are unavailable: no extensions folder was configured.'**
  String get editor_unavailable;

  /// create extension first
  ///
  /// In en, this message translates to:
  /// **'Create an extension first, then open it here.'**
  String get create_extension_first;

  /// choose extension
  ///
  /// In en, this message translates to:
  /// **'Choose an extension above, or use Edit source from the Extensions panel.'**
  String get choose_extension;

  /// no such file
  ///
  /// In en, this message translates to:
  /// **'No such file: {name}'**
  String no_such_file(String name);

  /// plugin not installed
  ///
  /// In en, this message translates to:
  /// **'{id} is not installed'**
  String plugin_not_installed(String id);

  /// snap endpoint
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get snap_endpoint;

  /// snap midpoint
  ///
  /// In en, this message translates to:
  /// **'Midpoint'**
  String get snap_midpoint;

  /// snap center
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get snap_center;

  /// snap quadrant
  ///
  /// In en, this message translates to:
  /// **'Quadrant'**
  String get snap_quadrant;

  /// snap intersection
  ///
  /// In en, this message translates to:
  /// **'Intersection'**
  String get snap_intersection;

  /// snap perpendicular
  ///
  /// In en, this message translates to:
  /// **'Perpendicular'**
  String get snap_perpendicular;

  /// snap tangent
  ///
  /// In en, this message translates to:
  /// **'Tangent'**
  String get snap_tangent;

  /// snap node
  ///
  /// In en, this message translates to:
  /// **'Node'**
  String get snap_node;

  /// snap nearest
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get snap_nearest;

  /// category file
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get category_file;

  /// category draw
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get category_draw;

  /// category modify
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get category_modify;

  /// category view
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get category_view;

  /// category select
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get category_select;

  /// category layers
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get category_layers;

  /// category inquiry
  ///
  /// In en, this message translates to:
  /// **'Inquiry'**
  String get category_inquiry;

  /// category output
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get category_output;

  /// category extensions
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get category_extensions;

  /// command file new
  ///
  /// In en, this message translates to:
  /// **'New Drawing'**
  String get command_file_new;

  /// command file open
  ///
  /// In en, this message translates to:
  /// **'Open...'**
  String get command_file_open;

  /// command file save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get command_file_save;

  /// command file save as
  ///
  /// In en, this message translates to:
  /// **'Save As...'**
  String get command_file_save_as;

  /// command file close
  ///
  /// In en, this message translates to:
  /// **'Close Drawing'**
  String get command_file_close;

  /// command file open recent
  ///
  /// In en, this message translates to:
  /// **'Open Recent'**
  String get command_file_open_recent;

  /// command file audit
  ///
  /// In en, this message translates to:
  /// **'Fidelity Audit'**
  String get command_file_audit;

  /// command draw line
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get command_draw_line;

  /// command draw polyline
  ///
  /// In en, this message translates to:
  /// **'Polyline'**
  String get command_draw_polyline;

  /// command draw spline
  ///
  /// In en, this message translates to:
  /// **'Spline'**
  String get command_draw_spline;

  /// command draw rectangle
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get command_draw_rectangle;

  /// command draw circle
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get command_draw_circle;

  /// command draw circle 2p
  ///
  /// In en, this message translates to:
  /// **'Circle (2 Points)'**
  String get command_draw_circle_2p;

  /// command draw circle 3p
  ///
  /// In en, this message translates to:
  /// **'Circle (3 Points)'**
  String get command_draw_circle_3p;

  /// command draw circle ttr
  ///
  /// In en, this message translates to:
  /// **'Circle (Tan Tan Radius)'**
  String get command_draw_circle_ttr;

  /// command draw donut
  ///
  /// In en, this message translates to:
  /// **'Donut'**
  String get command_draw_donut;

  /// command draw arc
  ///
  /// In en, this message translates to:
  /// **'Arc'**
  String get command_draw_arc;

  /// command draw polygon
  ///
  /// In en, this message translates to:
  /// **'Polygon'**
  String get command_draw_polygon;

  /// command draw ellipse
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get command_draw_ellipse;

  /// command draw xline
  ///
  /// In en, this message translates to:
  /// **'Construction Line'**
  String get command_draw_xline;

  /// command draw ray
  ///
  /// In en, this message translates to:
  /// **'Ray'**
  String get command_draw_ray;

  /// command draw point
  ///
  /// In en, this message translates to:
  /// **'Point'**
  String get command_draw_point;

  /// command draw divide
  ///
  /// In en, this message translates to:
  /// **'Divide'**
  String get command_draw_divide;

  /// command draw measure
  ///
  /// In en, this message translates to:
  /// **'Measure'**
  String get command_draw_measure;

  /// command draw text
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get command_draw_text;

  /// command draw mtext
  ///
  /// In en, this message translates to:
  /// **'MText'**
  String get command_draw_mtext;

  /// command draw leader
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get command_draw_leader;

  /// command draw hatch
  ///
  /// In en, this message translates to:
  /// **'Hatch'**
  String get command_draw_hatch;

  /// command draw dim linear
  ///
  /// In en, this message translates to:
  /// **'Linear Dimension'**
  String get command_draw_dim_linear;

  /// command draw dim aligned
  ///
  /// In en, this message translates to:
  /// **'Aligned Dimension'**
  String get command_draw_dim_aligned;

  /// command draw dim radius
  ///
  /// In en, this message translates to:
  /// **'Radius Dimension'**
  String get command_draw_dim_radius;

  /// command draw dim diameter
  ///
  /// In en, this message translates to:
  /// **'Diameter Dimension'**
  String get command_draw_dim_diameter;

  /// command draw center mark
  ///
  /// In en, this message translates to:
  /// **'Center Mark'**
  String get command_draw_center_mark;

  /// command draw center line
  ///
  /// In en, this message translates to:
  /// **'Centerline'**
  String get command_draw_center_line;

  /// command draw dim angular
  ///
  /// In en, this message translates to:
  /// **'Angular Dimension'**
  String get command_draw_dim_angular;

  /// command draw dim continue
  ///
  /// In en, this message translates to:
  /// **'Continue Dimension'**
  String get command_draw_dim_continue;

  /// command draw dim baseline
  ///
  /// In en, this message translates to:
  /// **'Baseline Dimension'**
  String get command_draw_dim_baseline;

  /// command annot dimstyle
  ///
  /// In en, this message translates to:
  /// **'Dimension Style'**
  String get command_annot_dimstyle;

  /// command annot textstyle
  ///
  /// In en, this message translates to:
  /// **'Text Style'**
  String get command_annot_textstyle;

  /// command edit erase
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get command_edit_erase;

  /// command edit overkill
  ///
  /// In en, this message translates to:
  /// **'Overkill'**
  String get command_edit_overkill;

  /// command edit move
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get command_edit_move;

  /// command edit copy
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get command_edit_copy;

  /// command edit copy clip
  ///
  /// In en, this message translates to:
  /// **'Copy to Clipboard'**
  String get command_edit_copy_clip;

  /// command edit copy base
  ///
  /// In en, this message translates to:
  /// **'Copy with Base Point'**
  String get command_edit_copy_base;

  /// command edit cut clip
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get command_edit_cut_clip;

  /// command edit paste clip
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get command_edit_paste_clip;

  /// command edit paste orig
  ///
  /// In en, this message translates to:
  /// **'Paste to Original Coordinates'**
  String get command_edit_paste_orig;

  /// command edit paste block
  ///
  /// In en, this message translates to:
  /// **'Paste as Block'**
  String get command_edit_paste_block;

  /// command edit stretch
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get command_edit_stretch;

  /// command edit rotate
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get command_edit_rotate;

  /// command edit scale
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get command_edit_scale;

  /// command edit mirror
  ///
  /// In en, this message translates to:
  /// **'Mirror'**
  String get command_edit_mirror;

  /// command edit align
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get command_edit_align;

  /// command edit array
  ///
  /// In en, this message translates to:
  /// **'Rectangular Array'**
  String get command_edit_array;

  /// command edit polar array
  ///
  /// In en, this message translates to:
  /// **'Polar Array'**
  String get command_edit_polar_array;

  /// command edit offset
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get command_edit_offset;

  /// command edit trim
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get command_edit_trim;

  /// command edit extend
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get command_edit_extend;

  /// command edit fillet
  ///
  /// In en, this message translates to:
  /// **'Fillet'**
  String get command_edit_fillet;

  /// command edit chamfer
  ///
  /// In en, this message translates to:
  /// **'Chamfer'**
  String get command_edit_chamfer;

  /// command edit break
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get command_edit_break;

  /// command edit lengthen
  ///
  /// In en, this message translates to:
  /// **'Lengthen'**
  String get command_edit_lengthen;

  /// command edit explode
  ///
  /// In en, this message translates to:
  /// **'Explode'**
  String get command_edit_explode;

  /// command edit block
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get command_edit_block;

  /// command edit insert
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get command_edit_insert;

  /// command edit minsert
  ///
  /// In en, this message translates to:
  /// **'MInsert'**
  String get command_edit_minsert;

  /// command block purge
  ///
  /// In en, this message translates to:
  /// **'Purge Unused Blocks'**
  String get command_block_purge;

  /// command block rename
  ///
  /// In en, this message translates to:
  /// **'Rename Block'**
  String get command_block_rename;

  /// command edit join
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get command_edit_join;

  /// command edit close
  ///
  /// In en, this message translates to:
  /// **'Close Polyline'**
  String get command_edit_close;

  /// command edit open
  ///
  /// In en, this message translates to:
  /// **'Open Polyline'**
  String get command_edit_open;

  /// command edit polyline width
  ///
  /// In en, this message translates to:
  /// **'Polyline Width'**
  String get command_edit_polyline_width;

  /// command edit hatch
  ///
  /// In en, this message translates to:
  /// **'Hatch Edit'**
  String get command_edit_hatch;

  /// command edit to polyline
  ///
  /// In en, this message translates to:
  /// **'Convert to Polyline'**
  String get command_edit_to_polyline;

  /// command edit reverse
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get command_edit_reverse;

  /// command edit undo
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get command_edit_undo;

  /// command edit redo
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get command_edit_redo;

  /// command edit change layer
  ///
  /// In en, this message translates to:
  /// **'Change Layer'**
  String get command_edit_change_layer;

  /// command edit change color
  ///
  /// In en, this message translates to:
  /// **'Change Colour'**
  String get command_edit_change_color;

  /// command edit change linetype
  ///
  /// In en, this message translates to:
  /// **'Change Linetype'**
  String get command_edit_change_linetype;

  /// command edit change lineweight
  ///
  /// In en, this message translates to:
  /// **'Change Lineweight'**
  String get command_edit_change_lineweight;

  /// command edit dimension text
  ///
  /// In en, this message translates to:
  /// **'Dimension Text'**
  String get command_edit_dimension_text;

  /// command edit dim tedit
  ///
  /// In en, this message translates to:
  /// **'Move Dimension Text'**
  String get command_edit_dim_tedit;

  /// command edit text content
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get command_edit_text_content;

  /// command edit text object
  ///
  /// In en, this message translates to:
  /// **'Edit Text Object'**
  String get command_edit_text_object;

  /// floating editor title with entity kind and handle
  ///
  /// In en, this message translates to:
  /// **'Edit {entity}'**
  String edit_text_object_window(String entity);

  /// command edit justify text
  ///
  /// In en, this message translates to:
  /// **'Justify Text'**
  String get command_edit_justify_text;

  /// command edit match prop
  ///
  /// In en, this message translates to:
  /// **'Match Properties'**
  String get command_edit_match_prop;

  /// command view zoom extents
  ///
  /// In en, this message translates to:
  /// **'Zoom Extents'**
  String get command_view_zoom_extents;

  /// command view zoom window
  ///
  /// In en, this message translates to:
  /// **'Zoom Window'**
  String get command_view_zoom_window;

  /// command view zoom in
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get command_view_zoom_in;

  /// command view zoom out
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get command_view_zoom_out;

  /// command view zoom selected
  ///
  /// In en, this message translates to:
  /// **'Zoom to Selection'**
  String get command_view_zoom_selected;

  /// command view regen
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get command_view_regen;

  /// command workbench preferences
  ///
  /// In en, this message translates to:
  /// **'Settings...'**
  String get command_workbench_preferences;

  /// command select all
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get command_select_all;

  /// command select none
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get command_select_none;

  /// command select invert
  ///
  /// In en, this message translates to:
  /// **'Invert Selection'**
  String get command_select_invert;

  /// command select similar
  ///
  /// In en, this message translates to:
  /// **'Select Similar'**
  String get command_select_similar;

  /// command select by layer
  ///
  /// In en, this message translates to:
  /// **'Select by Layer'**
  String get command_select_by_layer;

  /// command select by color
  ///
  /// In en, this message translates to:
  /// **'Select by Colour'**
  String get command_select_by_color;

  /// command select by linetype
  ///
  /// In en, this message translates to:
  /// **'Select by Linetype'**
  String get command_select_by_linetype;

  /// command select by lineweight
  ///
  /// In en, this message translates to:
  /// **'Select by Lineweight'**
  String get command_select_by_lineweight;

  /// command select by type
  ///
  /// In en, this message translates to:
  /// **'Select by Type'**
  String get command_select_by_type;

  /// command select by block
  ///
  /// In en, this message translates to:
  /// **'Select by Block'**
  String get command_select_by_block;

  /// command view isolate objects
  ///
  /// In en, this message translates to:
  /// **'Isolate Objects'**
  String get command_view_isolate_objects;

  /// command view hide objects
  ///
  /// In en, this message translates to:
  /// **'Hide Objects'**
  String get command_view_hide_objects;

  /// command view unisolate objects
  ///
  /// In en, this message translates to:
  /// **'Unisolate Objects'**
  String get command_view_unisolate_objects;

  /// command layer new
  ///
  /// In en, this message translates to:
  /// **'New Layer'**
  String get command_layer_new;

  /// command layer set current
  ///
  /// In en, this message translates to:
  /// **'Set Current Layer'**
  String get command_layer_set_current;

  /// command layer toggle visible
  ///
  /// In en, this message translates to:
  /// **'Toggle Layer Visibility'**
  String get command_layer_toggle_visible;

  /// command layer isolate
  ///
  /// In en, this message translates to:
  /// **'Isolate Layer'**
  String get command_layer_isolate;

  /// command layer show all
  ///
  /// In en, this message translates to:
  /// **'Show All Layers'**
  String get command_layer_show_all;

  /// command layer toggle lock
  ///
  /// In en, this message translates to:
  /// **'Toggle Layer Lock'**
  String get command_layer_toggle_lock;

  /// command layer delete
  ///
  /// In en, this message translates to:
  /// **'Delete Layer'**
  String get command_layer_delete;

  /// command layer purge
  ///
  /// In en, this message translates to:
  /// **'Purge Unused Layers'**
  String get command_layer_purge;

  /// command query summary
  ///
  /// In en, this message translates to:
  /// **'Drawing Summary'**
  String get command_query_summary;

  /// command query list
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get command_query_list;

  /// command query entities
  ///
  /// In en, this message translates to:
  /// **'Query Entities'**
  String get command_query_entities;

  /// command query selection
  ///
  /// In en, this message translates to:
  /// **'Query Selection'**
  String get command_query_selection;

  /// command query viewport
  ///
  /// In en, this message translates to:
  /// **'Query Viewport'**
  String get command_query_viewport;

  /// command query id
  ///
  /// In en, this message translates to:
  /// **'ID Point'**
  String get command_query_id;

  /// command query distance
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get command_query_distance;

  /// command query angle
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get command_query_angle;

  /// command query area
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get command_query_area;

  /// command query layers
  ///
  /// In en, this message translates to:
  /// **'List Layers'**
  String get command_query_layers;

  /// command layout list
  ///
  /// In en, this message translates to:
  /// **'List Layouts'**
  String get command_layout_list;

  /// command layout set
  ///
  /// In en, this message translates to:
  /// **'Set Layout'**
  String get command_layout_set;

  /// command layout new
  ///
  /// In en, this message translates to:
  /// **'New Layout'**
  String get command_layout_new;

  /// command layout delete
  ///
  /// In en, this message translates to:
  /// **'Delete Layout'**
  String get command_layout_delete;

  /// command layout copy
  ///
  /// In en, this message translates to:
  /// **'Copy Layout'**
  String get command_layout_copy;

  /// command layout rename
  ///
  /// In en, this message translates to:
  /// **'Rename Layout'**
  String get command_layout_rename;

  /// command layout order
  ///
  /// In en, this message translates to:
  /// **'Layout Order'**
  String get command_layout_order;

  /// command layout pagesetup
  ///
  /// In en, this message translates to:
  /// **'Page Setup'**
  String get command_layout_pagesetup;

  /// command layout mview
  ///
  /// In en, this message translates to:
  /// **'Make Viewport'**
  String get command_layout_mview;

  /// command layout vpscale
  ///
  /// In en, this message translates to:
  /// **'Viewport Scale'**
  String get command_layout_vpscale;

  /// command layout vplock
  ///
  /// In en, this message translates to:
  /// **'Viewport Lock'**
  String get command_layout_vplock;

  /// command layout vpon
  ///
  /// In en, this message translates to:
  /// **'Viewport On'**
  String get command_layout_vpon;

  /// command layout vplayer
  ///
  /// In en, this message translates to:
  /// **'Viewport Layer Freeze'**
  String get command_layout_vplayer;

  /// command layout vpmax
  ///
  /// In en, this message translates to:
  /// **'Maximize Viewport'**
  String get command_layout_vpmax;

  /// command layout vpmin
  ///
  /// In en, this message translates to:
  /// **'Minimize Viewport'**
  String get command_layout_vpmin;

  /// command print export svg
  ///
  /// In en, this message translates to:
  /// **'Export SVG'**
  String get command_print_export_svg;

  /// command print export pdf
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get command_print_export_pdf;

  /// command xref attach
  ///
  /// In en, this message translates to:
  /// **'Attach Xref'**
  String get command_xref_attach;

  /// command xref reload
  ///
  /// In en, this message translates to:
  /// **'Reload Xref'**
  String get command_xref_reload;

  /// command xref detach
  ///
  /// In en, this message translates to:
  /// **'Detach Xref'**
  String get command_xref_detach;

  /// command xref bind
  ///
  /// In en, this message translates to:
  /// **'Bind Xref'**
  String get command_xref_bind;

  /// command plugins list
  ///
  /// In en, this message translates to:
  /// **'List Extensions'**
  String get command_plugins_list;

  /// command plugins reload
  ///
  /// In en, this message translates to:
  /// **'Reload Extension'**
  String get command_plugins_reload;

  /// command plugins enable
  ///
  /// In en, this message translates to:
  /// **'Enable Extension'**
  String get command_plugins_enable;

  /// command plugins disable
  ///
  /// In en, this message translates to:
  /// **'Disable Extension'**
  String get command_plugins_disable;

  /// command plugins logs
  ///
  /// In en, this message translates to:
  /// **'Show Extension Log'**
  String get command_plugins_logs;

  /// command plugins scaffold
  ///
  /// In en, this message translates to:
  /// **'Create Extension'**
  String get command_plugins_scaffold;

  /// command plugins write
  ///
  /// In en, this message translates to:
  /// **'Write Extension File'**
  String get command_plugins_write;

  /// command plugins read
  ///
  /// In en, this message translates to:
  /// **'Read Extension File'**
  String get command_plugins_read;

  /// command plugins typings
  ///
  /// In en, this message translates to:
  /// **'Write Plugin API Typings'**
  String get command_plugins_typings;

  /// command plugins edit
  ///
  /// In en, this message translates to:
  /// **'Edit Extension File'**
  String get command_plugins_edit;

  /// command plugins eval
  ///
  /// In en, this message translates to:
  /// **'Evaluate In Extension'**
  String get command_plugins_eval;

  /// command file list
  ///
  /// In en, this message translates to:
  /// **'List Drawings'**
  String get command_file_list;

  /// command file activate
  ///
  /// In en, this message translates to:
  /// **'Activate Drawing'**
  String get command_file_activate;

  /// command draw attdef
  ///
  /// In en, this message translates to:
  /// **'Attribute Definition'**
  String get command_draw_attdef;

  /// command edit attedit
  ///
  /// In en, this message translates to:
  /// **'Edit Attributes'**
  String get command_edit_attedit;

  /// command view units
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get command_view_units;

  /// command file new desc
  ///
  /// In en, this message translates to:
  /// **'Creates an empty drawing in a new tab.'**
  String get command_file_new_desc;

  /// command file open desc
  ///
  /// In en, this message translates to:
  /// **'Opens a DWG or DXF file.'**
  String get command_file_open_desc;

  /// command file save desc
  ///
  /// In en, this message translates to:
  /// **'Saves the drawing this command is targeting, asking for a path when it has never been saved.'**
  String get command_file_save_desc;

  /// command file save as desc
  ///
  /// In en, this message translates to:
  /// **'Saves the drawing this command is targeting to a new file.'**
  String get command_file_save_as_desc;

  /// command file close desc
  ///
  /// In en, this message translates to:
  /// **'Closes the drawing this command is targeting.'**
  String get command_file_close_desc;

  /// command file open recent desc
  ///
  /// In en, this message translates to:
  /// **'Reopens a recently used file.'**
  String get command_file_open_recent_desc;

  /// command file audit desc
  ///
  /// In en, this message translates to:
  /// **'Writes the drawing to a temp DXF and reports anything a round trip would lose.'**
  String get command_file_audit_desc;

  /// command file list desc
  ///
  /// In en, this message translates to:
  /// **'Lists every open drawing tab: id, title, path, dirty, whether it is active, entity count, and the current layout. Use the id as the fancad tab selector to operate on a drawing without switching the UI.'**
  String get command_file_list_desc;

  /// command file activate desc
  ///
  /// In en, this message translates to:
  /// **'Brings an open drawing to the front. Pass id from file.list, or a unique path or title.'**
  String get command_file_activate_desc;

  /// command draw line desc
  ///
  /// In en, this message translates to:
  /// **'Draws one or more connected straight line segments. Supply start and end to draw a single segment non-interactively.'**
  String get command_draw_line_desc;

  /// command draw polyline desc
  ///
  /// In en, this message translates to:
  /// **'Draws a connected sequence of segments as one polyline entity. Pass a points array to create it non-interactively.'**
  String get command_draw_polyline_desc;

  /// command draw spline desc
  ///
  /// In en, this message translates to:
  /// **'Draws a clamped B-spline. Control-point mode pulls the curve toward the clicks and only guarantees the ends. Fit mode interpolates every point. Pass a points array to create it non-interactively.'**
  String get command_draw_spline_desc;

  /// command draw rectangle desc
  ///
  /// In en, this message translates to:
  /// **'Draws an axis-aligned rectangle as a closed polyline.'**
  String get command_draw_rectangle_desc;

  /// command draw circle desc
  ///
  /// In en, this message translates to:
  /// **'Draws a circle from a centre point and a radius.'**
  String get command_draw_circle_desc;

  /// command draw circle 2p desc
  ///
  /// In en, this message translates to:
  /// **'Draws a circle whose diameter is the segment between two points.'**
  String get command_draw_circle_2p_desc;

  /// command draw circle 3p desc
  ///
  /// In en, this message translates to:
  /// **'Draws the unique circle that passes through three specified points.'**
  String get command_draw_circle_3p_desc;

  /// command draw circle ttr desc
  ///
  /// In en, this message translates to:
  /// **'Draws a circle of a given radius tangent to two lines, circles or arcs. The pick on each object chooses the side (and, for a circle, external versus internal tangent).'**
  String get command_draw_circle_ttr_desc;

  /// command draw donut desc
  ///
  /// In en, this message translates to:
  /// **'Draws a filled ring from an inside and outside diameter. A zero inside diameter is a filled disk. The result is a closed wide polyline, which is how DWG stores a donut.'**
  String get command_draw_donut_desc;

  /// command draw arc desc
  ///
  /// In en, this message translates to:
  /// **'Draws a circular arc through three points: start, a point on the arc, and end.'**
  String get command_draw_arc_desc;

  /// command draw polygon desc
  ///
  /// In en, this message translates to:
  /// **'Draws a regular polygon inscribed in a circle.'**
  String get command_draw_polygon_desc;

  /// command draw ellipse desc
  ///
  /// In en, this message translates to:
  /// **'Draws an ellipse from a centre, one axis endpoint, and the distance to the other axis.'**
  String get command_draw_ellipse_desc;

  /// command draw xline desc
  ///
  /// In en, this message translates to:
  /// **'Draws an infinite construction line through a point in a given direction. The second point only sets the angle; both sides extend without end.'**
  String get command_draw_xline_desc;

  /// command draw ray desc
  ///
  /// In en, this message translates to:
  /// **'Draws a semi-infinite ray from a start point through a second point. Unlike XLINE, it has a beginning.'**
  String get command_draw_ray_desc;

  /// command draw point desc
  ///
  /// In en, this message translates to:
  /// **'Places a point marker.'**
  String get command_draw_point_desc;

  /// command draw divide desc
  ///
  /// In en, this message translates to:
  /// **'Places point markers that split a line, polyline, arc or circle into equal segments. Open objects leave the endpoints unmarked; a circle or closed polyline places a marker at every interval. A bulge is followed as its arc, not the chord.'**
  String get command_draw_divide_desc;

  /// command draw measure desc
  ///
  /// In en, this message translates to:
  /// **'Places point markers at a fixed spacing along a line, polyline, arc or circle. Open objects start from the nearer end; a circle starts at the pick. Endpoints are not marked. A bulge is followed as its arc, not the chord.'**
  String get command_draw_measure_desc;

  /// command draw text desc
  ///
  /// In en, this message translates to:
  /// **'Places a single line of text. Style defaults to the current TEXTSTYLE. Justify is Left, Center, Right or a corner code such as TL.'**
  String get command_draw_text_desc;

  /// command draw mtext desc
  ///
  /// In en, this message translates to:
  /// **'Places multiline text. Newlines become \\P. Width 0 does not wrap. Justify is TL…BR or attachment 1–9 (1 is top-left).'**
  String get command_draw_mtext_desc;

  /// command draw attdef desc
  ///
  /// In en, this message translates to:
  /// **'Places an attribute definition. Include it in a BLOCK so INSERT and ATTEDIT can fill the tag — title blocks and schedules.'**
  String get command_draw_attdef_desc;

  /// command draw leader desc
  ///
  /// In en, this message translates to:
  /// **'Draws a leader from an arrow tip through one or more vertices. Optional annotation text sits on a horizontal landing at the last point, the same way AutoCAD LEADER places a callout.'**
  String get command_draw_leader_desc;

  /// command draw hatch desc
  ///
  /// In en, this message translates to:
  /// **'Fills the area around an internal point, or around selected closed boundaries. Four lines that meet still count as a boundary.'**
  String get command_draw_hatch_desc;

  /// command draw dim linear desc
  ///
  /// In en, this message translates to:
  /// **'Places a horizontal or vertical dimension. The dimension-line pick chooses the axis: above or below the origins measures width; left or right measures height. A line can stand in for the two origins.'**
  String get command_draw_dim_linear_desc;

  /// command draw dim aligned desc
  ///
  /// In en, this message translates to:
  /// **'Places a dimension parallel to the two origins. The text is the true distance, not the horizontal or vertical component. A line can stand in for the two origins.'**
  String get command_draw_dim_aligned_desc;

  /// command draw dim radius desc
  ///
  /// In en, this message translates to:
  /// **'Places a radius dimension on a circle or arc. The second pick is the arrow tip; the text is the radius, prefixed with R.'**
  String get command_draw_dim_radius_desc;

  /// command draw dim diameter desc
  ///
  /// In en, this message translates to:
  /// **'Places a diameter dimension on a circle or arc. The second pick is the arrow tip; the text is the diameter, prefixed with Ø.'**
  String get command_draw_dim_diameter_desc;

  /// command draw center mark desc
  ///
  /// In en, this message translates to:
  /// **'Draws a centre mark on selected circles or arcs. A short cross sits on the centre; optional extensions continue past the circumference, the usual shop-drawing DIMCENTER.'**
  String get command_draw_center_mark_desc;

  /// command draw center line desc
  ///
  /// In en, this message translates to:
  /// **'Draws a centreline between two parallel lines, or through the centres of two circles or arcs. The line spans both objects and extends a little past each end.'**
  String get command_draw_center_line_desc;

  /// command draw dim angular desc
  ///
  /// In en, this message translates to:
  /// **'Places an angular dimension. Pick an arc and its centre is the vertex; pick two lines and their intersection is the vertex; the last pick sits on the dimension arc and chooses which sector is labelled. Three points still work when a vertex is supplied.'**
  String get command_draw_dim_angular_desc;

  /// command draw dim continue desc
  ///
  /// In en, this message translates to:
  /// **'Places the next linear or aligned dimension from the previous second origin, on the same dimension line. Chain several next points to walk a row of features.'**
  String get command_draw_dim_continue_desc;

  /// command draw dim baseline desc
  ///
  /// In en, this message translates to:
  /// **'Places the next linear or aligned dimension from the same first origin, on a dimension line stepped outward. Chain several next points to stack overall lengths.'**
  String get command_draw_dim_baseline_desc;

  /// command annot dimstyle desc
  ///
  /// In en, this message translates to:
  /// **'Creates or edits a dimension style. Regenerated dimensions read text height, arrow size, extension offsets, scale and decimal places from the named style. Omit the name to list styles or to edit the current one.'**
  String get command_annot_dimstyle_desc;

  /// command annot textstyle desc
  ///
  /// In en, this message translates to:
  /// **'Creates or edits a text style. New TEXT and MTEXT read the font, fixed height, width factor and oblique from the named style. Omit the name to list styles or to edit the current one.'**
  String get command_annot_textstyle_desc;

  /// command edit erase desc
  ///
  /// In en, this message translates to:
  /// **'Deletes the selected objects.'**
  String get command_edit_erase_desc;

  /// command edit overkill desc
  ///
  /// In en, this message translates to:
  /// **'Deletes exact geometric duplicates and folds overlapping or abutting collinear lines into one stroke. The first copy is kept and stretched to the union. Omitted ids means the whole current space, so a leftover selection cannot hide the rest of the duplicates.'**
  String get command_edit_overkill_desc;

  /// command edit move desc
  ///
  /// In en, this message translates to:
  /// **'Moves the selected objects by a displacement.'**
  String get command_edit_move_desc;

  /// command edit copy desc
  ///
  /// In en, this message translates to:
  /// **'Copies the selected objects to one or more locations. Each second point is another copy from the same base; Escape finishes.'**
  String get command_edit_copy_desc;

  /// command edit copy clip desc
  ///
  /// In en, this message translates to:
  /// **'Copies the selected objects to the clipboard. The lower-left of the selection is the paste base. Paste in this drawing or another tab with PASTECLIP.'**
  String get command_edit_copy_clip_desc;

  /// command edit copy base desc
  ///
  /// In en, this message translates to:
  /// **'Copies the selected objects to the clipboard with a base point you pick, so PASTECLIP can land that point on the insertion.'**
  String get command_edit_copy_base_desc;

  /// command edit cut clip desc
  ///
  /// In en, this message translates to:
  /// **'Copies the selected objects to the clipboard and deletes them from the drawing. Objects on a locked layer stay; the clipboard still holds a copy.'**
  String get command_edit_cut_clip_desc;

  /// command edit paste clip desc
  ///
  /// In en, this message translates to:
  /// **'Pastes clipboard objects at an insertion point. The stored base point lands on that click.'**
  String get command_edit_paste_clip_desc;

  /// command edit paste orig desc
  ///
  /// In en, this message translates to:
  /// **'Pastes clipboard objects at the coordinates they had in the source drawing, without asking for an insertion point.'**
  String get command_edit_paste_orig_desc;

  /// command edit paste block desc
  ///
  /// In en, this message translates to:
  /// **'Pastes clipboard objects as one anonymous block reference. The stored base point lands on the insertion point you pick.'**
  String get command_edit_paste_block_desc;

  /// command edit stretch desc
  ///
  /// In en, this message translates to:
  /// **'Moves vertices inside a crossing window and leaves the rest anchored. Objects wholly captured by the window move as a body.'**
  String get command_edit_stretch_desc;

  /// command edit rotate desc
  ///
  /// In en, this message translates to:
  /// **'Rotates the selected objects about a base point. The angle is in degrees, counter-clockwise.'**
  String get command_edit_rotate_desc;

  /// command edit scale desc
  ///
  /// In en, this message translates to:
  /// **'Scales the selected objects uniformly about a base point.'**
  String get command_edit_scale_desc;

  /// command edit mirror desc
  ///
  /// In en, this message translates to:
  /// **'Mirrors the selected objects across a line.'**
  String get command_edit_mirror_desc;

  /// command edit align desc
  ///
  /// In en, this message translates to:
  /// **'Moves the selection so a source point lands on a destination point. A second pair rotates to match the two directions; an optional scale matches the two lengths.'**
  String get command_edit_align_desc;

  /// command edit array desc
  ///
  /// In en, this message translates to:
  /// **'Creates a rectangular grid of copies of the selected objects.'**
  String get command_edit_array_desc;

  /// command edit polar array desc
  ///
  /// In en, this message translates to:
  /// **'Creates copies of the selected objects rotated about a centre. A fill of 360° spaces items around the full circle; a smaller fill spaces them from the original through that angle, inclusive.'**
  String get command_edit_polar_array_desc;

  /// command edit offset desc
  ///
  /// In en, this message translates to:
  /// **'Creates parallel copies of lines, arcs, circles and polylines at a fixed distance.'**
  String get command_edit_offset_desc;

  /// command edit trim desc
  ///
  /// In en, this message translates to:
  /// **'Shortens a line, polyline or arc back to where it crosses the selected cutting edges. The part containing the pick point is removed. A closed polyline opens; a bulge is cut on the arc, not the chord.'**
  String get command_edit_trim_desc;

  /// command edit extend desc
  ///
  /// In en, this message translates to:
  /// **'Lengthens a line, open polyline or arc until it meets the selected boundary edges. A bulge grows along its circle. On a polyline or arc the pick chooses which end moves.'**
  String get command_edit_extend_desc;

  /// command edit fillet desc
  ///
  /// In en, this message translates to:
  /// **'Rounds the corner between two lines, or vertices of a polyline, with an arc of a given radius. Pass all=true to fillet every straight corner of a polyline. A radius of zero trims or extends two lines to a sharp corner.'**
  String get command_edit_fillet_desc;

  /// command edit chamfer desc
  ///
  /// In en, this message translates to:
  /// **'Cuts a straight bevel between two lines, or at vertices of a polyline. Pass all=true to chamfer every straight corner. The two distances are measured from the corner back along each segment; omit the second to use the same length on both.'**
  String get command_edit_chamfer_desc;

  /// command edit break desc
  ///
  /// In en, this message translates to:
  /// **'Splits a line, polyline or arc at a point, or removes the portion between two points. A bulge is split into two smaller arcs. A circle needs two points and keeps the counter-clockwise remnant from the second pick back to the first. Omit the second point to only split (arcs and open chains).'**
  String get command_edit_break_desc;

  /// command edit lengthen desc
  ///
  /// In en, this message translates to:
  /// **'Changes the length of a line, open polyline or arc by moving the end you pick. A bulge grows or shrinks along its arc. Supply a total length, or a signed delta to add to the current length. An arc cannot be closed into a full circle.'**
  String get command_edit_lengthen_desc;

  /// command edit explode desc
  ///
  /// In en, this message translates to:
  /// **'Breaks polylines into their segments, block references into copies of their contents, and dimensions into the lines, arrows and text they draw.'**
  String get command_edit_explode_desc;

  /// command edit block desc
  ///
  /// In en, this message translates to:
  /// **'Defines a named block from selected objects and replaces them with one insert at the base point, so the drawing looks the same and the definition can be inserted again.'**
  String get command_edit_block_desc;

  /// command edit insert desc
  ///
  /// In en, this message translates to:
  /// **'Places one or more references to a named block. Scale is uniform; rotation is in degrees. Pass a points array to stamp the same block at several locations.'**
  String get command_edit_insert_desc;

  /// command edit minsert desc
  ///
  /// In en, this message translates to:
  /// **'Places a rectangular array of a named block as one insert. The copies stay one object, so moving the insert moves the whole grid.'**
  String get command_edit_minsert_desc;

  /// command block purge desc
  ///
  /// In en, this message translates to:
  /// **'Deletes named block definitions that no insert references. Nested unused definitions are removed in the same pass, so a block that only existed inside another unused block is cleared too. Xrefs and layout blocks are left alone.'**
  String get command_block_purge_desc;

  /// command block rename desc
  ///
  /// In en, this message translates to:
  /// **'Renames a block definition and every insert that still points at the old name. Layout blocks, anonymous blocks and xrefs cannot be renamed.'**
  String get command_block_rename_desc;

  /// command edit join desc
  ///
  /// In en, this message translates to:
  /// **'Joins selected lines, arcs and open polylines whose endpoints meet into a single polyline. A piece is reversed when that is how it touches the chain; a loop whose ends meet is stored closed.'**
  String get command_edit_join_desc;

  /// command edit close desc
  ///
  /// In en, this message translates to:
  /// **'Closes the selected open polylines by connecting the last vertex back to the first. Already-closed polylines are left alone.'**
  String get command_edit_close_desc;

  /// command edit open desc
  ///
  /// In en, this message translates to:
  /// **'Opens the selected closed polylines by dropping the closing segment. The vertices stay; only the loop is broken.'**
  String get command_edit_open_desc;

  /// command edit polyline width desc
  ///
  /// In en, this message translates to:
  /// **'Sets the constant width of selected polylines. Zero is a hairline; a donut is the same field, so this is how a wide stroke is edited after it is drawn.'**
  String get command_edit_polyline_width_desc;

  /// command edit hatch desc
  ///
  /// In en, this message translates to:
  /// **'Changes the pattern, scale or angle of selected hatches. Omit a field to leave it. Angle is in degrees.'**
  String get command_edit_hatch_desc;

  /// command edit to polyline desc
  ///
  /// In en, this message translates to:
  /// **'Turns selected lines into two-vertex polylines so they can be closed, opened or reversed as a chain.'**
  String get command_edit_to_polyline_desc;

  /// command edit reverse desc
  ///
  /// In en, this message translates to:
  /// **'Reverses the direction of selected lines and polylines. The drawn shape stays the same; start and end swap, which matters for linetypes and for commands that follow a chain.'**
  String get command_edit_reverse_desc;

  /// command edit undo desc
  ///
  /// In en, this message translates to:
  /// **'Reverses the most recent change.'**
  String get command_edit_undo_desc;

  /// command edit redo desc
  ///
  /// In en, this message translates to:
  /// **'Re-applies the most recently undone change.'**
  String get command_edit_redo_desc;

  /// command edit change layer desc
  ///
  /// In en, this message translates to:
  /// **'Moves the selected objects onto a different layer.'**
  String get command_edit_change_layer_desc;

  /// command edit change color desc
  ///
  /// In en, this message translates to:
  /// **'Sets the colour of the selected objects. Accepts an AutoCAD Color Index (1-255), a #rrggbb value, or ByLayer.'**
  String get command_edit_change_color_desc;

  /// command edit change linetype desc
  ///
  /// In en, this message translates to:
  /// **'Sets the linetype of the selected objects. Stock names (DASHED, HIDDEN, CENTER, PHANTOM, DOT, DASHDOT, DIVIDE, Continuous) are added to the drawing if they are not there yet. ByLayer and ByBlock inherit instead.'**
  String get command_edit_change_linetype_desc;

  /// command edit change lineweight desc
  ///
  /// In en, this message translates to:
  /// **'Sets the lineweight of the selected objects. Accepts a millimetre value (0.25), hundredths (25), ByLayer, ByBlock, Default or hairline.'**
  String get command_edit_change_lineweight_desc;

  /// command edit dimension text desc
  ///
  /// In en, this message translates to:
  /// **'Overrides the text of selected dimensions. Empty restores the measured value; <> stands for that value; a single space hides the text.'**
  String get command_edit_dimension_text_desc;

  /// command edit dim tedit desc
  ///
  /// In en, this message translates to:
  /// **'Moves the text of selected dimensions to a new point. On a linear dimension the dimension line follows without flipping width and height; aligned, radial and angular dimensions keep their type.'**
  String get command_edit_dim_tedit_desc;

  /// command edit text content desc
  ///
  /// In en, this message translates to:
  /// **'Changes the content of selected text, mtext, dimensions, attributes or leaders. On a dimension, empty restores the measured value and <> stands for that value, same as DIMEDIT.'**
  String get command_edit_text_content_desc;

  /// command edit text object desc
  ///
  /// In en, this message translates to:
  /// **'Updates content, height, colour, justification, rotation, style, column width, width factor or oblique of selected text, mtext, attributes or leaders in one undo. Dimension text height is a dimstyle property and is ignored.'**
  String get command_edit_text_object_desc;

  /// command edit justify text desc
  ///
  /// In en, this message translates to:
  /// **'Changes the justification of selected text or mtext and moves the insertion point so the letters stay where they are. Align and Fit are not offered; they need a second point.'**
  String get command_edit_justify_text_desc;

  /// command edit match prop desc
  ///
  /// In en, this message translates to:
  /// **'Copies layer, colour, linetype, lineweight and the other display properties from a source object onto the destination objects. Visibility is left alone so isolate and hide stay intact.'**
  String get command_edit_match_prop_desc;

  /// command edit attedit desc
  ///
  /// In en, this message translates to:
  /// **'Changes the values on a block reference. Constant tags stay as the definition wrote them.'**
  String get command_edit_attedit_desc;

  /// command view zoom extents desc
  ///
  /// In en, this message translates to:
  /// **'Fits the whole drawing in the window.'**
  String get command_view_zoom_extents_desc;

  /// command view zoom window desc
  ///
  /// In en, this message translates to:
  /// **'Zooms to a rectangle you specify.'**
  String get command_view_zoom_window_desc;

  /// command view zoom in desc
  ///
  /// In en, this message translates to:
  /// **'Magnifies the view about its centre.'**
  String get command_view_zoom_in_desc;

  /// command view zoom out desc
  ///
  /// In en, this message translates to:
  /// **'Shrinks the view about its centre.'**
  String get command_view_zoom_out_desc;

  /// command view zoom selected desc
  ///
  /// In en, this message translates to:
  /// **'Fits the selected objects in the window.'**
  String get command_view_zoom_selected_desc;

  /// command view regen desc
  ///
  /// In en, this message translates to:
  /// **'Rebuilds the display list, discarding cached curve tessellations.'**
  String get command_view_regen_desc;

  /// command view units desc
  ///
  /// In en, this message translates to:
  /// **'Sets the drawing insertion units written to \$INSUNITS. Coordinates stay in these units; the value is what importers and queries use to convert.'**
  String get command_view_units_desc;

  /// command workbench preferences desc
  ///
  /// In en, this message translates to:
  /// **'Opens the application settings dialog.'**
  String get command_workbench_preferences_desc;

  /// command select all desc
  ///
  /// In en, this message translates to:
  /// **'Selects every selectable object in the current space.'**
  String get command_select_all_desc;

  /// command select none desc
  ///
  /// In en, this message translates to:
  /// **'Clears the selection.'**
  String get command_select_none_desc;

  /// command select invert desc
  ///
  /// In en, this message translates to:
  /// **'Selects everything that is not currently selected.'**
  String get command_select_invert_desc;

  /// command select similar desc
  ///
  /// In en, this message translates to:
  /// **'Extends the selection to every object of the same type and layer.'**
  String get command_select_similar_desc;

  /// command select by layer desc
  ///
  /// In en, this message translates to:
  /// **'Selects every object on a named layer.'**
  String get command_select_by_layer_desc;

  /// command select by color desc
  ///
  /// In en, this message translates to:
  /// **'Selects every object whose stored colour matches an ACI, #rrggbb, ByLayer or ByBlock. Layer-inherited red is not the same as ACI 1.'**
  String get command_select_by_color_desc;

  /// command select by linetype desc
  ///
  /// In en, this message translates to:
  /// **'Selects every object whose stored linetype matches a name, ByLayer or ByBlock. Layer-inherited DASHED is not the same as DASHED.'**
  String get command_select_by_linetype_desc;

  /// command select by lineweight desc
  ///
  /// In en, this message translates to:
  /// **'Selects every object whose stored lineweight matches a millimetre value, hundredths, ByLayer, ByBlock, Default or hairline. Layer-inherited 0.25 mm is not the same as 25.'**
  String get command_select_by_lineweight_desc;

  /// command select by type desc
  ///
  /// In en, this message translates to:
  /// **'Selects every object of one entity kind in the current space. LINE, CIRCLE, INSERT, DIMENSION and the other FanCAD kinds work; LWPOLYLINE and BLOCK are accepted as polyline and insert.'**
  String get command_select_by_type_desc;

  /// command select by block desc
  ///
  /// In en, this message translates to:
  /// **'Selects every insert of a named block in the current space. The name is case-insensitive, the same way INSERT and RENAME look it up.'**
  String get command_select_by_block_desc;

  /// command view isolate objects desc
  ///
  /// In en, this message translates to:
  /// **'Hides every object in the current space except the selection, so the rest of the drawing is out of the way without being deleted.'**
  String get command_view_isolate_objects_desc;

  /// command view hide objects desc
  ///
  /// In en, this message translates to:
  /// **'Hides the selected objects without deleting them.'**
  String get command_view_hide_objects_desc;

  /// command view unisolate objects desc
  ///
  /// In en, this message translates to:
  /// **'Shows every object that Isolate or Hide had turned off in the current space.'**
  String get command_view_unisolate_objects_desc;

  /// command layer new desc
  ///
  /// In en, this message translates to:
  /// **'Creates a layer and makes it current.'**
  String get command_layer_new_desc;

  /// command layer set current desc
  ///
  /// In en, this message translates to:
  /// **'Chooses the layer new objects are created on.'**
  String get command_layer_set_current_desc;

  /// command layer toggle visible desc
  ///
  /// In en, this message translates to:
  /// **'Turns a layer on or off.'**
  String get command_layer_toggle_visible_desc;

  /// command layer isolate desc
  ///
  /// In en, this message translates to:
  /// **'Turns off every layer except the named one.'**
  String get command_layer_isolate_desc;

  /// command layer show all desc
  ///
  /// In en, this message translates to:
  /// **'Turns every layer back on.'**
  String get command_layer_show_all_desc;

  /// command layer toggle lock desc
  ///
  /// In en, this message translates to:
  /// **'Locks or unlocks a layer. Objects on a locked layer stay visible but cannot be modified.'**
  String get command_layer_toggle_lock_desc;

  /// command layer delete desc
  ///
  /// In en, this message translates to:
  /// **'Deletes a layer and everything on it. The layer named 0 cannot be deleted.'**
  String get command_layer_delete_desc;

  /// command layer purge desc
  ///
  /// In en, this message translates to:
  /// **'Deletes layers that no object uses. Layer 0 is kept, and if the current layer is empty it is switched back to 0 before the purge.'**
  String get command_layer_purge_desc;

  /// command query summary desc
  ///
  /// In en, this message translates to:
  /// **'Returns a compact statistical summary of the drawing: extents, entity counts by type, and per-layer counts. Use this first to understand a drawing before querying its contents.'**
  String get command_query_summary_desc;

  /// command query list desc
  ///
  /// In en, this message translates to:
  /// **'Reports the full properties of the selected objects.'**
  String get command_query_list_desc;

  /// command query entities desc
  ///
  /// In en, this message translates to:
  /// **'Finds entities matching optional filters and returns their ids and properties. Use layer, kind and a bounding window to narrow a large drawing to the part you care about.'**
  String get command_query_entities_desc;

  /// command query selection desc
  ///
  /// In en, this message translates to:
  /// **'Returns the current selection as structured records (id, kind, layer, bounds, short geometry). Use this instead of guessing ids. An empty selection is a successful empty list, not a prompt.'**
  String get command_query_selection_desc;

  /// command query viewport desc
  ///
  /// In en, this message translates to:
  /// **'Returns the active camera: centre, scale and visible window as [minX, minY, maxX, maxY]. Pass that window to query.entities to list what the user is looking at.'**
  String get command_query_viewport_desc;

  /// command query id desc
  ///
  /// In en, this message translates to:
  /// **'Reports the X and Y coordinates of a point. Use this when you need a location, not a distance between two locations.'**
  String get command_query_id_desc;

  /// command query distance desc
  ///
  /// In en, this message translates to:
  /// **'Measures the distance and angle between two points.'**
  String get command_query_distance_desc;

  /// command query angle desc
  ///
  /// In en, this message translates to:
  /// **'Measures the angle at a vertex between two rays. The first point is the vertex; the next two define the sides.'**
  String get command_query_angle_desc;

  /// command query area desc
  ///
  /// In en, this message translates to:
  /// **'Reports the area and perimeter of the selected closed objects.'**
  String get command_query_area_desc;

  /// command query layers desc
  ///
  /// In en, this message translates to:
  /// **'Returns every layer with its state and object count.'**
  String get command_query_layers_desc;

  /// command layout list desc
  ///
  /// In en, this message translates to:
  /// **'Lists model and paper-space layouts and their viewports.'**
  String get command_layout_list_desc;

  /// command layout set desc
  ///
  /// In en, this message translates to:
  /// **'Switches the active layout (Model or a paper tab).'**
  String get command_layout_set_desc;

  /// command layout new desc
  ///
  /// In en, this message translates to:
  /// **'Adds a paper-space layout tab and opens it. The sheet defaults to A4 landscape; pass width and height in millimetres to override.'**
  String get command_layout_new_desc;

  /// command layout delete desc
  ///
  /// In en, this message translates to:
  /// **'Removes a paper-space layout tab and the entities on that sheet. Model cannot be deleted. Omit the name to delete the current tab.'**
  String get command_layout_delete_desc;

  /// command layout copy desc
  ///
  /// In en, this message translates to:
  /// **'Duplicates a paper layout: sheet size, viewports, and the entities on that sheet. Model cannot be copied.'**
  String get command_layout_copy_desc;

  /// command layout rename desc
  ///
  /// In en, this message translates to:
  /// **'Renames a paper layout tab. The sheet, viewports and paper entities stay put. Model cannot be renamed.'**
  String get command_layout_rename_desc;

  /// command layout order desc
  ///
  /// In en, this message translates to:
  /// **'Moves a paper tab in the layout strip. Model stays first. index is the destination among paper tabs (0 = first paper). Or pass before / after another tab name.'**
  String get command_layout_order_desc;

  /// command layout pagesetup desc
  ///
  /// In en, this message translates to:
  /// **'Changes the paper size of a layout, in millimetres, the plot rotation (0, 90, 180 or 270), scale or fit-to-sheet, an offset, and an optional plot window. Omit the name to edit the current paper tab. Model has no sheet.'**
  String get command_layout_pagesetup_desc;

  /// command layout mview desc
  ///
  /// In en, this message translates to:
  /// **'Cuts a window on the current paper layout that looks into model space. The model is framed in the rectangle unless a scale is supplied.'**
  String get command_layout_mview_desc;

  /// command layout vpscale desc
  ///
  /// In en, this message translates to:
  /// **'Sets the scale of a paper viewport (model units per paper unit). Pass fit=true to frame the model again. A locked viewport is refused.'**
  String get command_layout_vpscale_desc;

  /// command layout vplock desc
  ///
  /// In en, this message translates to:
  /// **'Locks or unlocks a paper viewport so VPSCALE cannot change the view. Omit locked to toggle. The window frame can still move.'**
  String get command_layout_vplock_desc;

  /// command layout vpon desc
  ///
  /// In en, this message translates to:
  /// **'Turns a paper viewport on or off. An off window keeps its frame but hides the model and is skipped when plotting. Omit on to toggle.'**
  String get command_layout_vpon_desc;

  /// command layout vplayer desc
  ///
  /// In en, this message translates to:
  /// **'Freezes or thaws layers in one paper viewport. Other windows and model space keep their own visibility. Omit freeze to freeze.'**
  String get command_layout_vplayer_desc;

  /// command layout vpmax desc
  ///
  /// In en, this message translates to:
  /// **'Opens model space framed to a paper viewport so the model can be edited through that window. VPMIN returns to the sheet.'**
  String get command_layout_vpmax_desc;

  /// command layout vpmin desc
  ///
  /// In en, this message translates to:
  /// **'Returns to the paper layout left by VPMAX and frames the sheet.'**
  String get command_layout_vpmin_desc;

  /// command print export svg desc
  ///
  /// In en, this message translates to:
  /// **'Plots a layout to an SVG file. Omit the layout name to plot the current tab. A .pdf path writes a vector PDF instead. Pass corner1 and corner2 to plot a window; otherwise the layout\'s stored plot window or the full sheet is used.'**
  String get command_print_export_svg_desc;

  /// command print export pdf desc
  ///
  /// In en, this message translates to:
  /// **'Plots a layout to a vector PDF. Omit the layout name to plot the current tab. Paper size becomes the page MediaBox; viewports are clipped. Pass corner1 and corner2 to plot a window.'**
  String get command_print_export_pdf_desc;

  /// command xref attach desc
  ///
  /// In en, this message translates to:
  /// **'Loads another drawing as an external reference and places it in model space. Reload by attaching the same path again; existing inserts keep their position.'**
  String get command_xref_attach_desc;

  /// command xref reload desc
  ///
  /// In en, this message translates to:
  /// **'Re-reads attached external references from their stored paths. Omit the name to reload the selected xref, or the only xref in the drawing.'**
  String get command_xref_reload_desc;

  /// command xref detach desc
  ///
  /// In en, this message translates to:
  /// **'Removes an external reference and every insert that shows it. Omit the name to detach the selected xref, or the only xref in the drawing.'**
  String get command_xref_detach_desc;

  /// command xref bind desc
  ///
  /// In en, this message translates to:
  /// **'Turns an external reference into a local block so the drawing no longer depends on that file. Inserts stay where they are. Omit the name to bind the selected xref, or the only xref in the drawing.'**
  String get command_xref_bind_desc;

  /// command plugins list desc
  ///
  /// In en, this message translates to:
  /// **'Lists installed extensions with their state, version and the commands they contribute.'**
  String get command_plugins_list_desc;

  /// command plugins reload desc
  ///
  /// In en, this message translates to:
  /// **'Re-reads an extension from disk and re-evaluates it, picking up both code and manifest changes without restarting.'**
  String get command_plugins_reload_desc;

  /// command plugins enable desc
  ///
  /// In en, this message translates to:
  /// **'Loads an extension so it can contribute commands again.'**
  String get command_plugins_enable_desc;

  /// command plugins disable desc
  ///
  /// In en, this message translates to:
  /// **'Unloads an extension and stops it activating again until enabled.'**
  String get command_plugins_disable_desc;

  /// command plugins logs desc
  ///
  /// In en, this message translates to:
  /// **'Prints what an extension logged, for diagnosing a failure.'**
  String get command_plugins_logs_desc;

  /// command plugins scaffold desc
  ///
  /// In en, this message translates to:
  /// **'Writes a new extension folder with a manifest and a working main.js, then loads it. Returns the paths written.'**
  String get command_plugins_scaffold_desc;

  /// command plugins write desc
  ///
  /// In en, this message translates to:
  /// **'Overwrites one file inside an extension folder. Paths are confined to that folder.'**
  String get command_plugins_write_desc;

  /// command plugins read desc
  ///
  /// In en, this message translates to:
  /// **'Reads one file from an extension folder.'**
  String get command_plugins_read_desc;

  /// command plugins typings desc
  ///
  /// In en, this message translates to:
  /// **'Regenerates fancad.d.ts from the live command registry, so editors and models see the real API surface.'**
  String get command_plugins_typings_desc;

  /// command plugins edit desc
  ///
  /// In en, this message translates to:
  /// **'Opens an extension file in the built-in editor so a person can review or change what the AI authoring loop wrote.'**
  String get command_plugins_edit_desc;

  /// command plugins eval desc
  ///
  /// In en, this message translates to:
  /// **'Runs a JavaScript expression inside an extension scope. For debugging; it can do anything the extension can.'**
  String get command_plugins_eval_desc;

  /// command step
  ///
  /// In en, this message translates to:
  /// **'{verb}  {step}'**
  String command_step(String verb, String step);

  /// prompt specify first point
  ///
  /// In en, this message translates to:
  /// **'Specify first point:'**
  String get prompt_specify_first_point;

  /// prompt specify next point esc
  ///
  /// In en, this message translates to:
  /// **'Specify next point (Escape to finish):'**
  String get prompt_specify_next_point_esc;

  /// prompt specify second point
  ///
  /// In en, this message translates to:
  /// **'Specify second point:'**
  String get prompt_specify_second_point;

  /// prompt specify second point esc
  ///
  /// In en, this message translates to:
  /// **'Specify second point (Escape to finish):'**
  String get prompt_specify_second_point_esc;

  /// prompt specify base point
  ///
  /// In en, this message translates to:
  /// **'Specify base point:'**
  String get prompt_specify_base_point;

  /// prompt select objects
  ///
  /// In en, this message translates to:
  /// **'Select objects:'**
  String get prompt_select_objects;

  /// prompt specify center
  ///
  /// In en, this message translates to:
  /// **'Specify center:'**
  String get prompt_specify_center;

  /// prompt specify center point
  ///
  /// In en, this message translates to:
  /// **'Specify center point:'**
  String get prompt_specify_center_point;

  /// prompt specify radius
  ///
  /// In en, this message translates to:
  /// **'Specify radius:'**
  String get prompt_specify_radius;

  /// prompt specify first corner
  ///
  /// In en, this message translates to:
  /// **'Specify first corner:'**
  String get prompt_specify_first_corner;

  /// prompt specify opposite corner
  ///
  /// In en, this message translates to:
  /// **'Specify opposite corner:'**
  String get prompt_specify_opposite_corner;

  /// prompt specify insertion point
  ///
  /// In en, this message translates to:
  /// **'Specify insertion point:'**
  String get prompt_specify_insertion_point;

  /// prompt specify next insertion esc
  ///
  /// In en, this message translates to:
  /// **'Specify next insertion point (Escape to finish):'**
  String get prompt_specify_next_insertion_esc;

  /// prompt specify height
  ///
  /// In en, this message translates to:
  /// **'Specify height:'**
  String get prompt_specify_height;

  /// prompt specify start point
  ///
  /// In en, this message translates to:
  /// **'Specify start point:'**
  String get prompt_specify_start_point;

  /// prompt specify through point
  ///
  /// In en, this message translates to:
  /// **'Specify through point:'**
  String get prompt_specify_through_point;

  /// prompt specify end point
  ///
  /// In en, this message translates to:
  /// **'Specify end point:'**
  String get prompt_specify_end_point;

  /// prompt specify a point
  ///
  /// In en, this message translates to:
  /// **'Specify a point:'**
  String get prompt_specify_a_point;

  /// prompt specify a location
  ///
  /// In en, this message translates to:
  /// **'Specify a location:'**
  String get prompt_specify_a_location;

  /// prompt specify point
  ///
  /// In en, this message translates to:
  /// **'Specify point:'**
  String get prompt_specify_point;

  /// prompt specify vertex
  ///
  /// In en, this message translates to:
  /// **'Specify vertex:'**
  String get prompt_specify_vertex;

  /// prompt specify dim line
  ///
  /// In en, this message translates to:
  /// **'Specify dimension line location:'**
  String get prompt_specify_dim_line;

  /// prompt specify first ext origin
  ///
  /// In en, this message translates to:
  /// **'Specify first extension line origin:'**
  String get prompt_specify_first_ext_origin;

  /// prompt specify second ext origin
  ///
  /// In en, this message translates to:
  /// **'Specify second extension line origin:'**
  String get prompt_specify_second_ext_origin;

  /// prompt specify next ext origin
  ///
  /// In en, this message translates to:
  /// **'Specify next extension line origin:'**
  String get prompt_specify_next_ext_origin;

  /// prompt specify second ext origin alt
  ///
  /// In en, this message translates to:
  /// **'Specify a second extension line origin:'**
  String get prompt_specify_second_ext_origin_alt;

  /// prompt specify dim arc
  ///
  /// In en, this message translates to:
  /// **'Specify dimension arc location:'**
  String get prompt_specify_dim_arc;

  /// prompt specify rotation angle
  ///
  /// In en, this message translates to:
  /// **'Specify rotation angle:'**
  String get prompt_specify_rotation_angle;

  /// prompt specify new height
  ///
  /// In en, this message translates to:
  /// **'Specify new height:'**
  String get prompt_specify_new_height;

  /// prompt specify width factor
  ///
  /// In en, this message translates to:
  /// **'Specify width factor:'**
  String get prompt_specify_width_factor;

  /// prompt specify oblique
  ///
  /// In en, this message translates to:
  /// **'Specify oblique angle:'**
  String get prompt_specify_oblique;

  /// prompt specify column width
  ///
  /// In en, this message translates to:
  /// **'Specify column width:'**
  String get prompt_specify_column_width;

  /// prompt specify attachment point
  ///
  /// In en, this message translates to:
  /// **'Specify attachment point:'**
  String get prompt_specify_attachment_point;

  /// prompt specify scale factor
  ///
  /// In en, this message translates to:
  /// **'Specify scale factor (or pick a distance):'**
  String get prompt_specify_scale_factor;

  /// prompt specify offset distance
  ///
  /// In en, this message translates to:
  /// **'Specify offset distance:'**
  String get prompt_specify_offset_distance;

  /// prompt specify offset side
  ///
  /// In en, this message translates to:
  /// **'Specify a point on the side to offset:'**
  String get prompt_specify_offset_side;

  /// prompt specify fillet radius
  ///
  /// In en, this message translates to:
  /// **'Specify fillet radius:'**
  String get prompt_specify_fillet_radius;

  /// prompt specify inside diameter
  ///
  /// In en, this message translates to:
  /// **'Specify inside diameter:'**
  String get prompt_specify_inside_diameter;

  /// prompt specify outside diameter
  ///
  /// In en, this message translates to:
  /// **'Specify outside diameter:'**
  String get prompt_specify_outside_diameter;

  /// prompt specify center of donut
  ///
  /// In en, this message translates to:
  /// **'Specify center of donut:'**
  String get prompt_specify_center_of_donut;

  /// prompt specify total length
  ///
  /// In en, this message translates to:
  /// **'Specify total length:'**
  String get prompt_specify_total_length;

  /// prompt specify segment length
  ///
  /// In en, this message translates to:
  /// **'Specify segment length:'**
  String get prompt_specify_segment_length;

  /// prompt specify stretch point
  ///
  /// In en, this message translates to:
  /// **'Specify stretch point:'**
  String get prompt_specify_stretch_point;

  /// prompt idle select
  ///
  /// In en, this message translates to:
  /// **'Select objects or specify a command:'**
  String get prompt_idle_select;

  /// prompt enter layer name
  ///
  /// In en, this message translates to:
  /// **'Enter layer name:'**
  String get prompt_enter_layer_name;

  /// prompt enter a layer name
  ///
  /// In en, this message translates to:
  /// **'Enter a layer name:'**
  String get prompt_enter_a_layer_name;

  /// prompt extension id
  ///
  /// In en, this message translates to:
  /// **'Extension id:'**
  String get prompt_extension_id;

  /// prompt enter block name
  ///
  /// In en, this message translates to:
  /// **'Enter block name:'**
  String get prompt_enter_block_name;

  /// prompt enter text
  ///
  /// In en, this message translates to:
  /// **'Enter the text:'**
  String get prompt_enter_text;

  /// prompt select closed objects
  ///
  /// In en, this message translates to:
  /// **'Select closed objects:'**
  String get prompt_select_closed_objects;

  /// prompt select viewport
  ///
  /// In en, this message translates to:
  /// **'Select viewport:'**
  String get prompt_select_viewport;

  /// prompt selected viewport
  ///
  /// In en, this message translates to:
  /// **'Selected viewport'**
  String get prompt_selected_viewport;

  /// prompt enter colour
  ///
  /// In en, this message translates to:
  /// **'Enter a colour (1-255, #rrggbb or ByLayer):'**
  String get prompt_enter_colour;

  /// prompt javascript
  ///
  /// In en, this message translates to:
  /// **'JavaScript:'**
  String get prompt_javascript;

  /// prompt svg path
  ///
  /// In en, this message translates to:
  /// **'SVG path:'**
  String get prompt_svg_path;

  /// prompt pdf path
  ///
  /// In en, this message translates to:
  /// **'PDF path:'**
  String get prompt_pdf_path;

  /// prompt layout name
  ///
  /// In en, this message translates to:
  /// **'Layout name:'**
  String get prompt_layout_name;

  /// prompt layout to copy
  ///
  /// In en, this message translates to:
  /// **'Layout to copy:'**
  String get prompt_layout_to_copy;

  /// prompt layout to delete
  ///
  /// In en, this message translates to:
  /// **'Layout to delete:'**
  String get prompt_layout_to_delete;

  /// prompt layout to move
  ///
  /// In en, this message translates to:
  /// **'Layout to move:'**
  String get prompt_layout_to_move;

  /// prompt layout to rename
  ///
  /// In en, this message translates to:
  /// **'Layout to rename:'**
  String get prompt_layout_to_rename;

  /// prompt drawing to attach
  ///
  /// In en, this message translates to:
  /// **'Drawing to attach:'**
  String get prompt_drawing_to_attach;

  /// prompt file to write
  ///
  /// In en, this message translates to:
  /// **'File to write:'**
  String get prompt_file_to_write;

  /// prompt file to read
  ///
  /// In en, this message translates to:
  /// **'File to read:'**
  String get prompt_file_to_read;

  /// prompt select objects to erase
  ///
  /// In en, this message translates to:
  /// **'Select objects to erase:'**
  String get prompt_select_objects_to_erase;

  /// prompt select objects to array
  ///
  /// In en, this message translates to:
  /// **'Select objects to array:'**
  String get prompt_select_objects_to_array;

  /// prompt select objects to align
  ///
  /// In en, this message translates to:
  /// **'Select objects to align:'**
  String get prompt_select_objects_to_align;

  /// prompt select objects to rotate
  ///
  /// In en, this message translates to:
  /// **'Select objects to rotate:'**
  String get prompt_select_objects_to_rotate;

  /// prompt select objects to scale
  ///
  /// In en, this message translates to:
  /// **'Select objects to scale:'**
  String get prompt_select_objects_to_scale;

  /// prompt select objects to mirror
  ///
  /// In en, this message translates to:
  /// **'Select objects to mirror:'**
  String get prompt_select_objects_to_mirror;

  /// prompt select objects to offset
  ///
  /// In en, this message translates to:
  /// **'Select objects to offset:'**
  String get prompt_select_objects_to_offset;

  /// prompt select objects to explode
  ///
  /// In en, this message translates to:
  /// **'Select objects to explode:'**
  String get prompt_select_objects_to_explode;

  /// prompt select objects to hide
  ///
  /// In en, this message translates to:
  /// **'Select objects to hide:'**
  String get prompt_select_objects_to_hide;

  /// prompt select objects keep visible
  ///
  /// In en, this message translates to:
  /// **'Select objects to keep visible:'**
  String get prompt_select_objects_keep_visible;

  /// prompt select objects recolour
  ///
  /// In en, this message translates to:
  /// **'Select objects to recolour:'**
  String get prompt_select_objects_recolour;

  /// prompt select objects change layer
  ///
  /// In en, this message translates to:
  /// **'Select objects to move to another layer:'**
  String get prompt_select_objects_change_layer;

  /// prompt select text objects
  ///
  /// In en, this message translates to:
  /// **'Select text objects:'**
  String get prompt_select_text_objects;

  /// prompt textobject options
  ///
  /// In en, this message translates to:
  /// **'Specify text, height, colour, justification, rotation, style, column width, width factor or oblique:'**
  String get prompt_textobject_options;

  /// prompt place n points
  ///
  /// In en, this message translates to:
  /// **'Place {count} point(s)?'**
  String prompt_place_n_points(int count);

  /// prompt specify first kind point
  ///
  /// In en, this message translates to:
  /// **'Specify first {kind} point:'**
  String prompt_specify_first_kind_point(String kind);

  /// prompt specify next kind point esc
  ///
  /// In en, this message translates to:
  /// **'Specify next {kind} point (Escape to finish):'**
  String prompt_specify_next_kind_point_esc(String kind);

  /// prompt selected object
  ///
  /// In en, this message translates to:
  /// **'Selected {entity} on layer {layer}'**
  String prompt_selected_object(String entity, String layer);

  /// prompt objects selected
  ///
  /// In en, this message translates to:
  /// **'{count} objects selected'**
  String prompt_objects_selected(int count);

  /// prompt selection found
  ///
  /// In en, this message translates to:
  /// **'{message} ({count} found, Enter to accept)'**
  String prompt_selection_found(String message, int count);

  /// prompt enter annotation none
  ///
  /// In en, this message translates to:
  /// **'Enter annotation text <none>:'**
  String get prompt_enter_annotation_none;

  /// prompt enter attribute tag
  ///
  /// In en, this message translates to:
  /// **'Enter attribute tag:'**
  String get prompt_enter_attribute_tag;

  /// prompt enter block name to change
  ///
  /// In en, this message translates to:
  /// **'Enter block name to change:'**
  String get prompt_enter_block_name_to_change;

  /// prompt enter default value
  ///
  /// In en, this message translates to:
  /// **'Enter default value:'**
  String get prompt_enter_default_value;

  /// prompt enter dimension text
  ///
  /// In en, this message translates to:
  /// **'Enter dimension text (<> = measured):'**
  String get prompt_enter_dimension_text;

  /// prompt enter justification
  ///
  /// In en, this message translates to:
  /// **'Enter justification [Left/Center/Right/TL/TC/TR/ML/MC/MR/BL/BC/BR]:'**
  String get prompt_enter_justification;

  /// prompt enter layer names
  ///
  /// In en, this message translates to:
  /// **'Enter layer name(s):'**
  String get prompt_enter_layer_names;

  /// prompt enter spline method
  ///
  /// In en, this message translates to:
  /// **'Enter method [Control/Fit]:'**
  String get prompt_enter_spline_method;

  /// prompt enter linetype name
  ///
  /// In en, this message translates to:
  /// **'Enter name (DASHED, HIDDEN, CENTER, ByLayer):'**
  String get prompt_enter_linetype_name;

  /// prompt enter new block name
  ///
  /// In en, this message translates to:
  /// **'Enter new block name:'**
  String get prompt_enter_new_block_name;

  /// prompt enter new text
  ///
  /// In en, this message translates to:
  /// **'Enter new text:'**
  String get prompt_enter_new_text;

  /// prompt enter columns
  ///
  /// In en, this message translates to:
  /// **'Enter number of columns:'**
  String get prompt_enter_columns;

  /// prompt enter items
  ///
  /// In en, this message translates to:
  /// **'Enter number of items:'**
  String get prompt_enter_items;

  /// prompt enter rows
  ///
  /// In en, this message translates to:
  /// **'Enter number of rows:'**
  String get prompt_enter_rows;

  /// prompt enter sides
  ///
  /// In en, this message translates to:
  /// **'Enter number of sides:'**
  String get prompt_enter_sides;

  /// prompt enter object type
  ///
  /// In en, this message translates to:
  /// **'Enter object type (LINE, CIRCLE, INSERT, …):'**
  String get prompt_enter_object_type;

  /// prompt enter attribute prompt
  ///
  /// In en, this message translates to:
  /// **'Enter prompt:'**
  String get prompt_enter_attribute_prompt;

  /// prompt enter fill angle
  ///
  /// In en, this message translates to:
  /// **'Enter the angle to fill:'**
  String get prompt_enter_fill_angle;

  /// prompt enter column spacing
  ///
  /// In en, this message translates to:
  /// **'Enter the column spacing:'**
  String get prompt_enter_column_spacing;

  /// prompt enter segments
  ///
  /// In en, this message translates to:
  /// **'Enter the number of segments:'**
  String get prompt_enter_segments;

  /// prompt enter row spacing
  ///
  /// In en, this message translates to:
  /// **'Enter the row spacing:'**
  String get prompt_enter_row_spacing;

  /// prompt enter lineweight
  ///
  /// In en, this message translates to:
  /// **'Enter weight (0.25 mm, 25, ByLayer):'**
  String get prompt_enter_lineweight;

  /// prompt fillet vertex all
  ///
  /// In en, this message translates to:
  /// **'Fillet [Vertex/All]:'**
  String get prompt_fillet_vertex_all;

  /// prompt chamfer vertex all
  ///
  /// In en, this message translates to:
  /// **'Chamfer [Vertex/All]:'**
  String get prompt_chamfer_vertex_all;

  /// prompt select block reference
  ///
  /// In en, this message translates to:
  /// **'Select a block reference:'**
  String get prompt_select_block_reference;

  /// prompt select line pline arc
  ///
  /// In en, this message translates to:
  /// **'Select a line, polyline or arc:'**
  String get prompt_select_line_pline_arc;

  /// prompt select linear aligned dim
  ///
  /// In en, this message translates to:
  /// **'Select a linear or aligned dimension:'**
  String get prompt_select_linear_aligned_dim;

  /// prompt select arc or circle
  ///
  /// In en, this message translates to:
  /// **'Select arc or circle:'**
  String get prompt_select_arc_or_circle;

  /// prompt select arc or first line
  ///
  /// In en, this message translates to:
  /// **'Select arc or first line:'**
  String get prompt_select_arc_or_first_line;

  /// prompt select boundary edges
  ///
  /// In en, this message translates to:
  /// **'Select boundary edges:'**
  String get prompt_select_boundary_edges;

  /// prompt select circles or arcs
  ///
  /// In en, this message translates to:
  /// **'Select circles or arcs:'**
  String get prompt_select_circles_or_arcs;

  /// prompt select closed boundaries
  ///
  /// In en, this message translates to:
  /// **'Select closed boundaries:'**
  String get prompt_select_closed_boundaries;

  /// prompt select cutting edges
  ///
  /// In en, this message translates to:
  /// **'Select cutting edges:'**
  String get prompt_select_cutting_edges;

  /// prompt select destination objects
  ///
  /// In en, this message translates to:
  /// **'Select destination objects:'**
  String get prompt_select_destination_objects;

  /// prompt select dimensions
  ///
  /// In en, this message translates to:
  /// **'Select dimensions:'**
  String get prompt_select_dimensions;

  /// prompt select first line circle arc
  ///
  /// In en, this message translates to:
  /// **'Select first line, circle or arc:'**
  String get prompt_select_first_line_circle_arc;

  /// prompt select first object
  ///
  /// In en, this message translates to:
  /// **'Select first object:'**
  String get prompt_select_first_object;

  /// prompt select first tangent
  ///
  /// In en, this message translates to:
  /// **'Select first tangent object:'**
  String get prompt_select_first_tangent;

  /// prompt select hatch objects
  ///
  /// In en, this message translates to:
  /// **'Select hatch objects:'**
  String get prompt_select_hatch_objects;

  /// prompt select lines or plines
  ///
  /// In en, this message translates to:
  /// **'Select lines or polylines:'**
  String get prompt_select_lines_or_plines;

  /// prompt select lines to convert
  ///
  /// In en, this message translates to:
  /// **'Select lines to convert:'**
  String get prompt_select_lines_to_convert;

  /// prompt select join objects
  ///
  /// In en, this message translates to:
  /// **'Select lines, arcs or polylines to join:'**
  String get prompt_select_join_objects;

  /// prompt select object to break
  ///
  /// In en, this message translates to:
  /// **'Select object to break:'**
  String get prompt_select_object_to_break;

  /// prompt select object to divide
  ///
  /// In en, this message translates to:
  /// **'Select object to divide:'**
  String get prompt_select_object_to_divide;

  /// prompt select object to measure
  ///
  /// In en, this message translates to:
  /// **'Select object to measure:'**
  String get prompt_select_object_to_measure;

  /// prompt select plines to close
  ///
  /// In en, this message translates to:
  /// **'Select polylines to close:'**
  String get prompt_select_plines_to_close;

  /// prompt select plines to open
  ///
  /// In en, this message translates to:
  /// **'Select polylines to open:'**
  String get prompt_select_plines_to_open;

  /// prompt select plines width
  ///
  /// In en, this message translates to:
  /// **'Select polylines to set width:'**
  String get prompt_select_plines_width;

  /// prompt select second line circle arc
  ///
  /// In en, this message translates to:
  /// **'Select second line, circle or arc:'**
  String get prompt_select_second_line_circle_arc;

  /// prompt select second line
  ///
  /// In en, this message translates to:
  /// **'Select second line:'**
  String get prompt_select_second_line;

  /// prompt select second tangent
  ///
  /// In en, this message translates to:
  /// **'Select second tangent object:'**
  String get prompt_select_second_tangent;

  /// prompt select source object
  ///
  /// In en, this message translates to:
  /// **'Select source object:'**
  String get prompt_select_source_object;

  /// prompt select text mtext dim
  ///
  /// In en, this message translates to:
  /// **'Select text, mtext or a dimension:'**
  String get prompt_select_text_mtext_dim;

  /// prompt specify nearer end
  ///
  /// In en, this message translates to:
  /// **'Specify a point nearer the end to change:'**
  String get prompt_specify_nearer_end;

  /// prompt specify first ray point
  ///
  /// In en, this message translates to:
  /// **'Specify a point on the first ray:'**
  String get prompt_specify_first_ray_point;

  /// prompt specify second ray point
  ///
  /// In en, this message translates to:
  /// **'Specify a point on the second ray:'**
  String get prompt_specify_second_ray_point;

  /// prompt specify second point on arc
  ///
  /// In en, this message translates to:
  /// **'Specify a second point on the arc:'**
  String get prompt_specify_second_point_on_arc;

  /// prompt specify vertex to bevel
  ///
  /// In en, this message translates to:
  /// **'Specify a vertex to bevel:'**
  String get prompt_specify_vertex_to_bevel;

  /// prompt specify vertex to round
  ///
  /// In en, this message translates to:
  /// **'Specify a vertex to round:'**
  String get prompt_specify_vertex_to_round;

  /// prompt specify column distance
  ///
  /// In en, this message translates to:
  /// **'Specify distance between columns:'**
  String get prompt_specify_column_distance;

  /// prompt specify row distance
  ///
  /// In en, this message translates to:
  /// **'Specify distance between rows:'**
  String get prompt_specify_row_distance;

  /// prompt specify other axis distance
  ///
  /// In en, this message translates to:
  /// **'Specify distance to other axis:'**
  String get prompt_specify_other_axis_distance;

  /// prompt specify axis endpoint
  ///
  /// In en, this message translates to:
  /// **'Specify endpoint of axis:'**
  String get prompt_specify_axis_endpoint;

  /// prompt specify first break
  ///
  /// In en, this message translates to:
  /// **'Specify first break point:'**
  String get prompt_specify_first_break;

  /// prompt specify first chamfer
  ///
  /// In en, this message translates to:
  /// **'Specify first chamfer distance:'**
  String get prompt_specify_first_chamfer;

  /// prompt specify crossing first corner
  ///
  /// In en, this message translates to:
  /// **'Specify first corner of crossing window:'**
  String get prompt_specify_crossing_first_corner;

  /// prompt specify first dest
  ///
  /// In en, this message translates to:
  /// **'Specify first destination point:'**
  String get prompt_specify_first_dest;

  /// prompt specify first diameter end
  ///
  /// In en, this message translates to:
  /// **'Specify first end of diameter:'**
  String get prompt_specify_first_diameter_end;

  /// prompt specify first leader point
  ///
  /// In en, this message translates to:
  /// **'Specify first leader point:'**
  String get prompt_specify_first_leader_point;

  /// prompt specify mirror first
  ///
  /// In en, this message translates to:
  /// **'Specify first point of mirror line:'**
  String get prompt_specify_mirror_first;

  /// prompt specify first on circle
  ///
  /// In en, this message translates to:
  /// **'Specify first point on circle:'**
  String get prompt_specify_first_on_circle;

  /// prompt specify first source
  ///
  /// In en, this message translates to:
  /// **'Specify first source point:'**
  String get prompt_specify_first_source;

  /// prompt specify insertion base
  ///
  /// In en, this message translates to:
  /// **'Specify insertion base point:'**
  String get prompt_specify_insertion_base;

  /// prompt hatch internal or select
  ///
  /// In en, this message translates to:
  /// **'Specify internal point or [Select]:'**
  String get prompt_hatch_internal_or_select;

  /// prompt specify dim text location
  ///
  /// In en, this message translates to:
  /// **'Specify new location for dimension text:'**
  String get prompt_specify_dim_text_location;

  /// prompt specify polyline width
  ///
  /// In en, this message translates to:
  /// **'Specify new width for all segments:'**
  String get prompt_specify_polyline_width;

  /// prompt specify second break esc
  ///
  /// In en, this message translates to:
  /// **'Specify second break point (Escape to split):'**
  String get prompt_specify_second_break_esc;

  /// prompt specify second chamfer
  ///
  /// In en, this message translates to:
  /// **'Specify second chamfer distance:'**
  String get prompt_specify_second_chamfer;

  /// prompt specify second dest
  ///
  /// In en, this message translates to:
  /// **'Specify second destination point:'**
  String get prompt_specify_second_dest;

  /// prompt specify second diameter end
  ///
  /// In en, this message translates to:
  /// **'Specify second end of diameter:'**
  String get prompt_specify_second_diameter_end;

  /// prompt specify mirror second
  ///
  /// In en, this message translates to:
  /// **'Specify second point of mirror line:'**
  String get prompt_specify_mirror_second;

  /// prompt specify second on circle
  ///
  /// In en, this message translates to:
  /// **'Specify second point on circle:'**
  String get prompt_specify_second_on_circle;

  /// prompt specify second source or enter
  ///
  /// In en, this message translates to:
  /// **'Specify second source point or press Enter:'**
  String get prompt_specify_second_source_or_enter;

  /// prompt specify third on circle
  ///
  /// In en, this message translates to:
  /// **'Specify third point on circle:'**
  String get prompt_specify_third_on_circle;

  /// prompt enter units
  ///
  /// In en, this message translates to:
  /// **'Enter insertion units <{current}>:'**
  String prompt_enter_units(String current);

  /// prompt enter text style name
  ///
  /// In en, this message translates to:
  /// **'Enter text style name:'**
  String get prompt_enter_text_style_name;

  /// prompt enter layer to delete
  ///
  /// In en, this message translates to:
  /// **'Enter layer to delete:'**
  String get prompt_enter_layer_to_delete;

  /// prompt enter layer to isolate
  ///
  /// In en, this message translates to:
  /// **'Enter layer to isolate:'**
  String get prompt_enter_layer_to_isolate;

  /// prompt enter linetype
  ///
  /// In en, this message translates to:
  /// **'Enter a linetype (DASHED, ByLayer, …):'**
  String get prompt_enter_linetype;

  /// prompt enter a lineweight
  ///
  /// In en, this message translates to:
  /// **'Enter a lineweight (0.25 mm, 25, ByLayer):'**
  String get prompt_enter_a_lineweight;

  /// prompt select object to trim
  ///
  /// In en, this message translates to:
  /// **'Select an object to trim (Escape to finish):'**
  String get prompt_select_object_to_trim;

  /// prompt select object to extend
  ///
  /// In en, this message translates to:
  /// **'Select an object to extend (Escape to finish):'**
  String get prompt_select_object_to_extend;

  /// prompt scale objects align
  ///
  /// In en, this message translates to:
  /// **'Scale objects based on alignment points?'**
  String get prompt_scale_objects_align;

  /// prompt sheet width
  ///
  /// In en, this message translates to:
  /// **'Sheet width (mm):'**
  String get prompt_sheet_width;

  /// prompt sheet height
  ///
  /// In en, this message translates to:
  /// **'Sheet height (mm):'**
  String get prompt_sheet_height;

  /// prompt viewport scale
  ///
  /// In en, this message translates to:
  /// **'Viewport scale (model / paper):'**
  String get prompt_viewport_scale;

  /// prompt new layout name
  ///
  /// In en, this message translates to:
  /// **'New layout name:'**
  String get prompt_new_layout_name;

  /// prompt open recent
  ///
  /// In en, this message translates to:
  /// **'Open recent:'**
  String get prompt_open_recent;

  /// end
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// min
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get min;

  /// max
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get max;

  /// objects in drawing one
  ///
  /// In en, this message translates to:
  /// **'1 object in this drawing.'**
  String get objects_in_drawing_one;

  /// use
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// objects in drawing many
  ///
  /// In en, this message translates to:
  /// **'{count} objects in this drawing.'**
  String objects_in_drawing_many(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
