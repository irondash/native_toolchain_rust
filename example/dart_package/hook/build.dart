import 'dart:io';

import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildInput input, BuildOutputBuilder output) async {
      final builder = RustBuilder(
        package: 'dart_package',
        cratePath: 'rust',
        buildInput: input,
      );
      await builder.run(output: output);
    });
  } catch (e) {
    print(e);
    exit(1);
  }
}
