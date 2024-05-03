import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:path/path.dart' as path;

class AndroidSdkInfo {
  AndroidSdkInfo({
    required this.androidSdk,
    required this.javaHome,
  });

  final String androidSdk;
  final String javaHome;

  static Future<AndroidSdkInfo?> find({
    String? flutterRoot,
    Logger? logger,
  }) async {
    final flutterCommand = flutterRoot != null
        ? path.join(flutterRoot, 'bin', 'flutter')
        : 'flutter';
    final result = await runCommand(
      flutterCommand,
      [
        'config',
        '--machine',
      ],
      logger: logger,
    );
    final json = result.stdout as String;
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final javaHome = decoded['jdk-dir'] as String?;
    final sdk = decoded['android-sdk'] as String?;
    if (javaHome == null || sdk == null) {
      return null;
    }
    return AndroidSdkInfo(
      androidSdk: sdk,
      javaHome: javaHome,
    );
  }
}
