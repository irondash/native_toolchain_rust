import 'dart:io';

import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

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

class RustManifestInfo {
  RustManifestInfo({required this.toolchainToVersion});

  final Map<String, Version> toolchainToVersion;

  static RustManifestInfo parse(YamlNode node) {
    if (node is! YamlMap) {
      throw SourceSpanException('Rust manifest info must be a map', node.span);
    }
    final toolchainToVersion = <String, Version>{};
    for (final entry in node.nodes.entries) {
      final toolchain = entry.key.value as String;
      final value = entry.value;
      if (value is! YamlMap) {
        throw SourceSpanException(
            'Rust toolchain version must be in a map', value.span);
      }
      final version = value.nodes['version'];
      if (version is! YamlScalar) {
        throw SourceSpanException('Rust version must be a string', value.span);
      }
      final parsedVersion = Version.parse(version.value as String);
      toolchainToVersion[toolchain] = parsedVersion;
    }

    return RustManifestInfo(toolchainToVersion: toolchainToVersion);
  }
}

class NativeManifest {
  NativeManifest({
    required this.version,
    required this.requirements,
  });

  final Version version;
  final Map<String, YamlNode> requirements;

  static NativeManifest parse(String content, {Uri? sourceUri}) {
    final doc = loadYamlNode(content, sourceUrl: sourceUri);
    if (doc is! YamlMap) {
      throw SourceSpanException('Manifest must be a map', doc.span);
    }
    final versionNode = doc.nodes['version'];
    if (versionNode is! YamlScalar) {
      throw SourceSpanException('Manifest version must be a string', doc.span);
    }
    final version = Version.parse(versionNode.value as String);
    final requirements = doc.nodes['requirements'];
    if (requirements is! YamlMap) {
      throw SourceSpanException(
          'Manifest requirements must be a map', doc.span);
    }
    return NativeManifest(
      version: version,
      requirements: requirements.nodes.cast(),
    );
  }

  static final String fileName = 'native_manifest.yaml';

  static NativeManifest? forPackage(Uri packageRoot, {Logger? verboseLogger}) {
    final manifestUri = packageRoot.resolve(fileName);
    final manifestFile = File.fromUri(manifestUri);
    if (!manifestFile.existsSync()) {
      return null;
    }
    final manifestContent = manifestFile.readAsStringSync();
    final manifest =
        NativeManifest.parse(manifestContent, sourceUri: manifestUri);
    verboseLogger?.info('Succesfully parsed manifest at $manifestUri');
    return manifest;
  }

  static List<NativeManifest> forPackageConfig(
    PackageConfig packageConfig, {
    Logger? verboseLogger,
  }) {
    final res = <NativeManifest>[];
    for (final package in packageConfig.packages) {
      final manifest = forPackage(package.root, verboseLogger: verboseLogger);
      if (manifest != null) {
        res.add(manifest);
      }
    }
    return res;
  }
}
