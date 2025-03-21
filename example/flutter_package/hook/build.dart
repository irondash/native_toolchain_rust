import 'dart:io';

import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildInput input, BuildOutputBuilder output) async {
      final builder = RustBuilder(
        // The ID of native assets consists of package name and crate name.
        package: 'flutter_package',
        cratePath: 'rust',
        buildInput: input,
        extraCargoArgs: ['--features=sum'],
      );
      await builder.run(output: output);
    });
  } catch (e) {
    // FIXME(knopp): Figure out where to log the error
    // https://github.com/flutter/flutter/issues/147544
    stdout.writeln(e);
    exit(1);
  }
}
