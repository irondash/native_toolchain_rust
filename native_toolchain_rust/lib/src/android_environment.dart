import 'dart:io';

import 'package:collection/collection.dart';
import 'package:native_assets_cli/code_assets.dart';
import 'package:native_toolchain_rust/rustup.dart';
import 'package:native_toolchain_rust/src/android_linker_wrapper.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';

class NdkInfo {
  NdkInfo({
    required this.toolchainPath,
    required this.ndkVersion,
  });

  /// Path for NDK toolchain bin directory.
  final String toolchainPath;

  /// NDK version.
  final Version ndkVersion;

  static NdkInfo? forCCompiler(String cCompiler) {
    final toolchainPath = path.dirname(cCompiler);
    var p = toolchainPath;
    while (true) {
      final manifest = File(path.join(p, 'source.properties'));
      if (manifest.existsSync()) {
        final lines = manifest.readAsLinesSync();
        String? pkgDesc;
        String? pkgRevision;
        for (final line in lines) {
          final elements = line.split('=');
          if (elements.length != 2) {
            continue;
          }
          final key = elements[0].trim();
          final value = elements[1].trim();
          if (key == 'Pkg.Desc') {
            pkgDesc = value;
          } else if (key == 'Pkg.Revision') {
            pkgRevision = value;
          }
        }
        if (pkgDesc != 'Android NDK' || pkgRevision == null) {
          return null;
        }
        final version = Version.parse(pkgRevision);
        return NdkInfo(
          toolchainPath: toolchainPath,
          ndkVersion: version,
        );
      }
      final parent = path.normalize(path.join(p, '..'));
      if (parent == p) {
        break;
      }
      p = parent;
    }
    return null;
  }
}

class AndroidEnvironment {
  AndroidEnvironment({
    required this.ndkInfo,
    required this.minSdkVersion,
    required this.targetTempDir,
    required this.toolchain,
    required this.target,
  });

  /// Info about the NDK being used.
  final NdkInfo ndkInfo;

  /// Minimum supported SDK version.
  final int minSdkVersion;

  /// Target directory for build artifacts.
  final String targetTempDir;

  /// Toolchain being used.
  final RustupToolchain toolchain;

  /// Target being built.
  final RustTarget target;

  Future<Map<String, String>> buildEnvironment() async {
    final toolchainPath = ndkInfo.toolchainPath;

    final arKey = 'AR_${target.triple}';
    final arValue = ['${target.triple}-ar', 'llvm-ar', 'llvm-ar.exe']
        .map((e) => path.join(toolchainPath, e))
        .firstWhereOrNull((element) => File(element).existsSync());
    if (arValue == null) {
      throw Exception('Failed to find ar for $target in $toolchainPath');
    }

    final targetArg = '--target=${target.triple}$minSdkVersion';

    final ccKey = 'CC_${target.triple}';
    final ccValue = path.join(
      toolchainPath,
      OS.current.executableFileName('clang'),
    );
    final cfFlagsKey = 'CFLAGS_${target.triple}';
    final cFlagsValue = targetArg;

    final cxxKey = 'CXX_${target.triple}';
    final cxxValue = path.join(
      toolchainPath,
      OS.current.executableFileName('clang++'),
    );
    final cxxFlagsKey = 'CXXFLAGS_${target.triple}';
    final cxxFlagsValue = targetArg;

    final linkerKey =
        'cargo_target_${target.triple.replaceAll('-', '_')}_linker'
            .toUpperCase();

    final ranlibKey = 'RANLIB_${target.triple}';
    final ranlibValue = path.join(
      toolchainPath,
      OS.current.executableFileName('llvm-ranlib'),
    );

    final rustFlagsKey = 'CARGO_ENCODED_RUSTFLAGS';
    final rustFlagsValue = _libGccWorkaround(targetTempDir, ndkInfo.ndkVersion);

    final wrapper = AndroidLinkerWrapper(
      tempDir: targetTempDir,
      toolchain: toolchain,
    );

    return {
      arKey: arValue,
      ccKey: ccValue,
      cfFlagsKey: cFlagsValue,
      cxxKey: cxxValue,
      cxxFlagsKey: cxxFlagsValue,
      ranlibKey: ranlibValue,
      rustFlagsKey: rustFlagsValue,
      linkerKey: await wrapper.linkerWrapperPath(),
      // Recognized by main() so we know when we're acting as a wrapper
      '_CARGOKIT_NDK_LINK_TARGET': targetArg,
      '_CARGOKIT_NDK_LINK_CLANG': ccValue,
    };
  }

  // Workaround for libgcc missing in NDK23, inspired by cargo-ndk
  String _libGccWorkaround(String buildDir, Version ndkVersion) {
    final workaroundDir = path.join(
      buildDir,
      'cargokit',
      'libgcc_workaround',
      '${ndkVersion.major}',
    );
    Directory(workaroundDir).createSync(recursive: true);
    if (ndkVersion.major >= 23) {
      File(path.join(workaroundDir, 'libgcc.a'))
          .writeAsStringSync('INPUT(-lunwind)');
    } else {
      // Other way around, untested, forward libgcc.a from libunwind once Rust
      // gets updated for NDK23+.
      File(path.join(workaroundDir, 'libunwind.a'))
          .writeAsStringSync('INPUT(-lgcc)');
    }

    var rustFlags = Platform.environment['CARGO_ENCODED_RUSTFLAGS'] ?? '';
    if (rustFlags.isNotEmpty) {
      rustFlags = '$rustFlags\x1f';
    }
    rustFlags = '$rustFlags-L\x1f$workaroundDir';
    return rustFlags;
  }
}
