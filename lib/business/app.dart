import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import 'l10n/l10n.dart';
import 'theme/theme.dart';
import 'workbench/workbench.dart';

/// The application widget. Startup I/O stays in `main.dart` so this tree
/// can read settings synchronously from the first frame.
class FanCadApp extends ConsumerStatefulWidget {
  const FanCadApp({super.key, this.initialFiles = const []});

  final List<String> initialFiles;

  @override
  ConsumerState<FanCadApp> createState() => _FanCadAppState();
}

class _FanCadAppState extends ConsumerState<FanCadApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialFiles());
  }

  Future<void> _openInitialFiles() async {
    final workspace = ref.read(workspaceProvider);
    for (final path in widget.initialFiles) {
      await workspace.openFile(path);
    }
    if (workspace.tabs.isEmpty) {
      // Land on a usable drawing rather than on an empty shell, but only when
      // nothing was requested on the command line.
      workspace.newDocument(title: 'Drawing1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = ref.watch(themeBrightnessProvider);
    final language = ref.watch(languageProvider);
    return MaterialApp(
      title: 'FanCAD',
      debugShowCheckedModeBanner: false,
      theme: FanCadTheme.light(),
      darkTheme: FanCadTheme.dark(),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Workbench(),
    );
  }
}
