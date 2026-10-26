///|
test "a guest returns an i32" {
  // (module (func (export "add") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))
  let wasm = b"\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b"
  let s = @sandbox.Sandbox::new(wasm)
  s.session()
  assert_eq(s.call("add", [40, 2]), 42)
  s.free()
}
