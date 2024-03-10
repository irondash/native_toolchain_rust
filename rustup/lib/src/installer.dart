import 'dart:io';

import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:process/process.dart';

abstract class RustupInstaller {
  static Future<RustupInstaller> create({ProcessManager? processManager}) {
    final manager = processManager ?? LocalProcessManager();
    if (Platform.isWindows) {
      return _WindowsRustupInstaller.prepare(manager);
    } else {
      return _UnixRustupInstaller.prepare(manager);
    }
  }

  Future<void> install({
    bool modifyPath = true,
    String? cargoHome,
    String? rustupHome,
  }) async {
    final process = await _processManager.start(
      [
        _scriptPath(),
        '--default-toolchain',
        'none',
        '-y',
        if (!modifyPath) '--no-modify-path',
      ],
      environment: {
        if (cargoHome != null) 'CARGO_HOME': cargoHome,
        if (rustupHome != null) 'RUSTUP_HOME': rustupHome,
      },
    );
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception('Failed to install rustup');
    }
  }

  Future<void> dispose();

  RustupInstaller._({
    required ProcessManager processManager,
  }) : _processManager = processManager;

  String _scriptPath();
  final ProcessManager _processManager;
}

class _WindowsRustupInstaller extends RustupInstaller {
  _WindowsRustupInstaller({
    required this.tempDirectory,
    required this.scriptFile,
    required ProcessManager processManager,
  }) : super._(processManager: processManager);

  static Future<_WindowsRustupInstaller> prepare(
      ProcessManager processManager) async {
    final script = await get(Uri.parse('https://win.rustup.rs/x86_64'));
    final tempDir = Directory.systemTemp.createTempSync('rustup');
    // Save script to temp dir
    final scriptPath = path.join(tempDir.path, 'rustup-init.exe');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsBytes(script.bodyBytes);
    return _WindowsRustupInstaller(
      tempDirectory: tempDir,
      scriptFile: scriptFile,
      processManager: processManager,
    );
  }

  @override
  Future<void> dispose() async {
    tempDirectory.deleteSync(recursive: true);
  }

  @override
  String _scriptPath() {
    return scriptFile.path;
  }

  final Directory tempDirectory;
  final File scriptFile;
}

class _UnixRustupInstaller extends RustupInstaller {
  _UnixRustupInstaller({
    required this.tempDirectory,
    required this.scriptFile,
    required ProcessManager processManager,
  }) : super._(processManager: processManager);

  static Future<_UnixRustupInstaller> prepare(
      ProcessManager processManager) async {
    final script = await get(Uri.parse('https://sh.rustup.rs'));
    final tempDir = Directory.systemTemp.createTempSync('rustup');
    // Save script to temp dir
    final scriptPath = path.join(tempDir.path, 'rustup.sh');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsBytes(script.bodyBytes);
    // Make script executable
    await processManager.run(['chmod', '+x', scriptPath]);
    return _UnixRustupInstaller(
      tempDirectory: tempDir,
      scriptFile: scriptFile,
      processManager: processManager,
    );
  }

  @override
  Future<void> dispose() async {
    tempDirectory.deleteSync(recursive: true);
  }

  @override
  String _scriptPath() {
    return scriptFile.path;
  }

  final Directory tempDirectory;
  final File scriptFile;
}
