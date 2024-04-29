import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_rust/rustup.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:rustup/rustup.dart';
import 'package:native_toolchain_rust/src/android_environment.dart';
import 'package:native_toolchain_rust/src/crate_manifest.dart';

import 'package:path/path.dart' as path;

class RustToolchainException implements Exception {
  RustToolchainException({required this.message});

  final String message;

  @override
  String toString() {
    return message;
  }
}

class RunNativeDoctorException extends RustToolchainException {
  RunNativeDoctorException({required super.message});

  @override
  String toString() {
    return '$message\n'
        'Please run native_doctor in your project to fix the issue:\n'
        '-----------------------------------------------------------\n'
        'dart pub global activate native_doctor\n'
        'dart pub global run native_doctor\n'
        '-----------------------------------------------------------';
  }
}

class RustToolchain {
  final RustupToolchain toolchain;
  final String name;

  RustToolchain._({
    required this.name,
    required this.toolchain,
  });

  static Future<RustToolchain> withName(String name) async {
    final rustup = Rustup.systemRustup();
    if (rustup == null) {
      throw RunNativeDoctorException(message: 'Rustup not found.');
    }
    final toolchain = await rustup.getToolchain(name);
    if (toolchain == null) {
      throw RunNativeDoctorException(
          message: 'Rust toolchain $name not found.');
    }
    return RustToolchain._(name: toolchain.name, toolchain: toolchain);
  }

  static RustToolchain withRustupToolchain(RustupToolchain toolchain) {
    return RustToolchain._(name: toolchain.name, toolchain: toolchain);
  }

  Future<void> _checkTarget({
    required RustTarget target,
  }) async {
    final installedTargets = await toolchain.installedTargets();
    if (!installedTargets.contains(target)) {
      throw RunNativeDoctorException(
        message:
            'Rust target ${target.triple} not installed for toolchain $name.',
      );
    }
  }

  Future<void> _checkNativeManifest({
    required BuildConfig buildConfig,
  }) async {
    final manifest = NativeManifest.forPackage(buildConfig.packageRoot);
    if (manifest == null) {
      throw RustToolchainException(
        message: '`native_manifest.yaml` expected in package root.\n'
            'See https://pub.dev/packages/native_doctor more information and example manifest.',
      );
    }
    final requirements = manifest.requirements;
    final rustInfo = RustManifestInfo.parse(requirements['rust']!);
    for (final toolchainInfo in rustInfo.toolchainToVersion.entries) {
      if (toolchain.name.startsWith(toolchainInfo.key)) {
        final requiredVersion = toolchainInfo.value;
        final installedVersion = await toolchain.rustVersion();
        if (installedVersion < requiredVersion) {
          throw RunNativeDoctorException(
            message:
                'Rust toolchain $name is older than required version $requiredVersion.',
          );
        }
      }
    }
  }
}

class RustBuilder {
  RustBuilder({
    required this.package,
    this.toolchain,
    required this.crateManifestPath,
    required this.buildConfig,
    this.ignoreMissingNativeManifest = false,
    this.dartBuildFiles = const ['hook/build.dart'],
    this.logger,
  });

  /// Custom Rust toolchain to use (optional).
  final RustToolchain? toolchain;

  /// Package name. This will be part of asset Id.
  /// For example package `my_package` with crate name `my_crate` will have
  /// asset id `package:my_package/my_crate`:
  /// ```dart
  /// @ffi.DefaultAsset('package:my_package/my_crate')
  /// library rust;
  /// ```
  final String package;

  /// Path to the `Cargo.toml` file relative to the package root.
  final String crateManifestPath;

  /// Build config provided to the build callback from `native_assets_cli`.
  final BuildConfig buildConfig;

  /// Dart build files inside hook directory that should be added as
  /// dependencies. Default value adds `hook/build.dart` as dependency.
  final List<String> dartBuildFiles;

  /// By default `native_toolchain_rust` expects `native_manifest.yaml` in
  /// package root in order to check for required Rust version and also for
  /// `native_doctor` to work. If you don't want to include `native_manifest.yaml`
  /// in your package, set this to `true`.
  ///
  /// See https://pub.dev/packages/native_doctor for more information.
  final bool ignoreMissingNativeManifest;

  /// Optional logger for verbose output.
  final Logger? logger;

  Future<void> run({required BuildOutput output}) async {
    final toolchain = this.toolchain ?? await RustToolchain.withName('stable');

    final manifestPath = buildConfig.packageRoot.resolve(
      crateManifestPath,
    );
    final manifestInfo = CrateManifestInfo.load(manifestPath);
    final outDir =
        buildConfig.outputDirectory.resolve('native_toolchain_rust/');

    final dylibName =
        buildConfig.targetOS.dylibFileName(manifestInfo.packageName);

    if (buildConfig.dryRun) {
      output.addAsset(NativeCodeAsset(
        package: package,
        name: manifestInfo.packageName,
        linkMode: DynamicLoadingBundled(),
        os: buildConfig.targetOS,
        file: Uri.file(dylibName),
      ));
      return;
    }

    final target = RustTarget.from(
      architecture: buildConfig.targetArchitecture!,
      os: buildConfig.targetOS,
      iosSdk: buildConfig.targetOS == OS.iOS ? buildConfig.targetIOSSdk : null,
    )!;

    await toolchain._checkTarget(target: target);
    if (!ignoreMissingNativeManifest) {
      await toolchain._checkNativeManifest(buildConfig: buildConfig);
    }

    if (!buildConfig.dryRun) {
      await toolchain.toolchain.rustup.runCommand(
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
        environment: await _buildEnvironment(
          outDir,
          target,
          toolchain.toolchain,
        ),
        logger: logger,
      );
    }

    final effectiveOutDir = outDir
        .resolve('${target.triple}/')
        .resolve('${buildConfig.buildMode.name}/');

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

  Future<Map<String, String>> _buildEnvironment(
    Uri outDir,
    RustTarget target,
    RustupToolchain toolchain,
  ) async {
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
