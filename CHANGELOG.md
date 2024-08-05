# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2024-08-05

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`native_toolchain_rust` - `v0.1.0-dev.5`](#native_toolchain_rust---v010-dev5)

---

#### `native_toolchain_rust` - `v0.1.0-dev.5`

 - **FIX**: build on iOS failing for crates with build script (#18).


## 2024-07-05

### Changes

---

Packages with breaking changes:

 - [`native_toolchain_rust` - `v0.1.0-dev.4`](#native_toolchain_rust---v010-dev4)

Packages with other changes:

 - There are no other changes in this release.

---

#### `native_toolchain_rust` - `v0.1.0-dev.4`

 - **FIX**: use OS.executableFileName rather than hardcoding the extension (#5).
 - **FIX**: wording.
 - **FIX**: tweak message.
 - **FIX**: android build fixes.
 - **FEAT**: allow overriding asset name (#13).
 - **FEAT**: add build tests (#3).
 - **FEAT**: write error message to stderr.
 - **DOCS**: wording.
 - **DOCS**: singular.
 - **DOCS**: update example link.
 - **BREAKING** **FEAT**: update native_assets_cli version.
 - **BREAKING** **FEAT**: rename ignoreMissingNativeManifest to useNativeManifest (#6).


## 2024-07-04

### Changes

---

Packages with breaking changes:

 - [`native_doctor` - `v0.1.0-dev.4`](#native_doctor---v010-dev4)
 - [`rustup` - `v0.1.0-dev.3`](#rustup---v010-dev3)

Packages with other changes:

 - [`native_toolchain_rust_common` - `v0.1.0-dev.3`](#native_toolchain_rust_common---v010-dev3)

---

#### `native_doctor` - `v0.1.0-dev.4`

 - **REFACTOR**: runCommand should just return stdout instead of Process (#9).
 - **REFACTOR**: make try/catch blocks shorter (#7).
 - **FIX**: reduce line width.
 - **FIX**: android build fixes.
 - **BREAKING** **FEAT**: update native_assets_cli version.

#### `rustup` - `v0.1.0-dev.3`

 - **REFACTOR**: runCommand should just return stdout instead of Process (#9).
 - **FIX**: wording.
 - **BREAKING** **FEAT**: update native_assets_cli version.

#### `native_toolchain_rust_common` - `v0.1.0-dev.3`

 - **REFACTOR**: runCommand should just return stdout instead of Process (#9).


## 2024-04-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`native_doctor` - `v0.1.0-dev.3`](#native_doctor---v010-dev3)
 - [`native_toolchain_rust` - `v0.1.0-dev.2`](#native_toolchain_rust---v010-dev2)
 - [`native_toolchain_rust_common` - `v0.1.0-dev.2`](#native_toolchain_rust_common---v010-dev2)
 - [`rustup` - `v0.1.0-dev.2`](#rustup---v010-dev2)

---

#### `native_doctor` - `v0.1.0-dev.3`

 - **FIX**: correct rustup dependency version.
 - **FEAT**: add flutter package example.
 - **FEAT**: add dart example + refactor.
 - **FEAT**: native_doctor tweaks.
 - **FEAT**: add native_doctor.
 - **DOCS**: improve documentation (#2).

#### `native_toolchain_rust` - `v0.1.0-dev.2`

 - **FEAT**: add flutter package example.
 - **FEAT**: add dart example + refactor.
 - **FEAT**: add native_doctor.
 - **DOCS**: improve documentation (#2).

#### `native_toolchain_rust_common` - `v0.1.0-dev.2`

 - **FEAT**: add dart example + refactor.

#### `rustup` - `v0.1.0-dev.2`

 - **FEAT**: add dart example + refactor.
 - **FEAT**: add native_doctor.
 - **FEAT**: rustup install and uninstall.

