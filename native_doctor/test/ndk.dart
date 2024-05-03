import 'dart:io';

import 'package:native_doctor/src/checkers/ndk.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  test('Load a file', () async {
    final file = File('test/sdkmanager.txt').readAsStringSync();
    final stableVersion = NdkToolchainChecker.findBestNdkKversion(
      sdkManagerOutput: file,
      minimumVersion: Version(21, 0, 6113669),
    );
    expect(stableVersion, Version(26, 3, 11579264));

    final prereleaseVersion = NdkToolchainChecker.findBestNdkKversion(
      sdkManagerOutput: file,
      minimumVersion: Version(26, 4, 0),
    );
    expect(prereleaseVersion, Version(27, 0, 11718014));

    final noVersion = NdkToolchainChecker.findBestNdkKversion(
      sdkManagerOutput: file,
      minimumVersion: Version(28, 0, 0),
    );
    expect(noVersion, isNull);
  });
}
