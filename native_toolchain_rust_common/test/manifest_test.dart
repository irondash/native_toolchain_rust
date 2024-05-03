import 'package:native_toolchain_rust_common/src/manifest.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

final _manifest = """
version: 0.1.0
requirements:
  ndk:
    version: 1.2.1
  rust:
    stable:
      version: 1.1.0
    nightly:
      version: 1.0.0
""";

void main() {
  test('Manifest can be parsed', () {
    final manifest = NativeManifest.parse(_manifest);
    expect(manifest.version, Version.parse('0.1.0'));

    final ndkVersion = manifest.requirements['ndk'];
    expect(ndkVersion, isNotNull);
    final ndkManifestInfo = NdkManifestInfo.parse(ndkVersion!);
    expect(ndkManifestInfo.version, Version.parse('1.2.1'));

    final rustVersion = manifest.requirements['rust'];
    expect(rustVersion, isNotNull);

    final rustManifestInfo = RustManifestInfo.parse(rustVersion!);
    expect(rustManifestInfo.toolchainToVersion, {
      'stable': Version.parse('1.1.0'),
      'nightly': Version.parse('1.0.0'),
    });
  });
}
