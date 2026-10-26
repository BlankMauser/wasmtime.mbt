// moon prebuild (module level): fetch the pinned prebuilt Wasmtime C API and
// hand moon absolute include and link flags. Link flags set in a package's
// moon.pkg do not reach binaries of dependent modules; link_configs here do.
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const root = __dirname;
execFileSync('sh', [path.join(root, 'scripts', 'fetch-wasmtime-c-api.sh')], { stdio: ['ignore', 'ignore', 'inherit'] });
const capi = path.join(root, 'deps', 'wasmtime-c-api');
// Shared, not static: a static libwasmtime.a brings its own Rust std, which
// collides with any other Rust staticlib in the same binary (wgpu-native:
// duplicate `rust_eh_personality`).
const libDir = path.join(capi, 'lib');
const linkFlags = `${path.join(libDir, 'libwasmtime.so')} -Wl,-rpath,${libDir} -lpthread -ldl -lm`;
console.log(JSON.stringify({
  vars: { WASMTIME_C_API_INCLUDE: path.join(capi, 'include') },
  link_configs: [
    { package: 'mizchi/wasmtime', link_flags: linkFlags },
    { package: 'mizchi/wasmtime/sandbox', link_flags: linkFlags },
  ],
}));
