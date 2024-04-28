import 'dart:io';

import 'package:logging/logging.dart';
import 'package:package_config/package_config.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

class Manifest {
  Manifest({
    required this.version,
    required this.requirements,
  });

  final Version version;
  final Map<String, YamlNode> requirements;

  static Manifest parse(String content, {Uri? sourceUri}) {
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
    return Manifest(
      version: version,
      requirements: requirements.nodes.cast(),
    );
  }

  static final String fileName = 'native_manifest.yaml';

  static List<Manifest> forPackageConfig(
    PackageConfig packageConfig, {
    Logger? verboseLogger,
  }) {
    final res = <Manifest>[];
    for (final package in packageConfig.packages) {
      final manifestUri = package.root.resolve(fileName);
      final manifestFile = File.fromUri(manifestUri);
      if (!manifestFile.existsSync()) {
        continue;
      }
      final manifestContent = manifestFile.readAsStringSync();
      final manifest = Manifest.parse(manifestContent, sourceUri: manifestUri);
      verboseLogger?.info('Succesfully parsed manifest at $manifestUri');
      res.add(manifest);
    }
    return res;
  }
}
