import 'package:pub_semver/pub_semver.dart';
import 'package:rustup/src/command.dart';
import 'package:rustup/src/rustup.dart';
import 'package:test/test.dart';

import 'fake_process_manager.dart';

void main() {
  test('rustup with no toolchains', () async {
    final processManager = FakeProcessManager.list([
      FakeCommand(
        command: ['rustup', 'toolchain', 'list'],
        stdout: 'no installed toolchains\n',
      ),
      FakeCommand(
        command: [
          'rustup',
          'toolchain',
          'install',
          'stable',
          '--profile',
          'minimal'
        ],
      ),
      FakeCommand(
        command: ['rustup', 'toolchain', 'list'],
        stdout: 'stable-aarch64-apple-darwin\n',
      ),
      FakeCommand(
        command: [
          'rustup',
          'target',
          'list',
          '--toolchain',
          'stable-aarch64-apple-darwin',
          '--installed'
        ],
        stdout: 'x86_64-unknown-linux-gnu\nx86_64-apple-darwin\n',
      ),
    ]);
    await withProcessManager(processManager, () async {
      final rustup = Rustup(executablePath: 'rustup');

      expect(await rustup.installedToolchains(), []);
      await rustup.installToolchain('stable');

      expect((await rustup.installedToolchains()).length, 1);
      final toolchain = (await rustup.installedToolchains()).first;
      expect(toolchain.name, 'stable-aarch64-apple-darwin');

      final targets = await toolchain.installedTargets();
      expect(targets, [
        RustTarget.fromTriple('x86_64-unknown-linux-gnu')!,
        RustTarget.fromTriple('x86_64-apple-darwin')!,
      ]);
      expect(processManager, hasNoRemainingExpectations);
    });
  });

  test('rustup with esp toolchain', () async {
    final processManager = FakeProcessManager.list([
      FakeCommand(
        command: [
          'rustup',
          'toolchain',
          'list',
        ],
        stdout: 'stable-aarch64-apple-darwin (default)\n'
            'nightly-aarch64-apple-darwin\n'
            'esp\n',
      ),
    ]);
    await withProcessManager(processManager, () async {
      final rustup = Rustup(executablePath: 'rustup');
      final toolchains = await rustup.installedToolchains();
      expect(toolchains.length, 2);
      expect(toolchains[0].name, 'stable-aarch64-apple-darwin');
      expect(toolchains[1].name, 'nightly-aarch64-apple-darwin');
      expect(processManager, hasNoRemainingExpectations);
    });
  });

  test('toolchain version', () async {
    final processManager = FakeProcessManager.list([
      FakeCommand(
        command: ['rustup', 'toolchain', 'list'],
        stdout: 'stable-aarch64-apple-darwin (default)\n'
            'nightly-aarch64-apple-darwin\n',
      ),
      FakeCommand(
        command: [
          'rustup',
          'run',
          'stable-aarch64-apple-darwin',
          'rustc',
          '--version'
        ],
        stdout: 'rustc 1.75.0 (82e1608df 2023-12-21)',
      ),
      FakeCommand(
        command: [
          'rustup',
          'run',
          'nightly-aarch64-apple-darwin',
          'rustc',
          '--version'
        ],
        stdout: 'rustc 1.77.0-nightly (11f32b73e 2024-01-31)',
      ),
    ]);
    await withProcessManager(processManager, () async {
      final rustup = Rustup(executablePath: 'rustup');
      {
        final toolchain = (await rustup.getToolchain('stable'))!;
        final version = await toolchain.rustVersion();
        expect(version, Version(1, 75, 0));
      }
      {
        final toolchain = (await rustup.getToolchain('nightly'))!;
        final version = await toolchain.rustVersion();
        expect(version, Version(1, 77, 0, pre: 'nightly'));
      }
      expect(processManager, hasNoRemainingExpectations);
    });
  });
}
