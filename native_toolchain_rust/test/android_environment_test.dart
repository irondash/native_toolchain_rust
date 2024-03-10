import 'dart:io';

import 'package:native_toolchain_rust/src/android_environment.dart';
import 'package:path/path.dart' as path;
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('NdkInfo', () {
    final tempDir = Directory.systemTemp.createTempSync('ndk_info_test');
    final sourceProperties = path.join(tempDir.path, 'source.properties');
    File(sourceProperties)
        .writeAsStringSync('Pkg.Desc=Android NDK\nPkg.Revision=25.1.8937393\n');
    final binDir = path.join(tempDir.path, 'prebuilt', 'darwin-x86_64', 'bin');
    Directory(binDir).createSync(recursive: true);
    final cCompiler = path.join(binDir, 'clang');
    final info = NdkInfo.forCCompiler(cCompiler);
    expect(info, isNotNull);
    expect(info!.toolchainPath, binDir);
    expect(info.ndkVersion, Version(25, 1, 8937393));
    tempDir.deleteSync(recursive: true);
  });
}
