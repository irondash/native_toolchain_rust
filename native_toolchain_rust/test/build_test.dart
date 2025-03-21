import 'dart:io';

import 'package:native_assets_cli/code_assets.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void copyPathSync(String from, String to) {
  Directory(to).createSync(recursive: true);
  for (final file in Directory(from).listSync(recursive: false)) {
    if (file.uri.pathSegments.contains('.dart_tool') ||
        file.uri.pathSegments.contains('build')) {
      continue;
    }

    final copyTo = p.join(to, p.relative(file.path, from: from));
    if (file is Directory) {
      copyPathSync(file.path, copyTo);
    } else if (file is File) {
      File(file.path).copySync(copyTo);
    } else if (file is Link) {
      Link(copyTo).createSync(file.targetSync(), recursive: true);
    }
  }
}

Future<void> withFlutterExampleProject(
  Future<void> Function(Uri) testFn,
) async {
  final tempDir = Directory.systemTemp.createTempSync('buildTest');
  try {
    final workspaceRoot = Directory.current.uri.resolve('../');

    final exampleRoot = workspaceRoot.resolve('example/flutter_package');

    copyPathSync(exampleRoot.toFilePath(), tempDir.path);

    final pubspecOverrides = """
dependency_overrides:
  flutter_package:
    path: ../
  native_toolchain_rust:
    path: ${workspaceRoot.resolve('native_toolchain_rust').toFilePath()}
  native_toolchain_rust_common:
    path: ${workspaceRoot.resolve('native_toolchain_rust_common').toFilePath()}
  rustup:
    path: ${workspaceRoot.resolve('rustup').toFilePath()}
    """;

    File(tempDir.uri.resolve('example/pubspec_overrides.yaml').toFilePath())
        .writeAsStringSync(pubspecOverrides);

    final exampleUri = tempDir.uri.resolve('example/');

    await runCommand(
      'flutter',
      ['clean'],
      workingDirectory: exampleUri.toFilePath(),
    );

    await runCommand(
      'flutter',
      ['pub', 'get'],
      workingDirectory: exampleUri.toFilePath(),
    );

    await testFn(exampleUri);
  } finally {
    int attempt = 0;
    while (true) {
      try {
        await tempDir.delete(recursive: true);
        break;
      } catch (e) {
        if (attempt > 5) {
          // Thanks windows.
          print('Build temp dir clean failed. Giving up.');
          break;
        }
        attempt++;
        // Windows being windows.
        print('Failed to clean builder temp dir: $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
}

void main() async {
  test(
    'macOS project',
    () async {
      await withFlutterExampleProject((uri) async {
        for (final config in ['Debug', 'Profile', 'Release']) {
          await runCommand(
            'flutter',
            ['build', 'macos', '--${config.toLowerCase()}'],
            workingDirectory: uri.toFilePath(),
          );

          // Check if the library is built
          final library = File.fromUri(uri.resolve(
              'build/macos/Build/Products/$config/example.app/Contents/Frameworks/flutter_ffi_plugin.framework/Versions/A/flutter_ffi_plugin'));
          expect(library.existsSync(), isTrue);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !Platform.isMacOS,
  );
  test(
    'iOS project',
    () async {
      await withFlutterExampleProject((uri) async {
        for (final config in ['Debug', 'Profile', 'Release']) {
          await runCommand(
            'flutter',
            ['build', 'ios', '--${config.toLowerCase()}', '--no-codesign'],
            workingDirectory: uri.toFilePath(),
          );

          // Check if the library is built
          final library = File.fromUri(uri.resolve(
            'build/ios/$config-iphoneos/Runner.app/Frameworks/flutter_ffi_plugin.framework/flutter_ffi_plugin',
          ));
          expect(library.existsSync(), isTrue);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !Platform.isMacOS,
  );
  test(
    'windows project',
    () async {
      await withFlutterExampleProject((uri) async {
        for (final config in ['Debug', 'Profile', 'Release']) {
          await runCommand(
            'flutter',
            ['build', 'windows', '--${config.toLowerCase()}'],
            workingDirectory: uri.toFilePath(),
          );

          // Check if the library is built
          final library = File.fromUri(uri.resolve(
            'build/windows/${Architecture.current}/runner/$config/flutter_ffi_plugin.dll',
          ));
          expect(library.existsSync(), isTrue);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !Platform.isWindows,
  );
  test(
    'linux project',
    () async {
      await withFlutterExampleProject((uri) async {
        for (final config in ['debug', 'profile', 'release']) {
          await runCommand(
            'flutter',
            ['build', 'linux', '--$config'],
            workingDirectory: uri.toFilePath(),
          );

          // Check if the library is built
          final library = File.fromUri(uri.resolve(
            'build/linux/${Architecture.current}/$config/bundle/lib/libflutter_ffi_plugin.so',
          ));
          expect(library.existsSync(), isTrue);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
    skip: !Platform.isLinux,
  );
  test(
    'android project',
    () async {
      await withFlutterExampleProject((uri) async {
        for (final config in ['debug', 'profile', 'release']) {
          await runCommand(
            'flutter',
            ['build', 'apk', '--$config'],
            workingDirectory: uri.toFilePath(),
          );

          // Check if the library is built
          final library = File.fromUri(uri.resolve(
            'build/app/intermediates/merged_jni_libs/$config/out/arm64-v8a/libflutter_ffi_plugin.so',
          ));
          expect(library.existsSync(), isTrue);
        }
      });
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
