name = "mizchi/wasmtime"

version = "0.1.6"

import {
  "moonbitlang/x@0.5.1",
  "moonbitlang/async@0.22.5",
}

readme = "README.mbt.md"

repository = "https://github.com/mizchi/wasmtime.mbt"

license = "Apache-2.0"

keywords = [ "wasmtime", "wasm", "ffi", "native" ]

description = "Wasmtime C API bindings for MoonBit (native target)"

source = "src"

preferred_target = "native"

options(
  exclude: [ "deps/wasmtime/**", "deps/wasmtime-c-api/**" ],
  "--moonbit-unstable-prebuild": "build.js",
)