#!/bin/sh
# Fetches the official prebuilt Wasmtime C API (pinned version + sha256) into
# deps/wasmtime-c-api. No Rust toolchain needed. Idempotent.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
version=v42.0.0
name="wasmtime-$version-x86_64-linux-c-api"
sha256=ab5e9c144ea9ccc4b6f7b73a238e5ec58eb0ebf8fc74b52e4083dcdec9cfd6d5
dest="$root/deps/wasmtime-c-api"
if [ -f "$dest/.version" ] && [ "$(cat "$dest/.version")" = "$version" ]; then
  exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
url="https://github.com/bytecodealliance/wasmtime/releases/download/$version/$name.tar.xz"
curl -fsSL -o "$tmp/c-api.tar.xz" "$url"
echo "$sha256  $tmp/c-api.tar.xz" | sha256sum -c - >/dev/null
tar -xJf "$tmp/c-api.tar.xz" -C "$tmp"
rm -rf "$dest"
mkdir -p "$dest"
cp -r "$tmp/$name/include" "$tmp/$name/lib" "$tmp/$name/LICENSE" "$dest/"
echo "$version" > "$dest/.version"
