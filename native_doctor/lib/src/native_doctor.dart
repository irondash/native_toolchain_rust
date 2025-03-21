import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/code_assets.dart';
import 'package:native_doctor/src/checkers/ndk.dart';
import 'package:native_doctor/src/writer.dart';
import 'package:native_doctor/src/checkers/rustup.dart';
import 'package:native_doctor/src/tool_error.dart';
import 'package:native_doctor/src/toolchain_checker.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:package_config/package_config.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

class ToolOptions {
  ToolOptions({
    required this.yes,
    required this.verbose,
    required this.path,
    required this.writer,
  });

  final bool verbose;
  final bool yes;
  final Directory path;
  final Writer writer;
}

class NativeDoctor {
  NativeDoctor({
    required this.options,
    required this.packageConfig,
    required this.pubspec,
    required this.projectPlatforms,
    this.flutterRoot,
  });

  final ToolOptions options;
  final PackageConfig packageConfig;
  final Pubspec pubspec;
  final List<OS> projectPlatforms;
  final Uri? flutterRoot;

  Writer get writer => options.writer;
  final verboseLogger = Logger('verbose');

  static Future<NativeDoctor> withOptions(ToolOptions options) async {
    final projectUri = Uri.directory(options.path.path);

    final pubspecUri = projectUri.resolve('pubspec.yaml');
    final pubspecFile = File.fromUri(pubspecUri);
    if (!await pubspecFile.exists()) {
      throw ToolError(
          'Could not find pubspec.yaml in "${projectUri.toFilePath()}".\n'
          'Path must be a Dart or Flutter project.');
    }
    final pubspecContent = await pubspecFile.readAsString();
    final pubspec = Pubspec.parse(pubspecContent, sourceUrl: pubspecUri);

    final packageConfig = await findPackageConfig(options.path);
    if (packageConfig == null) {
      throw ToolError(
        'Could not find package config. Make sure to run `pub get` first.',
      );
    }
    Uri? flutterRoot;

    final packageConfigExtraData = packageConfig.extraData;
    if (pubspec.dependencies["flutter"] != null &&
        packageConfigExtraData is Map) {
      final root = packageConfigExtraData['flutterRoot'] as String?;
      if (root != null) {
        flutterRoot = Uri.parse(root);
      }
    }

    final List<OS> projectPlatforms;
    if (flutterRoot != null) {
      projectPlatforms = OS.values.where((value) {
        final platformPath = projectUri.resolve(value.toString()).toFilePath();
        final platformDir = Directory(platformPath);
        return platformDir.existsSync();
      }).toList(growable: false);
    } else {
      projectPlatforms = <OS>[];
    }

    return NativeDoctor(
      options: options,
      packageConfig: packageConfig,
      pubspec: pubspec,
      projectPlatforms: projectPlatforms,
      flutterRoot: flutterRoot,
    );
  }

  bool get hostOnly {
    return projectPlatforms.isEmpty;
  }

  List<OS> get targetPlatforms {
    final systems = switch (OS.current) {
      OS.macOS => [OS.macOS, OS.iOS, OS.android],
      OS.windows => [OS.windows, OS.android],
      OS.linux => [OS.linux, OS.android],
      final OS os => throw ToolError('Unsupported host system: $os'),
    };
    return systems.where(projectPlatforms.contains).toList(growable: false);
  }

  Future<void> run() async {
    verboseLogger.level = options.verbose ? Level.ALL : Level.OFF;

    final projectType = flutterRoot != null ? 'Flutter' : 'Dart';
    writer.printMessage(
      'Project: ${writer.bolden(pubspec.name)} ($projectType)',
    );
    final platforms = hostOnly ? 'host only' : targetPlatforms.join(', ');
    writer.printMessage('Buildable platforms: ${writer.bolden(platforms)}');

    writer.emptyLine();

    final manifests = NativeManifest.forPackageConfig(
      packageConfig,
      verboseLogger: verboseLogger,
    );

    if (manifests.isEmpty) {
      writer.printMessage(
        'No dependency containing ${NativeManifest.fileName} found. Nothing to check.',
      );
      writer.emptyLine();
      return;
    }

    final checkers = [
      NdkToolchainChecker(doctor: this),
      RustToolchainChecker(doctor: this),
    ];

    final proposedActions = <(String, ProposedAction)>[];

    for (final checker in checkers) {
      for (final manifest in manifests) {
        final context = ManifestContext(
          manifestVersion: manifest.version,
        );
        final node = manifest.requirements[checker.manifestKey];
        if (node != null) {
          await checker.updateFromManifest(context, node);
        }
      }

      final result = await checker.validate();
      if (result != null) {
        writer.printMessage(
            'Native toolchain: ${writer.bolden(checker.displayName)}');
        writer.emptyLine();
        for (final section in result.sections) {
          final prefix = section.ok ? '[✓]' : '[✗]';
          final color = section.ok ? TextColor.green : TextColor.red;
          writer.printMessage(
            section.title,
            prefix: '  $prefix ',
            prefixColor: color,
          );
          for (final message in section.messages) {
            final prefix = message.ok ? '•' : '!';
            final color = message.ok ? TextColor.green : TextColor.red;
            writer.printMessage(
              message.message,
              prefix: '       $prefix ',
              prefixColor: color,
            );
          }
        }
        writer.emptyLine();
        proposedActions.addAll(
          result.proposedActions.map(
            (action) => (checker.displayName, action),
          ),
        );
      }
    }

    if (proposedActions.isNotEmpty) {
      writer.printMessage(
        writer.color(
          writer.bolden('Proposed actions:'),
          TextColor.cyan,
        ),
      );
      writer.emptyLine();

      final maxCheckerLength =
          maxBy(proposedActions.map((action) => action.$1.length), (a) => a);
      for (final (checkerName, action) in proposedActions) {
        writer.printMessage(
          action.description,
          prefix:
              '  • ($checkerName) '.padRight(11 - 4 + maxCheckerLength!, ' '),
          prefixColor: TextColor.cyan,
        );
      }

      writer.emptyLine();
      if (!writer.hasTerminal && !options.yes) {
        writer.printMessage(
          'Run native doctor in terminal or with ${writer.bolden('-y')} to perform proposed actions.',
        );
        return;
      }
      if (!options.yes) {
        writer.printMessage(
          writer.bolden(
              'Do you want native doctor to perform proposed actions? (y/N)'),
        );
        final input = stdin.readLineSync();
        if (input != 'y') {
          return;
        }
      }

      for (final checker in checkers) {
        await checker.fix(writer);
      }
    } else {
      writer.printMessage(writer.bolden('No issues found!'));
    }

    writer.emptyLine();
  }
}

const String version = '0.0.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output.',
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Answer yes to all prompts.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the tool version.',
    )
    ..addOption(
      'path',
      help: 'Path to project root (optional)',
    );
}

void printUsage(ArgParser argParser, Writer writer) {
  writer.printMessage('Usage: native_doctor <flags> [arguments]');
  writer.printMessage(argParser.usage, prefix: '  ');
}

void run(List<String> arguments) async {
  final writer = AnsiWriter();
  final ArgParser argParser = buildParser();
  final ArgResults results;
  try {
    results = argParser.parse(arguments);
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    writer.printMessage(e.message);
    writer.emptyLine();
    printUsage(argParser, writer);
    exit(1);
  }

  // Process the parsed arguments.
  if (results.wasParsed('help')) {
    printUsage(argParser, writer);
    return;
  }
  if (results.wasParsed('version')) {
    print('native_doctor version: $version');
    return;
  }

  try {
    final options = ToolOptions(
      verbose: results.wasParsed('verbose'),
      yes: results.wasParsed('yes'),
      path: results.wasParsed('path')
          ? Directory(results['path'])
          : Directory.current,
      writer: writer,
    );

    if (options.path.existsSync()) {
      final doctor = await NativeDoctor.withOptions(options);
      doctor.run();
    } else {
      throw ToolError('Project path ${options.path.path} does not exist.');
    }
  } on Exception catch (e) {
    writer.emptyLine();
    writer.printMessage(writer.color(
      'Native doctor failed with error:',
      TextColor.red,
    ));
    writer.emptyLine();
    writer.printMessage(e.toString());
    exit(1);
  }
}
