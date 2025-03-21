Library to interact with `rustup` and `cargo` when building Dart and Flutter native assets written in Rust.

Native assets is currently an experimental feature that is only available in Flutter main branch and needs to be enabled through `flutter config`:
```
flutter config --enable-native-assets
```

## Usage

To build Rust code alongside Flutter or Dart package following steps are required:

1. Add `native_toolchain_rust` and `native_assets_cli` as a dependency to your project.
```
dart pub add native_toolchain_rust
dart pub add native_assets_cli
```

2. Create a build script at `hook/build.dart`:

```dart
import 'dart:io';

import 'package:native_toolchain_rust/native_toolchain_rust.dart';
import 'package:native_assets_cli/native_assets_cli.dart';

void main(List<String> args) async {
  try {
    await build(args, (BuildInput input, BuildOutputBuilder output) async {
      final builder = RustBuilder(
        // The ID of native assets consists of package name and crate name.
        package: '<your package name>',
        cratePath: 'rust',
        buildInput: input,
      );
      await builder.run(output: output);
    });
  } catch (e) {
    // ignore: avoid_print
    print(e);
    exit(1);
  }
}
```

This assumes that your Rust code is located in `rust` directory in package root. Crate must be a `cdylib`.

3. Add `native_manifest.yaml` file to your package root. This step is not strictly necessary, but it will let [`native_doctor`](https://pub.dev/packages/native_doctor) know what the toolchain requirements for your packages are.

```yaml
version: 0.1.0
requirements:
  ndk:
    version: 25.1.8937393
  rust:
    stable:
      version: 1.77.2
```

To reference native asset library in your code, you can use the `@ffi.DefaultAsset` annotation:

```dart
@ffi.DefaultAsset('package:<flutter_package_name>/<rust_crate_name>')
library rust;

import 'dart:ffi' as ffi;

@ffi.Native<ffi.IntPtr Function(ffi.IntPtr, ffi.IntPtr)>()
external int sum(
  int a,
  int b,
);
```

For complete examples see the [example](../example) directory.

## Using packages with Rust native assets

Package that has Rust code in it depends on Rust toolchain to be installed on machine of developer that uses the package. To make this as frictionless as possible, `native_toolchain_rust` detects if Rust toolchain is installed and up-do-date, and if not suggests running [`native_doctor`](https://pub.dev/packages/native_doctor) tool to automatically install and configure necessary toolchains.

For example, when user tries to build your package without having Rust installed, they get the following error message:
```
Rustup not found.
Please run native_doctor in your project to fix the issue:

dart pub global activate native_doctor
dart pub global run native_doctor
```

And here's output of `native_doctor` run on a computer with no Rust installation and outdated NDK:

```
Project: example (Flutter)
Buildable platforms: macos, ios, android

Native toolchain: NDK

  [✗] NDK installed, but too old
       ! Installed versions: 23.1.7779620
       ! Required minimum version: 25.1.8937393

Native toolchain: Rust

  [✗] Rustup not found
  [✗] Toolchain stable not installed
       ! Required minimum version: 1.77.2
       ! Missing targets: arm-linux-androideabi, aarch64-linux-android, i686-linux-android,
         x86_64-linux-android, aarch64-apple-ios, x86_64-apple-ios, aarch64-apple-ios-sim, aarch64-apple-darwin,
         x86_64-apple-darwin

Proposed actions:

  • (NDK)  Install NDK 25.1.8937393 or newer
  • (Rust) Install rustup
  • (Rust) Install toolchain stable
  • (Rust) Install targets arm-linux-androideabi, aarch64-linux-android, i686-linux-android,
           x86_64-linux-android, aarch64-apple-ios, x86_64-apple-ios, aarch64-apple-ios-sim, aarch64-apple-darwin,
           x86_64-apple-darwin for toolchain stable

Do you want native doctor to perform proposed actions? (y/N)
```

After confirming, `native_doctor` will automatically install correct NDK version, required Rust toolchain and targets:

```
 • Fetching NDK list... [done]
 • Installing NDK 26.3.11579264 [done]
 • Installing rustup [done]
 • Installing Rust toolchain stable [done]
 • Installing target arm-linux-androideabi for toolchain stable [done]
 • Installing target aarch64-linux-android for toolchain stable [done]
 • Installing target i686-linux-android for toolchain stable [done]
 • Installing target x86_64-linux-android for toolchain stable [done]
 • Installing target aarch64-apple-ios for toolchain stable [done]
 • Installing target x86_64-apple-ios for toolchain stable [done]
 • Installing target aarch64-apple-ios-sim for toolchain stable [done]
 • Installing target aarch64-apple-darwin for toolchain stable [done]
 • Installing target x86_64-apple-darwin for toolchain stable [done]
```
