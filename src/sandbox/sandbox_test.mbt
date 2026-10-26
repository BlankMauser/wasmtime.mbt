///|
test "a guest returns an i32" {
  // (module (func (export "add") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))
  let wasm = b"\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b"
  let s = @sandbox.Sandbox::new(@sandbox.Module::compile(wasm))
  s.session()
  assert_eq(s.call("add", [40, 2]), 42)
  s.free()
}

///|
test "modules beyond the compile limits are refused before compiling" {
  let wasm = b"\x00asm\x01\x00\x00\x00\x01\x07\x01\x60\x02\x7f\x7f\x01\x7f\x03\x02\x01\x00\x07\x07\x01\x03add\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x20\x01\x6a\x0b"
  let tight = { ..@sandbox.default_compile_limits, functions: 0 }
  let m = try {
    ignore(@sandbox.Module::compile(wasm, limits=tight))
    "compiled"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_true(m.contains("1 functions; the limit is 0"), msg=m)
  let m = try {
    ignore(@sandbox.Module::compile(wasm, limits={ ..@sandbox.default_compile_limits, code_bytes: 4 }))
    "compiled"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_true(m.contains("bytes of code"), msg=m)
  // A freed sandbox refuses instead of touching freed memory.
  let s = @sandbox.Sandbox::new(@sandbox.Module::compile(wasm))
  s.free()
  let m = try {
    s.session()
    "ran"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_eq(m, "sandbox was freed")
}

///|
/// `n` functions each declaring `locals` i32 locals.
fn with_locals(n : Int, locals : Int) -> Bytes {
  let leb = fn(v : Int) -> Array[Byte] {
    let out : Array[Byte] = []
    let mut v = v
    while true {
      let b = v & 0x7f
      v = v >> 7
      if v == 0 {
        out.push(b.to_byte())
        break
      }
      out.push((b | 0x80).to_byte())
    }
    out
  }
  let b : Array[Byte] = [b'\x00', b'a', b's', b'm', b'\x01', b'\x00', b'\x00', b'\x00']
  b.append([b'\x01', b'\x04', b'\x01', b'\x60', b'\x00', b'\x00'])
  let funcs = leb(n)
  for _ in 0..<n {
    funcs.push(b'\x00')
  }
  b.push(b'\x03')
  b.append(leb(funcs.length()))
  b.append(funcs)
  let entry : Array[Byte] = [b'\x01'] + leb(locals) + [b'\x7f', b'\x0b']
  let code = leb(n)
  for _ in 0..<n {
    code.append(leb(entry.length()))
    code.append(entry)
  }
  b.push(b'\x0a')
  b.append(leb(code.length()))
  b.append(code)
  Bytes::from_array(b)
}

///|
test "declared locals are capped before compiling" {
  let err = fn(w : Bytes) {
    try {
      @sandbox.Module::compile(w).free()
      "compiled"
    } catch {
      Failed(m) => m
      _ => "other"
    }
  }
  // 10k x 50,000 locals: ~20 s of Cranelift before the cap.
  assert_true(err(with_locals(10_000, 50_000)).contains("declares 50000 locals; the limit is 1000"))
  assert_true(err(with_locals(1000, 1000)).contains("1000000 locals in all; the limit is 200000"))
  assert_eq(err(with_locals(100, 200)), "compiled")
}
