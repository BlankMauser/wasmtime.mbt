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

///|
test "a local type the scan cannot size is refused, not miscounted" {
  // (func (local (ref null func)) (local i64 x 49990)): the two-byte type
  // used to shift the scan onto 0x70 and hide the 49,990.
  let b : Array[Byte] = [b'\x00', b'a', b's', b'm', b'\x01', b'\x00', b'\x00', b'\x00']
  b.append([b'\x01', b'\x04', b'\x01', b'\x60', b'\x00', b'\x00'])
  b.append([b'\x03', b'\x02', b'\x01', b'\x00'])
  let body : Array[Byte] = [b'\x02', b'\x01', b'\x63', b'\x70', b'\xc6', b'\x86', b'\x03', b'\x7e', b'\x0b']
  b.append([b'\x0a', (body.length() + 2).to_byte(), b'\x01', body.length().to_byte()])
  b.append(body)
  let m = try {
    @sandbox.Module::compile(Bytes::from_array(b)).free()
    "compiled"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_true(m.contains("unsupported local type"), msg=m)
}

///|
test "parameters count as locals" {
  // One type with 1000 i64 params; one function of it declaring 1 local.
  let b : Array[Byte] = [b'\x00', b'a', b's', b'm', b'\x01', b'\x00', b'\x00', b'\x00']
  let ty : Array[Byte] = [b'\x01', b'\x60', b'\xe8', b'\x07']
  for _ in 0..<1000 {
    ty.push(b'\x7e')
  }
  ty.push(b'\x00')
  b.push(b'\x01')
  b.append([((ty.length() & 0x7f) | 0x80).to_byte(), (ty.length() >> 7).to_byte()])
  b.append(ty)
  b.append([b'\x03', b'\x02', b'\x01', b'\x00'])
  let body : Array[Byte] = [b'\x01', b'\x01', b'\x7f', b'\x0b']
  b.append([b'\x0a', (body.length() + 2).to_byte(), b'\x01', body.length().to_byte()])
  b.append(body)
  let m = try {
    @sandbox.Module::compile(Bytes::from_array(b)).free()
    "compiled"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_true(m.contains("declares 1001 locals"), msg=m)
}

///|
test "a write into the guest's memory is what the guest reads; out of bounds is refused" {
  // (module (memory (export "memory") 1)
  //   (func (export "get") (param i32) (result i32) local.get 0 i32.load8_u))
  let wasm = b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x05\x03\x01\x00\x01\x07\x10\x02\x06\x6d\x65\x6d\x6f\x72\x79\x02\x00\x03\x67\x65\x74\x00\x00\x0a\x09\x01\x07\x00\x20\x00\x2d\x00\x00\x0b"
  let s = @sandbox.Sandbox::new(@sandbox.Module::compile(wasm))
  s.session()
  s.write("memory", 100, b"\x07\x2a")
  assert_eq(s.call("get", [101]), 42)
  assert_eq(s.read("memory", 100, 2), b"\x07\x2a")
  let out = FixedArray::make(4, b'\xff')
  s.read_into("memory", 100, 2, out, at=1)
  assert_eq(Bytes::from_array(out), b"\xff\x07\x2a\xff")
  let past = try {
    s.read_into("memory", 100, 2, out, at=3)
    "read"
  } catch {
    Failed(m) => m
    _ => "other"
  }
  assert_eq(past, "read of 2 bytes at 100 into 4 bytes at 3 is out of bounds")
  // A length or index near 2^31: `at + len` would wrap negative and pass a
  // naive check (then the copy overruns `out`).
  let refused_read = fn(len : Int, at : Int) -> String {
    try {
      s.read_into("memory", 0, len, out, at~)
      "read"
    } catch {
      Failed(m) => m
      _ => "other"
    }
  }
  assert_eq(refused_read(0x7fffffff, 4), "read of 2147483647 bytes at 0 into 4 bytes at 4 is out of bounds")
  assert_eq(refused_read(2, 0x7fffffff), "read of 2 bytes at 0 into 4 bytes at 2147483647 is out of bounds")
  assert_eq(refused_read(0x7ffffffe, 2), "read of 2147483646 bytes at 0 into 4 bytes at 2 is out of bounds")
  // The last byte of the 64 KiB page, then one past it.
  s.write("memory", 65535, b"\x09")
  assert_eq(s.call("get", [65535]), 9)
  let refused = fn(memory : String, offset : Int, data : Bytes) -> String {
    try {
      s.write(memory, offset, data)
      "written"
    } catch {
      Failed(m) => m
      NoExport(n) => "no export \{n}"
      _ => "other"
    }
  }
  assert_eq(refused("memory", 65535, b"\x01\x02"), "write of 2 bytes at 65535 is out of bounds")
  assert_eq(refused("memory", -1, b"\x01"), "write of 1 bytes at -1 is out of bounds")
  assert_eq(refused("nope", 0, b"\x01"), "no export nope")
  // An offset near 2^31: offset + length past Int's range is refused.
  assert_eq(refused("memory", 0x7fffffff, b"\x01\x02"), "write of 2 bytes at 2147483647 is out of bounds")
  s.free()
}
