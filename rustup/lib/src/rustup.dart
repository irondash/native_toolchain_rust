import 'dart:io';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:rustup/src/command.dart' as command;
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
    this.logger,
  });

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
      runCommand(['toolchain', 'install', name, '--profile', 'minimal']);
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
    final lines = await res.stdout
        .toString()
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

  Future<ProcessResult> runCommand(
    List<String> arguments, {
    Map<String, String>? environment,
    Logger? logger,
  }) {
    return command.runCommand(
      executablePath,
      arguments,
      environment: environment,
      logger: logger ?? this.logger,
    );
  }

  List<RustupToolchain>? _cachedToolchains;

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
  final Logger? logger;
}

class RustTarget {
  RustTarget({
    required this.target,
    required this.triple,
  });

  final Target target;
  final String triple;

  static RustTarget? fromTriple(String triple) {
    return Target.values
        .firstWhereOrNull((e) => e.toRust?.triple == triple)
        ?.toRust;
  }

  @override
  bool operator ==(Object other) {
    if (other is RustTarget) {
      return target == other.target && triple == other.triple;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(target, triple);
}

extension RustTargetExt on Target {
  RustTarget? get toRust {
    final triple = switch (this) {
      Target.androidArm => 'arm-linux-androideabi',
      Target.androidArm64 => 'armv7-linux-androideabi',
      Target.androidIA32 => 'i686-linux-android',
      Target.androidX64 => 'x86_64-linux-android',
      Target.androidRiscv64 => null,
      Target.fuchsiaArm64 => 'aarch64-unknown-fuchsia',
      Target.fuchsiaX64 => 'x86_64-unknown-fuchsia',
      Target.iOSArm => null,
      Target.iOSArm64 => 'aarch64-apple-ios',
      Target.iOSX64 => 'x86_64-apple-ios',
      Target.linuxArm => 'armv7-unknown-linux-gnueabi',
      Target.linuxArm64 => 'aarch64-unknown-linux-gnu',
      Target.linuxIA32 => 'i686-unknown-linux-gnu',
      Target.linuxRiscv32 => null,
      Target.linuxRiscv64 => 'riscv64gc-unknown-linux-gnu',
      Target.linuxX64 => 'x86_64-unknown-linux-gnu',
      Target.macOSArm64 => 'aarch64-apple-darwin',
      Target.macOSX64 => 'x86_64-apple-darwin',
      Target.windowsArm64 => 'aarch64-pc-windows-msvc',
      Target.windowsIA32 => 'i686-pc-windows-msvc',
      Target.windowsX64 => 'x86_64-pc-windows-msvc',
      _ => null,
    };
    return triple == null ? null : RustTarget(target: this, triple: triple);
  }
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
    final versionString = res.stdout.toString().split(' ')[1];
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
    final lines = res.stdout.toString().split('\n').where((e) => e.isNotEmpty);
    return lines
        .map((e) => RustTarget.fromTriple(e))
        .whereNotNull()
        .toList(growable: false);
  }

  List<RustTarget>? _cachedTargets;
}
