import 'dart:io';

import 'package:toml/toml.dart';

class ManifestException {
  ManifestException(this.message, {required this.fileName});

  final String? fileName;
  final String message;

  @override
  String toString() {
    if (fileName != null) {
      return 'Failed to parse package manifest at $fileName: $message';
    } else {
      return 'Failed to parse package manifest: $message';
    }
  }
}

class CrateManifestInfo {
  CrateManifestInfo({required this.packageName, required this.libraryName});

  final String packageName;
  final String libraryName;

  static CrateManifestInfo parseManifest(String manifest,
      {final String? fileName}) {
    final toml = TomlDocument.parse(manifest);
    final package = toml.toMap()['package'];
    if (package == null) {
      throw ManifestException('Missing package section', fileName: fileName);
    }
    final name = package['name'];
    if (name == null) {
      throw ManifestException('Missing package name', fileName: fileName);
    }

    final lib = toml.toMap()['lib'];
    if (lib == null) {
      throw ManifestException('Missing library section', fileName: fileName);
    }

    final libName = (lib['name'] ?? name).replaceAll("-", "_");

    return CrateManifestInfo(packageName: name, libraryName: libName);
  }

  static CrateManifestInfo load(Uri manifestPath) {
    final manifestFile = File.fromUri(manifestPath);
    final manifest = manifestFile.readAsStringSync();
    return parseManifest(manifest, fileName: manifestFile.path);
  }
}
