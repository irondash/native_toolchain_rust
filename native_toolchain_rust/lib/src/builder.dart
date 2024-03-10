import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:rustup/rustup.dart';
import 'package:native_toolchain_rust/src/android_environment.dart';
import 'package:native_toolchain_rust/src/manifest.dart';

import 'package:path/path.dart' as path;

class RustBuilder {
  RustBuilder({
    required this.assetId,
    required this.toolchain,
    required this.manifestPath,
    required this.buildConfig,
    this.dartBuildFiles = const ['build.dart'],
    this.logger,
  });

  final String assetId;
  final RustupToolchain toolchain;
  final String manifestPath;
  final BuildConfig buildConfig;
  final List<String> dartBuildFiles;
  final Logger? logger;

  Future<void> run({required BuildOutput output}) async {
    final manifestPath = buildConfig.packageRoot.resolve(this.manifestPath);
    final manifestInfo = ManifestInfo.load(manifestPath);
    final outDir = buildConfig.outDir.resolve('native_toolchain_rust/');
    final targetTriple = buildConfig.target.toRust!.triple;

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
          targetTriple,
          '--target-dir',
          outDir.toFilePath(),
        ],
        environment: _buildEnvironment(outDir),
        logger: logger,
      );
    }

    final effectiveOutDir = outDir
        .resolve('$targetTriple/')
        .resolve('${buildConfig.buildMode.name}/');

    final dylibName =
        buildConfig.targetOs.dylibFileName(manifestInfo.packageName);
    final asset = Asset(
      id: assetId,
      linkMode: LinkMode.dynamic,
      target: buildConfig.target,
      path: AssetAbsolutePath(effectiveOutDir.resolve(dylibName)),
    );
    output.assets.add(asset);
    if (!buildConfig.dryRun) {
      _addDependencies(
        output: output,
        effectiveOutDir: effectiveOutDir,
        dylibName: dylibName,
      );
    }
    for (final source in this.dartBuildFiles) {
      output.dependencies.dependencies.add(
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
          output.dependencies.dependencies.add(Uri.file(dependency));
        }
      }
    }
  }

  Map<String, String> _buildEnvironment(Uri outDir) {
    if (buildConfig.targetOs == OS.android) {
      final ndkInfo =
          NdkInfo.forCCompiler(buildConfig.cCompiler.cc!.toFilePath())!;
      final env = AndroidEnvironment(
        ndkInfo: ndkInfo,
        minSdkVersion: buildConfig.targetAndroidNdkApi!,
        targetTempDir: outDir.toFilePath(),
        toolchain: toolchain,
        target: buildConfig.target.toRust!,
      );
      return env.buildEnvironment();
    } else {
      return {};
    }
  }
}
