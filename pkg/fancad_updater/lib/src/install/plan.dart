/// How the app should finish an update.
enum InstallMode {
  /// Replace the install directory and relaunch, through a helper script.
  inPlace,

  /// Hand the downloaded package to the system: an installer wizard on
  /// Windows, a disk image on macOS.
  runInstaller,

  /// The app cannot install itself here; show the file instead.
  reveal,
}

/// Why an update fell back to [InstallMode.reveal]. The app maps these to
/// localised hints; the package does not own UI strings.
enum RevealReason { readOnly }

class InstallStep {
  const InstallStep(this.executable, this.arguments, {this.detached = false});

  final String executable;
  final List<String> arguments;

  /// A detached step must outlive this process: it is the installer that
  /// replaces us, so it cannot be a child we wait on.
  final bool detached;

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// A script the app writes next to the download before starting it.
///
/// The updater must be gone before its own files are replaced, so the last act
/// of the process is spawning this and exiting.
class HelperScript {
  const HelperScript({
    required this.path,
    required this.contents,
    required this.executable,
    required this.arguments,
  });

  final String path;
  final String contents;
  final String executable;
  final List<String> arguments;
}

class InstallPlan {
  const InstallPlan({
    required this.mode,
    required this.summary,
    this.helper,
    this.steps = const [],
    this.revealPath,
    this.revealReason,
  });

  final InstallMode mode;

  /// Diagnostic text for logs, not for the UI.
  final String summary;
  final HelperScript? helper;
  final List<InstallStep> steps;
  final String? revealPath;
  final RevealReason? revealReason;

  /// Whether this plan actually installs something.
  ///
  /// It is also the quit signal: an install replaces files the running process
  /// holds open, so the app must exit after starting it. A reveal installs
  /// nothing and the app stays open.
  bool get canInstall => mode != InstallMode.reveal;

  factory InstallPlan.reveal({
    required String path,
    required RevealReason reason,
    required String summary,
  }) => InstallPlan(
    mode: InstallMode.reveal,
    summary: summary,
    revealPath: path,
    revealReason: reason,
  );
}
