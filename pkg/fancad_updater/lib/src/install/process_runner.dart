import 'dart:io';

class ProcessOutcome {
  const ProcessOutcome({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get isSuccess => exitCode == 0;
}

/// Runs the helper scripts. Swappable so install planning can be tested
/// without spawning anything.
abstract interface class ProcessRunner {
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    bool detached = false,
  });
}

class ProcessRunException implements Exception {
  const ProcessRunException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IoProcessRunner implements ProcessRunner {
  const IoProcessRunner();

  @override
  Future<ProcessOutcome> run(
    String executable,
    List<String> arguments, {
    bool detached = false,
  }) async {
    try {
      if (detached) {
        await Process.start(
          executable,
          arguments,
          mode: ProcessStartMode.detached,
        );
        return const ProcessOutcome(exitCode: 0);
      }
      final result = await Process.run(executable, arguments);
      return ProcessOutcome(
        exitCode: result.exitCode,
        stdout: '${result.stdout}',
        stderr: '${result.stderr}',
      );
    } on ProcessException catch (error) {
      throw ProcessRunException('$executable: ${error.message}');
    }
  }
}
