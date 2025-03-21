import 'dart:io';

import 'package:collection/collection.dart';
import 'package:native_assets_cli/code_assets.dart';
import 'package:native_doctor/src/android_sdk.dart';
import 'package:native_doctor/src/native_doctor.dart';
import 'package:native_doctor/src/toolchain_checker.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

class _Ndk {
  _Ndk({
    required this.version,
    required this.uri,
  });

  final Version version;
  final Uri uri;
}

class NdkToolchainChecker extends ToolchainChecker {
  NdkToolchainChecker({
    required this.doctor,
  });

  final NativeDoctor doctor;

  @override
  String get displayName => 'NDK';

  @override
  String get manifestKey => 'ndk';

  Version? minimumVersion;

  @override
  @override
  Future<void> updateFromManifest(
    ManifestContext context,
    YamlNode manifestNode,
  ) async {
    final manifestInfo = NdkManifestInfo.parse(manifestNode);
    if (minimumVersion == null || minimumVersion! < manifestInfo.version) {
      minimumVersion = manifestInfo.version;
    }
  }

  AndroidSdkInfo? _sdkInfo;

  Future<List<_Ndk>> _findInstalledNdks() async {
    final sdkRoot = _sdkInfo?.androidSdk;
    if (sdkRoot == null) {
      return [];
    }

    final ndkRoot = Uri.directory(sdkRoot).resolve('ndk');
    final ndkDir = Directory.fromUri(ndkRoot);
    if (!await ndkDir.exists()) {
      return [];
    }

    final result = <_Ndk>[];

    final ndkDirs = await ndkDir.list().toList();
    for (final dir in ndkDirs) {
      final sourceProperties =
          File.fromUri(dir.uri.resolve('source.properties'));
      if (await sourceProperties.exists()) {
        final content = await sourceProperties.readAsString();
        final revision = content
            .split('\n')
            .firstWhere((line) => line.startsWith('Pkg.Revision'))
            .split('=')
            .last
            .trim();
        final version = Version.parse(revision);
        result.add(_Ndk(
          version: version,
          uri: dir.uri,
        ));
      }
    }
    return result;
  }

  bool needNewerVersion = false;

  @override
  Future<ValidationResult?> validate() async {
    // No package needs NDK
    if (minimumVersion == null ||
        !doctor.targetPlatforms.contains(OS.android)) {
      return null;
    }

    _sdkInfo = await AndroidSdkInfo.find(
      flutterRoot: doctor.flutterRoot?.toFilePath(),
      logger: doctor.verboseLogger,
    );

    if (_sdkInfo == null) {
      return ValidationResult(sections: [
        ValidationResultSection(
          ok: false,
          title: 'Android SDK not found',
          messages: [],
        ),
      ], proposedActions: []);
    }

    final ndks = await _findInstalledNdks();
    if (ndks.isEmpty) {
      return ValidationResult(
        sections: [
          ValidationResultSection(
            ok: false,
            title: 'NDK not found',
            messages: [],
          ),
        ],
        proposedActions: [
          ProposedAction(
            description: 'Install NDK',
          ),
        ],
      );
    } else {
      needNewerVersion = ndks.none((ndk) => ndk.version >= minimumVersion!);
      return ValidationResult(
        sections: [
          ValidationResultSection(
            ok: !needNewerVersion,
            title: needNewerVersion
                ? 'NDK installed, but too old'
                : 'NDK installed',
            messages: [
              ValidationResultSectionMessage(
                ok: !needNewerVersion,
                message:
                    'Installed versions: ${ndks.map((e) => e.version).join(', ')}',
              ),
              ValidationResultSectionMessage(
                ok: !needNewerVersion,
                message: 'Required minimum version: $minimumVersion',
              ),
            ],
          ),
        ],
        proposedActions: [
          if (needNewerVersion)
            ProposedAction(
              description: 'Install NDK $minimumVersion or newer',
            ),
        ],
      );
    }
  }

  static Version? findBestNdkKversion({
    required String sdkManagerOutput,
    required Version minimumVersion,
  }) {
    Version? bestVersion;
    final lines = sdkManagerOutput.split('\n');
    for (var line in lines) {
      if (line.trim().startsWith('ndk;')) {
        final columns = line.split('|');
        if (columns.length < 3) {
          continue;
        }
        // Pre-release versions have another string in the second column, i.e.
        // 27.0.11718014 rc1
        final isPrerelease = columns[1].trim().split(' ').length > 1;
        final version = columns[0].split(';').last.trim();
        final parsedVersion = Version.parse(version);
        if (parsedVersion >= minimumVersion &&
            (bestVersion == null || parsedVersion > bestVersion)) {
          // Use prerelease only if there is no stable version.
          if (isPrerelease && bestVersion != null) {
            continue;
          }
          if (minimumVersion < parsedVersion) {
            bestVersion = parsedVersion;
          }
        }
      }
    }

    return bestVersion;
  }

  @override
  Future<void> fix(ActionLogger logger) async {
    if (!needNewerVersion) {
      return;
    }
    final sdkManagerExtension = Platform.isWindows ? '.bat' : '';
    final sdkManager = path.join(
      _sdkInfo!.androidSdk,
      'cmdline-tools',
      'latest',
      'bin',
      'sdkmanager$sdkManagerExtension',
    );

    Version? latestVersion;

    await logger.logAction('Fetching NDK list...', () async {
      final list = await runCommand(
        sdkManager,
        ['--list'],
        logger: doctor.verboseLogger,
      );
      latestVersion = findBestNdkKversion(
        sdkManagerOutput: list,
        minimumVersion: minimumVersion!,
      );
      if (latestVersion == null) {
        throw Exception('Failed to find latest NDK version');
      }
    });
    if (latestVersion! < minimumVersion!) {
      doctor.writer.printMessage(
          'No NDK version available that meets the minimum requirement.');
      return;
    }
    await logger.logAction('Installing NDK $latestVersion', () async {
      await runCommand(
        sdkManager,
        ['--install', 'ndk;$latestVersion'],
        logger: doctor.verboseLogger,
      );
    });
  }
}
