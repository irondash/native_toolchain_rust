import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:process/process.dart';

const String _kSeparator = "--";

ProcessManager _processManager = LocalProcessManager();

Future<T> withProcessManager<T>(
  ProcessManager processManager,
  Future<T> Function() run,
) async {
  final previous = _processManager;
  _processManager = processManager;
  try {
    return await run();
  } finally {
    _processManager = previous;
  }
}

class CommandFailedException implements Exception {
  final String executable;
  final List<String> arguments;
  final ProcessResult result;

  CommandFailedException({
    required this.executable,
    required this.arguments,
    required this.result,
  });

  @override
  String toString() {
    final stdout = result.stdout.toString().trim();
    final stderr = result.stderr.toString().trim();
    return [
      "External Command: $executable ${arguments.map((e) => '"$e"').join(' ')}",
      "Returned Exit Code: ${result.exitCode}",
      _kSeparator,
      "STDOUT:",
      if (stdout.isNotEmpty) stdout,
      _kSeparator,
      "STDERR:",
      if (stderr.isNotEmpty) stderr,
    ].join('\n');
  }
}

Future<ProcessResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
  Logger? logger,
}) async {
  logger?.info('Running command $executable ${arguments.join(' ')}');

  final res = await _processManager.run(
    [
      executable,
      ...arguments,
    ],
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    stderrEncoding: stderrEncoding,
    stdoutEncoding: stdoutEncoding,
  );
  if (res.exitCode != 0) {
    throw CommandFailedException(
      executable: executable,
      arguments: arguments,
      result: res,
    );
  } else {
    return res;
  }
}
