import 'dart:io';

import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Builds the FanCAD DWG shim against an in-tree LibreDWG.
///
/// LibreDWG is a git submodule at `native/third_party/libredwg`, compiled here
/// as a static PIC library and linked into `libfancad_io`. The application
/// binary does not load a Homebrew dylib at runtime, so a macOS sandbox (or a
/// machine without LibreDWG installed) cannot break DWG import.
///
/// A prebuilt prefix can still be forced with `libredwg_root` or
/// `FANCAD_LIBREDWG_ROOT` for people iterating on the parser itself.
void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    hierarchicalLoggingEnabled = true;
    final verbose = Platform.environment['FANCAD_BUILD_VERBOSE'] == '1';
    final logger = Logger('fancad_io')
      ..level = Level.ALL
      ..onRecord.listen((record) {
        if (!verbose && record.level < Level.WARNING) return;
        stderr.writeln('[fancad_io] ${record.level.name}: ${record.message}');
      });

    final nativeDirectory = input.packageRoot.resolve('native/fancad_io/');
    final sources = [
      nativeDirectory.resolve('fcb_builder.c').toFilePath(),
      nativeDirectory.resolve('fancad_io.c').toFilePath(),
      nativeDirectory.resolve('dwg_import.c').toFilePath(),
      nativeDirectory.resolve('dwg_export.c').toFilePath(),
    ];

    final libredwg = await _resolveLibreDwg(input, logger);

    if (libredwg != null) {
      logger.info('Linking LibreDWG from ${libredwg.root}');
      try {
        await _compile(
          input: input,
          output: output,
          logger: logger,
          sources: sources,
          includes: [nativeDirectory.toFilePath(), ...libredwg.includes],
          defines: {'FANCAD_HAVE_LIBREDWG': '1'},
          libraries: ['m'],
          libraryDirectories: const [],
          extraFlags: [
            if (Platform.isMacOS) '-mmacosx-version-min=12.0',
            libredwg.archive,
            if (Platform.isMacOS) '-liconv',
          ],
        );
        return;
      } catch (error) {
        logger.severe(
          'Compiling against LibreDWG at ${libredwg.root} failed: $error\n'
          'Falling back to a build without a DWG backend.',
        );
      }
    } else {
      logger.warning(
        'LibreDWG is unavailable (missing source or a failed in-tree build). '
        'Building without a DWG backend.',
      );
    }

    await _compile(
      input: input,
      output: output,
      logger: logger,
      sources: sources,
      includes: [nativeDirectory.toFilePath()],
      defines: const {},
      libraries: const [],
      libraryDirectories: const [],
      extraFlags: const [],
    );
  });
}

Future<void> _compile({
  required BuildInput input,
  required BuildOutputBuilder output,
  required Logger logger,
  required List<String> sources,
  required List<String> includes,
  required Map<String, String> defines,
  required List<String> libraries,
  required List<String> libraryDirectories,
  required List<String> extraFlags,
}) async {
  final builder = CBuilder.library(
    name: 'fancad_io',
    assetName: 'src/ffi/bindings.dart',
    sources: sources,
    includes: includes,
    defines: defines,
    libraries: libraries,
    libraryDirectories: ['.', ...libraryDirectories],
    std: 'c99',
    flags: ['-Wall', ...extraFlags],
  );
  await builder.run(input: input, output: output, logger: logger);
}

class _LibreDwg {
  const _LibreDwg({
    required this.root,
    required this.includes,
    required this.archive,
  });

  final String root;
  final List<String> includes;
  final String archive;
}

Future<_LibreDwg?> _resolveLibreDwg(BuildInput input, Logger logger) async {
  final forced = [
    ?input.userDefines['libredwg_root'] as String?,
    ?Platform.environment['FANCAD_LIBREDWG_ROOT'],
  ].where((path) => path.isNotEmpty);
  for (final prefix in forced) {
    final resolved = _probePrefix(prefix);
    if (resolved != null) return resolved;
    logger.warning('No usable LibreDWG at forced prefix $prefix');
  }

  final source = input.packageRoot
      .resolve('native/third_party/libredwg/')
      .toFilePath();
  if (!_looksLikeSource(source)) {
    if (Directory(source).existsSync()) {
      logger.warning(
        'LibreDWG at $source is not a usable source tree. '
        'If this is a git checkout, run `git submodule update --init --recursive`.',
      );
    }
    return null;
  }
  return _buildFromSource(source, input, logger);
}

bool _looksLikeSource(String root) {
  final hasHeader =
      File('$root/include/dwg.h').existsSync() ||
      File('$root/dwg.h').existsSync();
  final hasBuild =
      File('$root/CMakeLists.txt').existsSync() ||
      File('$root/configure').existsSync() ||
      File('$root/autogen.sh').existsSync();
  return hasHeader && hasBuild;
}

/// Configures and builds the submodule as a static PIC library.
///
/// The build lives under the hook's shared output directory so a `flutter run`
/// after the first compile does not rebuild several hundred C files.
Future<_LibreDwg?> _buildFromSource(
  String source,
  BuildInput input,
  Logger logger,
) async {
  final buildDir = input.outputDirectoryShared.resolve('libredwg-build/');
  Directory(buildDir.toFilePath()).createSync(recursive: true);
  final archive = _findArchive(buildDir.toFilePath());
  final stamp = File('${buildDir.toFilePath()}/.fancad-built');
  final marker = File(
    File('$source/configure').existsSync()
        ? '$source/configure'
        : '$source/CMakeLists.txt',
  );
  if (archive != null &&
      stamp.existsSync() &&
      stamp.lastModifiedSync().isAfter(marker.lastModifiedSync())) {
    logger.info('Reusing LibreDWG static library at $archive');
    return _fromSourceBuild(source, archive);
  }

  var rebuilt = false;
  if (File('$source/CMakeLists.txt').existsSync() && _which('cmake') != null) {
    rebuilt = await _cmakeBuild(source, buildDir.toFilePath(), logger);
    if (!rebuilt) {
      logger.warning(
        'cmake could not compile LibreDWG; trying autotools instead.',
      );
    }
  }
  if (!rebuilt) {
    final autoDir = '${buildDir.toFilePath()}/autotools';
    Directory(autoDir).createSync(recursive: true);
    if (await _ensureConfigure(source, logger)) {
      rebuilt = await _autotoolsBuild(source, autoDir, logger);
    } else if (!File('$source/CMakeLists.txt').existsSync()) {
      logger.severe(
        'LibreDWG has no usable build system. Install cmake, or autoconf so '
        'autogen.sh can produce configure.',
      );
    }
  }

  final built = _findArchive(buildDir.toFilePath());
  if (built == null) {
    logger.severe(
      'LibreDWG finished building but libredwg.a was not produced in '
      '${buildDir.toFilePath()}',
    );
    return null;
  }
  if (!rebuilt) {
    logger.warning(
      'Reusing an existing LibreDWG archive at $built after a failed rebuild',
    );
  }
  stamp.writeAsStringSync(built);
  return _fromSourceBuild(source, built);
}

_LibreDwg _fromSourceBuild(String source, String archive) {
  final headerDir = File('$source/dwg.h').existsSync()
      ? source
      : '$source/include';
  return _LibreDwg(root: source, includes: [headerDir], archive: archive);
}

String? _findArchive(String buildDir) {
  for (final path in [
    '$buildDir/libredwg.a',
    '$buildDir/src/libredwg.a',
    '$buildDir/src/.libs/libredwg.a',
    '$buildDir/Release/libredwg.a',
    '$buildDir/libredwg.lib',
    '$buildDir/Release/redwg.lib',
  ]) {
    if (File(path).existsSync()) return path;
  }
  final matches = Directory(buildDir)
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('libredwg.a') || file.path.endsWith('redwg.lib'),
      )
      .toList();
  return matches.isEmpty ? null : matches.first.path;
}

_LibreDwg? _probePrefix(String prefix) {
  final headerCandidates = [
    '$prefix/include/dwg.h',
    '$prefix/include/libredwg/dwg.h',
    '$prefix/dwg.h',
  ];
  final header = headerCandidates.firstWhere(
    (path) => File(path).existsSync(),
    orElse: () => '',
  );
  if (header.isEmpty) return null;

  for (final directory in [
    '$prefix/lib',
    '$prefix/lib64',
    '$prefix/src/.libs',
    prefix,
  ]) {
    for (final name in const ['libredwg.a', 'redwg.lib']) {
      final archive = '$directory/$name';
      if (File(archive).existsSync()) {
        return _LibreDwg(
          root: prefix,
          includes: [File(header).parent.path],
          archive: archive,
        );
      }
    }
  }
  return null;
}

Future<bool> _cmakeBuild(String source, String buildDir, Logger logger) async {
  logger.info('Configuring LibreDWG with cmake in $buildDir');
  // LibreDWG's generated config.h defines `_POSIX_C_SOURCE=200809L` so strdup
  // is visible. On Apple that hides `memmem`, while cmake's configure check
  // still finds the symbol. The compile then dies on an undeclared `memmem`
  // and the hook used to fall back to a build that cannot open DWG at all.
  final configure = await Process.run(_which('cmake')!, [
    '-S',
    source,
    '-B',
    buildDir,
    '-DBUILD_SHARED_LIBS=OFF',
    '-DLIBREDWG_LIBONLY=ON',
    '-DBUILD_TESTING=OFF',
    '-DENABLE_LTO=OFF',
    '-DDISABLE_WERROR=ON',
    '-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
    if (Platform.isMacOS) ...[
      '-DCMAKE_C_FLAGS=-D_DARWIN_C_SOURCE',
      '-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0',
    ],
  ]);
  if (configure.exitCode != 0) {
    logger.severe(
      'cmake configure failed:\n${configure.stdout}\n${configure.stderr}',
    );
    return false;
  }
  logger.info('Compiling LibreDWG (first run only)');
  final build = await Process.run(_which('cmake')!, [
    '--build',
    buildDir,
    '--config',
    'Release',
    '-j',
    '${Platform.numberOfProcessors}',
  ]);
  if (build.exitCode != 0) {
    logger.severe('cmake build failed:\n${build.stdout}\n${build.stderr}');
    return false;
  }
  return true;
}

/// Git checkouts ship `autogen.sh` instead of a generated `configure`.
Future<bool> _ensureConfigure(String source, Logger logger) async {
  if (File('$source/configure').existsSync()) return true;
  if (!File('$source/autogen.sh').existsSync()) return false;
  logger.info('Running autogen.sh for LibreDWG');
  final result = await Process.run(
    './autogen.sh',
    const [],
    workingDirectory: source,
  );
  if (result.exitCode != 0) {
    logger.severe('autogen.sh failed:\n${result.stdout}\n${result.stderr}');
    return false;
  }
  return File('$source/configure').existsSync();
}

Future<bool> _autotoolsBuild(
  String source,
  String buildDir,
  Logger logger,
) async {
  logger.info('Configuring LibreDWG with autotools in $buildDir');
  final configure = await Process.run(
    '$source/configure',
    const [
      '--disable-shared',
      '--enable-static',
      '--disable-bindings',
      '--disable-python',
      '--disable-werror',
    ],
    workingDirectory: buildDir,
    environment: {
      ...Platform.environment,
      if (Platform.isMacOS) 'MACOSX_DEPLOYMENT_TARGET': '12.0',
      'CFLAGS':
          '-O2 -fPIC${Platform.isMacOS ? ' -mmacosx-version-min=12.0' : ''} '
                  '${Platform.environment['CFLAGS'] ?? ''}'
              .trim(),
    },
  );
  if (configure.exitCode != 0) {
    logger.severe(
      'configure failed:\n${configure.stdout}\n${configure.stderr}',
    );
    return false;
  }
  logger.info('Compiling LibreDWG (first run only)');
  final build = await Process.run('make', [
    '-j',
    '${Platform.numberOfProcessors}',
    '-C',
    'src',
  ], workingDirectory: buildDir);
  if (build.exitCode != 0) {
    logger.severe('make failed:\n${build.stdout}\n${build.stderr}');
    return false;
  }
  return true;
}

String? _which(String name) {
  final result = Process.runSync('which', [name]);
  if (result.exitCode != 0) return null;
  final path = (result.stdout as String).trim();
  return path.isEmpty ? null : path;
}
