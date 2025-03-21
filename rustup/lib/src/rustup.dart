import 'dart:io';
import 'package:native_assets_cli/code_assets.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart'
    as common;
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:rustup/src/mutex.dart';

final _mutex = Mutex();

class Rustup {
  /// Returns rustup in user PATH.
  static Rustup? systemRustup({Logger? logger}) {
    final executablePath = _findExecutablePath();
    return executablePath == null
        ? null
        : Rustup(executablePath: executablePath, logger: logger);
  }

  Rustup({
    required this.executablePath,
    this.rustupHome,
    this.cargoHome,
    this.logger,
  });

  List<RustupToolchain>? _cachedToolchains;

  Future<List<RustupToolchain>> installedToolchains() async {
    return await _mutex.protect(() async {
      _cachedToolchains ??= await _getInstalledToolchains();
      return _cachedToolchains!;
    });
  }

  Future<RustupToolchain?> getToolchain(String name) async {
    return (await installedToolchains()).firstWhereOrNull(
      (e) => e.name == name || e.name.startsWith('$name-'),
    );
  }

  Future<void> installToolchain(String name) async {
    return await _mutex.protect(() async {
      _cachedToolchains = null;
      await runCommand(['toolchain', 'install', name, '--profile', 'minimal']);
    });
  }

  Future<List<RustupToolchain>> _getInstalledToolchains() async {
    String extractToolchainName(String line) {
      // ignore (default) after toolchain name
      final parts = line.split(' ');
      return parts[0];
    }

    final res = await runCommand(['toolchain', 'list']);

    // To list all non-custom toolchains, we need to filter out lines that
    // don't start with "stable", "beta", or "nightly".
    Pattern nonCustom = RegExp(r"^(stable|beta|nightly)");
    final lines = res
        .split('\n')
        .where((e) => e.isNotEmpty && e.startsWith(nonCustom))
        .map(extractToolchainName)
        .toList(growable: true);

    return lines
        .map(
          (name) => RustupToolchain(
            name: name,
            rustup: this,
          ),
        )
        .toList(growable: true);
  }

  Future<void> uninstall() {
    return runCommand(['self', 'uninstall', '-y']);
  }

  Future<String> runCommand(
    List<String> arguments, {
    Map<String, String>? environment,
    Logger? logger,
  }) {
    return common.runCommand(
      executablePath,
      arguments,
      environment: {
        if (environment != null) ...environment,
        if (rustupHome != null) 'RUSTUP_HOME': rustupHome!,
        if (cargoHome != null) 'CARGO_HOME': cargoHome!,
      },
      logger: logger ?? this.logger,
    );
  }

  /// Returns the path to the `rustup` executable, or `null` if it is not found.
  static String? _findExecutablePath() {
    final envPath = Platform.environment['PATH'];
    final envPathSeparator = Platform.isWindows ? ';' : ':';
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    final paths = [
      if (home != null) path.join(home, '.cargo', 'bin'),
      if (envPath != null) ...envPath.split(envPathSeparator),
    ];
    for (final p in paths) {
      final rustup = Platform.isWindows ? 'rustup.exe' : 'rustup';
      final rustupPath = path.join(p, rustup);
      if (File(rustupPath).existsSync()) {
        return rustupPath;
      }
    }
    return null;
  }

  final String executablePath;
  final String? rustupHome;
  final String? cargoHome;
  final Logger? logger;
}

class RustTarget {
  RustTarget({
    required this.architecture,
    required this.os,
    required this.triple,
    this.iosSdk,
  });

  final Architecture architecture;
  final OS os;
  final IOSSdk? iosSdk;
  final String triple;

  static RustTarget? fromTriple(String triple) {
    return _targets.firstWhereOrNull((e) => e.triple == triple);
  }

  static RustTarget? from({
    required Architecture architecture,
    required OS os,
    required IOSSdk? iosSdk,
  }) {
    return _targets.firstWhereOrNull(
      (e) => e.architecture == architecture && e.os == os && e.iosSdk == iosSdk,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is RustTarget) {
      return os == other.os &&
          architecture == other.architecture &&
          iosSdk == other.iosSdk &&
          triple == other.triple;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        os,
        architecture,
        iosSdk,
        triple,
      );

  @override
  String toString() => triple;

  static List<RustTarget> get allTargets => _targets;

  static final _targets = [
    RustTarget(
      os: OS.android,
      architecture: Architecture.arm,
      triple: 'arm-linux-androideabi',
    ),
    RustTarget(
      os: OS.android,
      architecture: Architecture.arm64,
      triple: 'aarch64-linux-android',
    ),
    RustTarget(
      os: OS.android,
      architecture: Architecture.ia32,
      triple: 'i686-linux-android',
    ),
    RustTarget(
      os: OS.android,
      architecture: Architecture.x64,
      triple: 'x86_64-linux-android',
    ),
    RustTarget(
      os: OS.fuchsia,
      architecture: Architecture.arm64,
      triple: 'aarch64-unknown-fuchsia',
    ),
    RustTarget(
      os: OS.fuchsia,
      architecture: Architecture.x64,
      triple: 'x86_64-unknown-fuchsia',
    ),
    RustTarget(
      os: OS.iOS,
      iosSdk: IOSSdk.iPhoneOS,
      architecture: Architecture.arm64,
      triple: 'aarch64-apple-ios',
    ),
    RustTarget(
      os: OS.iOS,
      iosSdk: IOSSdk.iPhoneSimulator,
      architecture: Architecture.x64,
      triple: 'x86_64-apple-ios',
    ),
    RustTarget(
      os: OS.iOS,
      iosSdk: IOSSdk.iPhoneSimulator,
      architecture: Architecture.arm64,
      triple: 'aarch64-apple-ios-sim',
    ),
    RustTarget(
      os: OS.macOS,
      architecture: Architecture.arm64,
      triple: 'aarch64-apple-darwin',
    ),
    RustTarget(
      os: OS.macOS,
      architecture: Architecture.x64,
      triple: 'x86_64-apple-darwin',
    ),
    RustTarget(
      os: OS.windows,
      architecture: Architecture.arm64,
      triple: 'aarch64-pc-windows-msvc',
    ),
    RustTarget(
      os: OS.windows,
      architecture: Architecture.ia32,
      triple: 'i686-pc-windows-msvc',
    ),
    RustTarget(
      os: OS.windows,
      architecture: Architecture.x64,
      triple: 'x86_64-pc-windows-msvc',
    ),
    RustTarget(
      os: OS.linux,
      architecture: Architecture.arm64,
      triple: 'aarch64-unknown-linux-gnu',
    ),
    RustTarget(
      os: OS.linux,
      architecture: Architecture.x64,
      triple: 'x86_64-unknown-linux-gnu',
    ),
  ];
}

class RustupToolchain {
  RustupToolchain({
    required this.name,
    required this.rustup,
  });

  final String name;
  final Rustup rustup;

  Future<Version> rustVersion() async {
    final res = await rustup.runCommand(['run', name, 'rustc', '--version']);
    final versionString = res.split(' ')[1];
    return Version.parse(versionString);
  }

  Future<List<RustTarget>> installedTargets() async {
    return await _mutex.protect(() async {
      _cachedTargets ??= await _getInstalledTargets();
      return _cachedTargets!;
    });
  }

  Future<void> installTarget(RustTarget target) async {
    return await _mutex.protect(() async {
      _cachedTargets = null;
      await rustup
          .runCommand(['target', 'add', target.triple, '--toolchain', name]);
    });
  }

  Future<List<RustTarget>> _getInstalledTargets() async {
    final res = await rustup.runCommand([
      'target',
      'list',
      '--toolchain',
      name,
      '--installed',
    ]);
    final lines = res.toString().split('\n').where((e) => e.isNotEmpty);
    return lines
        .map((e) => RustTarget.fromTriple(e))
        .nonNulls
        .toList(growable: false);
  }

  List<RustTarget>? _cachedTargets;
}
