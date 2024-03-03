import 'dart:io';
import 'package:collection/collection.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_rust/src/command.dart';
import 'package:path/path.dart' as path;

class Rustup {
  /// Returns rustup in user PATH.
  static Rustup? systemRustup() {
    final executablePath = _findExecutablePath();
    return executablePath == null
        ? null
        : Rustup(executablePath: executablePath);
  }

  Rustup({
    required this.executablePath,
  });

  List<RustupToolchain> installedToolchains() {
    _cachedToolchains ??= _getInstalledToolchains();
    return _cachedToolchains!;
  }

  void installToolchain(String name) {
    _cachedToolchains = null;
    _runCommand(['toolchain', 'install', name, '--profile', 'minimal']);
  }

  List<RustupToolchain> _getInstalledToolchains() {
    String extractToolchainName(String line) {
      // ignore (default) after toolchain name
      final parts = line.split(' ');
      return parts[0];
    }

    final res = _runCommand(['toolchain', 'list']);

    // To list all non-custom toolchains, we need to filter out lines that
    // don't start with "stable", "beta", or "nightly".
    Pattern nonCustom = RegExp(r"^(stable|beta|nightly)");
    final lines = res.stdout
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

  ProcessResult _runCommand(List<String> arguments) {
    return runCommand(executablePath, arguments);
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

  List<RustTarget> installedTargets() {
    _cachedTargets ??= _getInstalledTargets();
    return _cachedTargets!;
  }

  void installTarget(RustTarget target) {
    _cachedTargets = null;
    rustup._runCommand(['target', 'add', target.triple, '--toolchain', name]);
  }

  List<RustTarget> _getInstalledTargets() {
    final res = runCommand("rustup", [
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
