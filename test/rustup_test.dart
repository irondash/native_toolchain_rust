import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_rust/src/rustup.dart';
import 'package:native_toolchain_rust/src/command.dart';
import 'package:test/test.dart';

void main() {
  test('rustup with no toolchains', () {
    bool didListToolchains = false;
    bool didInstallStable = false;
    bool didListTargets = false;
    testRunCommandOverride = (args) {
      expect(args.executable, 'rustup');
      switch (args.arguments) {
        case ['toolchain', 'list']:
          didListToolchains = true;
          if (!didInstallStable)
            return TestRunCommandResult(stdout: 'no installed toolchains\n');
          else
            return TestRunCommandResult(
                stdout: 'stable-aarch64-apple-darwin\n');
        case ['toolchain', 'install', 'stable', '--profile', 'minimal']:
          didInstallStable = true;
          return TestRunCommandResult();
        case [
            'target',
            'list',
            '--toolchain',
            'stable-aarch64-apple-darwin',
            '--installed'
          ]:
          didListTargets = true;
          return TestRunCommandResult(
              stdout: 'x86_64-unknown-linux-gnu\nx86_64-apple-darwin\n');
        default:
          throw Exception('Unexpected call: ${args.arguments}');
      }
    };
    final rustup = Rustup(executablePath: 'rustup');

    expect(didListToolchains, isFalse);
    expect(rustup.installedToolchains(), []);
    expect(didListToolchains, isTrue);
    rustup.installToolchain('stable');
    expect(didInstallStable, true);

    expect(rustup.installedToolchains().length, 1);
    final toolchain = rustup.installedToolchains().first;
    expect(toolchain.name, 'stable-aarch64-apple-darwin');

    expect(didListTargets, isFalse);
    final targets = toolchain.installedTargets();
    expect(didListTargets, isTrue);
    expect(targets, [
      Target.linuxX64.toRust,
      Target.macOSX64.toRust,
    ]);
    testRunCommandOverride = null;
  });

  test('rustup with esp toolchain', () {
    testRunCommandOverride = (args) {
      expect(args.executable, 'rustup');
      switch (args.arguments) {
        case ['toolchain', 'list']:
          return TestRunCommandResult(
              stdout: 'stable-aarch64-apple-darwin (default)\n'
                  'nightly-aarch64-apple-darwin\n'
                  'esp\n');
        default:
          throw Exception('Unexpected call: ${args.arguments}');
      }
    };
    final rustup = Rustup(executablePath: 'rustup');
    final toolchains = rustup.installedToolchains();
    expect(toolchains.length, 2);
    expect(toolchains[0].name, 'stable-aarch64-apple-darwin');
    expect(toolchains[1].name, 'nightly-aarch64-apple-darwin');
  });
}
