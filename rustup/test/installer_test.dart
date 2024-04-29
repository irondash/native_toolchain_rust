import 'dart:io';

import 'package:rustup/rustup.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('installer works', () async {
    final tempDir = Directory.systemTemp.createTempSync('rustup');
    tempDir.createSync(recursive: true);
    final installer = await RustupInstaller.create();
    final cargoHome = path.join(tempDir.path, 'cargo');
    final rustupHome = path.join(tempDir.path, 'rustup');
    try {
      await installer.install(
        modifyPath: false,
        cargoHome: cargoHome,
        rustupHome: rustupHome,
      );
    } finally {
      int attempt = 0;
      while (true) {
        try {
          await installer.dispose();
          break;
        } catch (e) {
          if (attempt > 5) {
            rethrow;
          }
          attempt++;
          // Windows being windows.
          print('Failed to clean installer temp dir: $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    expect(tempDir.listSync(), isNotEmpty);
    final rustup = Rustup(
      executablePath: path.join(
        tempDir.path,
        'cargo',
        'bin',
        Platform.isWindows ? 'rustup.exe' : 'rustup',
      ),
      cargoHome: cargoHome,
      rustupHome: rustupHome,
    );
    print('Install path $tempDir');
    var toolchains = await rustup.installedToolchains();
    expect(toolchains, isEmpty);
    await rustup.installToolchain('stable');
    toolchains = await rustup.installedToolchains();
    expect(toolchains, isNotEmpty);
    expect(toolchains.first.name.startsWith('stable-'), isTrue);
    await rustup.uninstall();
    if (!Platform.isWindows) {
      // Rustup on windows doesn't seem to uninstall completely.
      expect(tempDir.listSync(), isEmpty);
    }
    int attempt = 0;
    while (true) {
      try {
        tempDir.deleteSync(recursive: true);
        break;
      } catch (e) {
        if (attempt > 5) {
          rethrow;
        }
        attempt++;
        // Windows being windows again.
        print('Failed to clean temp dir: $e');
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }, timeout: Timeout.none);
}
