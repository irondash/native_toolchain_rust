import 'dart:io';

import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildConfig buildConfig, BuildOutput output) async {
      final builder = RustBuilder(
        // The ID of native assets consists of package name and crate name.
        package: 'flutter_package',
        crateManifestPath: 'rust/Cargo.toml',
        buildConfig: buildConfig,
      );
      await builder.run(output: output);
    });
  } catch (e) {
    if (Platform.isWindows || Platform.isLinux) {
      // CMake build seems to swallow error written to stdout.
      stderr.writeln(e);
    } else {
      // While Xcode build prints the error twice unless when written to stderr.
      stdout.writeln(e.toString());
    }
    exit(1);
  }
}
