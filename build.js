// moon prebuild (module level): fetch the pinned prebuilt Wasmtime C API and
// hand moon absolute include and link flags. Link flags set in a package's
// moon.pkg do not reach binaries of dependent modules; link_configs here do.
const { execFileSync } = require('node:child_process');
const path = require('node:path');

const root = __dirname;
execFileSync('sh', [path.join(root, 'scripts', 'fetch-wasmtime-c-api.sh')], { stdio: ['ignore', 'ignore', 'inherit'] });
const capi = path.join(root, 'deps', 'wasmtime-c-api');
const lib = path.join(capi, 'lib', 'libwasmtime.a');
const linkFlags = `${lib} -lpthread -ldl -lm`;
console.log(JSON.stringify({
  vars: { WASMTIME_C_API_INCLUDE: path.join(capi, 'include') },
  link_configs: [
    { package: 'mizchi/wasmtime', link_flags: linkFlags },
    { package: 'mizchi/wasmtime/sandbox', link_flags: linkFlags },
  ],
}));
