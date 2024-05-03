import 'dart:io';

import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rust_common/native_toolchain_rust_common.dart';
import 'package:path/path.dart' as path;

abstract class RustupInstaller {
  static Future<RustupInstaller> create({Logger? logger}) {
    if (Platform.isWindows) {
      return _WindowsRustupInstaller.prepare(logger: logger);
    } else {
      return _UnixRustupInstaller.prepare(logger: logger);
    }
  }

  Future<void> install({
    bool modifyPath = true,
    String? cargoHome,
    String? rustupHome,
  }) async {
    final process = await runCommand(
      _scriptPath(),
      [
        '--default-toolchain',
        'none',
        '-y',
        if (!modifyPath) '--no-modify-path',
      ],
      environment: {
        if (cargoHome != null) 'CARGO_HOME': cargoHome,
        if (rustupHome != null) 'RUSTUP_HOME': rustupHome,
      },
      logger: _logger,
    );
    final exitCode = process.exitCode;
    if (exitCode != 0) {
      throw Exception('Failed to install rustup');
    }
  }

  Future<void> dispose();

  RustupInstaller._({
    Logger? logger,
  }) : _logger = logger;

  String _scriptPath();
  final Logger? _logger;
}

class _WindowsRustupInstaller extends RustupInstaller {
  _WindowsRustupInstaller({
    required this.tempDirectory,
    required this.scriptFile,
    required super.logger,
  }) : super._();

  static Future<_WindowsRustupInstaller> prepare({Logger? logger}) async {
    final script = await get(Uri.parse('https://win.rustup.rs/x86_64'));
    final tempDir = Directory.systemTemp.createTempSync('rustup');
    // Save script to temp dir
    final scriptPath = path.join(tempDir.path, 'rustup-init.exe');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsBytes(script.bodyBytes);
    return _WindowsRustupInstaller(
      tempDirectory: tempDir,
      scriptFile: scriptFile,
      logger: logger,
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
    required super.logger,
  }) : super._();

  static Future<_UnixRustupInstaller> prepare({Logger? logger}) async {
    final script = await get(Uri.parse('https://sh.rustup.rs'));
    final tempDir = Directory.systemTemp.createTempSync('rustup');
    // Save script to temp dir
    final scriptPath = path.join(tempDir.path, 'rustup.sh');
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsBytes(script.bodyBytes);
    // Make script executable
    await runCommand(
      'chmod',
      ['+x', scriptPath],
      logger: logger,
    );
    return _UnixRustupInstaller(
      tempDirectory: tempDir,
      scriptFile: scriptFile,
      logger: logger,
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
