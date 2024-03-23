import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:rustup/rustup.dart';
import 'package:native_toolchain_rust/src/android_environment.dart';
import 'package:native_toolchain_rust/src/manifest.dart';

import 'package:path/path.dart' as path;

class RustBuilder {
  RustBuilder({
    required this.package,
    required this.toolchain,
    required this.manifestPath,
    required this.buildConfig,
    this.dartBuildFiles = const ['build.dart'],
    this.logger,
  });

  final String package;
  final RustupToolchain toolchain;
  final String manifestPath;
  final BuildConfig buildConfig;
  final List<String> dartBuildFiles;
  final Logger? logger;

  Future<void> run({required BuildOutput output}) async {
    final manifestPath = buildConfig.packageRoot.resolve(this.manifestPath);
    final manifestInfo = ManifestInfo.load(manifestPath);
    final outDir =
        buildConfig.outputDirectory.resolve('native_toolchain_rust/');

    if (buildConfig.dryRun) {
      output.addAsset(NativeCodeAsset(
        package: package,
        name: manifestInfo.packageName,
        linkMode: DynamicLoadingBundled(),
        os: buildConfig.targetOS,
      ));
      return;
    }

    final target = RustTarget.from(
      architecture: buildConfig.targetArchitecture!,
      os: buildConfig.targetOS,
      iosSdk: buildConfig.targetOS == OS.iOS ? buildConfig.targetIOSSdk : null,
    )!;

    if (!buildConfig.dryRun) {
      await toolchain.rustup.runCommand(
        [
          'run',
          toolchain.name,
          'cargo',
          'build',
          '--manifest-path',
          manifestPath.toFilePath(),
          '-p',
          manifestInfo.packageName,
          if (buildConfig.buildMode == BuildMode.release) '--release',
          '--target',
          target.triple,
          '--target-dir',
          outDir.toFilePath(),
        ],
        environment: _buildEnvironment(outDir, target),
        logger: logger,
      );
    }

    final effectiveOutDir = outDir
        .resolve('${target.triple}/')
        .resolve('${buildConfig.buildMode.name}/');

    final dylibName =
        buildConfig.targetOS.dylibFileName(manifestInfo.packageName);
    final asset = NativeCodeAsset(
      package: package,
      name: manifestInfo.packageName,
      os: buildConfig.targetOS,
      architecture: buildConfig.targetArchitecture,
      linkMode: DynamicLoadingBundled(),
      file: effectiveOutDir.resolve(dylibName),
    );
    output.addAsset(asset);
    if (!buildConfig.dryRun) {
      _addDependencies(
        output: output,
        effectiveOutDir: effectiveOutDir,
        dylibName: dylibName,
      );
    }
    for (final source in dartBuildFiles) {
      output.addDependency(
        buildConfig.packageRoot.resolve(source),
      );
    }
  }

  void _addDependencies({
    required BuildOutput output,
    required Uri effectiveOutDir,
    required String dylibName,
  }) {
    final dylibPath = effectiveOutDir.resolve(dylibName).toFilePath();
    final depFile = path.setExtension(dylibPath, '.d');
    final lines = File(depFile).readAsLinesSync();
    for (final line in lines) {
      final parts = line.split(':');
      if (parts[0] == dylibPath) {
        final dependencies = parts[1].trim().split(' ');
        for (final dependency in dependencies) {
          output.addDependency(Uri.file(dependency));
        }
      }
    }
  }

  Map<String, String> _buildEnvironment(Uri outDir, RustTarget target) {
    if (buildConfig.targetOS == OS.android) {
      final ndkInfo =
          NdkInfo.forCCompiler(buildConfig.cCompiler.compiler!.toFilePath())!;
      final env = AndroidEnvironment(
        ndkInfo: ndkInfo,
        minSdkVersion: buildConfig.targetAndroidNdkApi!,
        targetTempDir: outDir.toFilePath(),
        toolchain: toolchain,
        target: target,
      );
      return env.buildEnvironment();
    } else {
      return {};
    }
  }
}
