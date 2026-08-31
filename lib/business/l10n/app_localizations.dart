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

  /// appearance dark tooltip
  ///
  /// In en, this message translates to:
  /// **'Appearance — Dark. Choose Light or Dark'**
  String get appearance_dark_tooltip;

  /// appearance light tooltip
  ///
  /// In en, this message translates to:
  /// **'Appearance — Light. Choose Light or Dark'**
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
  /// **'Start a command from the toolbar, type an alias such as L or C, or pick one below.'**
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
