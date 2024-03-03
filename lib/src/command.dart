import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'logging.dart';

final log = Logger("process");

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
      kSeparator,
      "STDOUT:",
      if (stdout.isNotEmpty) stdout,
      kSeparator,
      "STDERR:",
      if (stderr.isNotEmpty) stderr,
    ].join('\n');
  }
}

class TestRunCommandArgs {
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Map<String, String>? environment;
  final bool includeParentEnvironment;
  final bool runInShell;
  final Encoding? stdoutEncoding;
  final Encoding? stderrEncoding;

  TestRunCommandArgs({
    required this.executable,
    required this.arguments,
    this.workingDirectory,
    this.environment,
    this.includeParentEnvironment = true,
    this.runInShell = false,
    this.stdoutEncoding,
    this.stderrEncoding,
  });
}

class TestRunCommandResult {
  TestRunCommandResult({
    this.pid = 1,
    this.exitCode = 0,
    this.stdout = '',
    this.stderr = '',
  });

  final int pid;
  final int exitCode;
  final String stdout;
  final String stderr;
}

TestRunCommandResult Function(TestRunCommandArgs args)? testRunCommandOverride;

ProcessResult runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  Encoding? stdoutEncoding = systemEncoding,
  Encoding? stderrEncoding = systemEncoding,
}) {
  if (testRunCommandOverride != null) {
    final result = testRunCommandOverride!(TestRunCommandArgs(
      executable: executable,
      arguments: arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    ));
    return ProcessResult(
      result.pid,
      result.exitCode,
      result.stdout,
      result.stderr,
    );
  }
  log.finer('Running command $executable ${arguments.join(' ')}');
  final res = Process.runSync(
    executable,
    arguments,
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
