import 'settings.dart';

/// Command-pane height in `settings.json`. Expansion and the palette are
/// session-only and stay on the command-line notifier.
class CommandLineSettings {
  CommandLineSettings(this._store);

  final SettingsStore _store;

  double paneHeight({double fallback = 0}) =>
      _store.getDouble(SettingsKeys.commandPaneHeight, fallback: fallback);

  void setPaneHeight(double value) =>
      _store.set(SettingsKeys.commandPaneHeight, value);
}
