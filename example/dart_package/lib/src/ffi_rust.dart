@ffi.DefaultAsset('package:dart_package/dart_ffi_plugin')
library rust;

import 'dart:ffi' as ffi;

@ffi.Native<ffi.IntPtr Function(ffi.IntPtr, ffi.IntPtr)>()
external int sum(
  int a,
  int b,
);
