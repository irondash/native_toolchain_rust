import 'dart:io';

import 'package:collection/collection.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_doctor/src/android_sdk.dart';
import 'package:native_doctor/src/command.dart';
import 'package:native_doctor/src/native_doctor.dart';
import 'package:native_doctor/src/toolchain_checker.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
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

class NdkManifestInfo {
  NdkManifestInfo({
    required this.version,
  });

  final Version version;

  static NdkManifestInfo parse(YamlNode node) {
    if (node is! YamlMap) {
      throw SourceSpanException('NDK manifest info must be a map', node.span);
    }

    final version = node.nodes['version'];
    if (version is! YamlScalar) {
      throw SourceSpanException('NDK version must be a string', node.span);
    }
    return NdkManifestInfo(
      version: Version.parse(version.value as String),
    );
  }
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
      final ndkVersions = list.stdout
          .toString()
          .split('\n')
          .where((line) => line.trim().startsWith('ndk;'))
          .map((line) => line.trim().split(';')[1])
          .map((line) => line.split(' ')[0].trim())
          .map(Version.parse);
      latestVersion = maxBy(ndkVersions, (v) => v);
      if (latestVersion == null) {
        throw Exception('Failed to find latest NDK version');
      }
    });
    if (latestVersion! < minimumVersion!) {
      doctor.writer.printMessage(
          'NO NDK version available that meets the minimum requirement.');
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
