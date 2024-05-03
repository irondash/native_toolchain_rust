@ffi.DefaultAsset('package:flutter_package/flutter_ffi_plugin')
library rust;

import 'dart:ffi' as ffi;

@ffi.Native<ffi.IntPtr Function(ffi.IntPtr, ffi.IntPtr)>()
external int sum(
  int a,
  int b,
);
