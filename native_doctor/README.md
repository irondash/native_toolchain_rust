# Native Doctor

`native_doctor` is a tool analyzes Flutter and Dart project dependencies, find requirements for native toolchains and, if possible, resolves issues.

Currently supported native toolchains:
- NDK
- Rust (through rustup)

## Usage

In your project directory, run:
```bash
pub global activate native_doctor
pub global run native_doctor
```

## Features

`native_doctor` can

- Check for installed NDKs and install NDK if missing or outdated.
- Checks whether Rust is installed and install Rust (through Rustup) if missing.
- Check for installed Rust toolchains and targets and install missing toolchains and targets.

## Supporting `native_doctor` in Flutter or Dart packages

If your package depends on NDK or Rust being present during compilation, add a
`native_manifest.yaml` file to the root of the package. This file contains minimal required versions of NDK and/or Rust toolchains.

Example `native_manifest.yaml` file:

```yaml
version: 0.1.0
requirements:
  ndk:
    version: 26.0.0
  rust:
    stable:
      version: 1.77.2
```

Example `native_manifest.yaml` file if project only requires NDK:

```yaml
version: 0.1.0
requirements:
  ndk:
    version: 26.0.0
```

Example `native_manifest.yaml` file if project only requires both stable and nightly Rust and NDK:

```yaml
version: 0.1.0
requirements:
  ndk:
    version: 26.0.0
  rust:
    stable:
      version: 1.77.2
    nightly:
      version: 1.79.0-nightly
```

Example output of running `native_doctor` in a project with native dependencies:
```
Project: native_toolchain_rust_test (Flutter)
Buildable platforms: macos, ios, android

Native toolchain: NDK

  [✗] NDK installed, but too old
       ! Installed versions: 25.1.8937393, 23.1.7779620
       ! Required minimum version: 26.0.0

Native toolchain: Rust

  [✓] Rustup installed
  [✗] Toolchain stable-aarch64-apple-darwin (version 1.77.2)
       • Required minimum version: 1.77.2
       • Installed targets: aarch64-apple-darwin, aarch64-apple-ios,
         aarch64-apple-ios-sim, aarch64-linux-android, arm-linux-androideabi,
         x86_64-linux-android
       ! Missing targets: i686-linux-android, x86_64-apple-ios, x86_64-apple-darwin

Proposed actions:

  • (NDK)  Install NDK 26.0.0 or newer
  • (Rust) Install targets i686-linux-android, x86_64-apple-ios, x86_64-apple-darwin
           for toolchain stable-aarch64-apple-darwin

Do you want native doctor to perform proposed actions? (y/N)
```
