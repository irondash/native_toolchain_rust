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
      await installer.dispose();
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
    expect(tempDir.listSync(), isEmpty);
    tempDir.deleteSync();
  }, timeout: Timeout.none);
}
