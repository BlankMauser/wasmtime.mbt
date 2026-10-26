// Synchronous sandbox over the official Wasmtime C API: run untrusted Wasm
// that imports nothing, under fuel, a deadline and store limits, and get
// i32 results and bytes back. See sandbox_stub.c.
//
// Compilation is not bounded by fuel or the deadline (Cranelift runs first;
// 600k tiny functions took 27 s and 3.5 GB), so `Module::compile` scans the
// module's sections and refuses it beyond `CompileLimits` before Wasmtime
// sees it; compile once, instantiate as often as needed.

///|
#external
priv type RawModule

///|
#external
priv type Raw

///|
#borrow(wasm, msg)
extern "C" fn lf_module_new(wasm : Bytes, len : Int, msg : FixedArray[Byte], cap : Int) -> RawModule = "lf_module_new"

///|
extern "C" fn lf_module_is_null(m : RawModule) -> Int = "lf_module_is_null"

///|
extern "C" fn lf_module_free(m : RawModule) -> Unit = "lf_module_free"

///|
#borrow(status, msg)
extern "C" fn lf_sandbox_new(
  module_ : RawModule,
  memory_bytes : Int64,
  table_elements : Int64,
  fuel : Int64,
  timeout_ms : Int64,
  status : FixedArray[Int],
  msg : FixedArray[Byte],
  cap : Int,
) -> Raw = "lf_sandbox_new"

///|
extern "C" fn lf_sandbox_is_null(s : Raw) -> Int = "lf_sandbox_is_null"

///|
extern "C" fn lf_sandbox_free(s : Raw) -> Unit = "lf_sandbox_free"

///|
extern "C" fn lf_sandbox_session(s : Raw, fuel : Int64, timeout_ms : Int64) -> Unit = "lf_sandbox_session"

///|
extern "C" fn lf_sandbox_fuel(s : Raw) -> Int64 = "lf_sandbox_fuel"

///|
#borrow(name, args, result, msg)
extern "C" fn lf_sandbox_call_i32(
  s : Raw,
  name : Bytes,
  name_len : Int,
  args : FixedArray[Int],
  nargs : Int,
  result : FixedArray[Int],
  msg : FixedArray[Byte],
  cap : Int,
) -> Int = "lf_sandbox_call_i32"

///|
#borrow(name, out)
extern "C" fn lf_sandbox_read(
  s : Raw,
  name : Bytes,
  name_len : Int,
  offset : Int,
  len : Int,
  out : FixedArray[Byte],
) -> Int = "lf_sandbox_read"

///|
pub(all) suberror SandboxError {
  /// Compile, instantiate or call error (the message says which).
  Failed(String)
  /// A trap in guest code (unreachable, out of bounds, stack overflow...).
  Trap(String)
  OutOfFuel
  TimedOut
  NoExport(String)
} derive(Debug)

///|
/// Bounds checked before compiling (compilation itself is not bounded).
pub(all) struct CompileLimits {
  module_bytes : Int
  /// Imported plus defined functions.
  functions : Int
  /// The code section.
  code_bytes : Int
  /// Declared locals in one function. Cranelift zero-initialises each one:
  /// 10k functions x 50,000 locals is 100 KB of module and ~20 s to compile.
  locals_per_function : Int
  /// Declared locals in all functions.
  locals : Int
}

///|
pub let default_compile_limits : CompileLimits = {
  module_bytes: 4 * 1024 * 1024,
  functions: 10_000,
  code_bytes: 1024 * 1024,
  locals_per_function: 1000,
  locals: 200_000,
}

///|
pub(all) struct Limits {
  memory_bytes : Int64
  table_elements : Int64
  /// Fuel (roughly instructions) per session. Bulk operations cost almost
  /// nothing (a 64 MB memory.fill is ~12 fuel): `timeout_ms` bounds work.
  fuel : Int64
  /// Milliseconds of guest running time per session (an epoch ticks every
  /// 1 ms while a guest runs).
  timeout_ms : Int64
}

///|
pub let default_limits : Limits = {
  memory_bytes: 64L * 1024L * 1024L,
  table_elements: 100_000L,
  fuel: 1_000_000_000L,
  timeout_ms: 2000L,
}

///|
fn message(buf : FixedArray[Byte]) -> String {
  let mut n = 0
  while n < buf.length() && buf[n] != b'\x00' {
    n += 1
  }
  @utf8.decode_lossy(Bytes::makei(n, i => buf[i]))
}

///|
/// Section sizes and counts read before compiling. Raises on anything that
/// is not a well-formed section list (Wasmtime would refuse it anyway).
priv struct Scan {
  mut functions : Int
  mut code_bytes : Int
  /// The largest local count of one function, and the sum (Int64: each
  /// declaration may claim up to 2^31 locals).
  mut max_locals : Int64
  mut locals : Int64
}

///|
fn leb_u32(b : Bytes, pos : Int) -> (Int, Int) raise SandboxError {
  let mut result = 0L
  let mut shift = 0
  let mut p = pos
  while true {
    if p >= b.length() || shift > 28 {
      raise Failed("malformed module: bad LEB128 at \{pos}")
    }
    let byte = b[p].to_int()
    result = result | ((byte & 0x7f).to_int64() << shift)
    p += 1
    if (byte & 0x80) == 0 {
      break
    }
    shift += 7
  }
  if result > 0xffffffffL || result > 0x7fffffffL {
    raise Failed("malformed module: count too large at \{pos}")
  }
  (result.to_int(), p)
}

///|
fn scan(b : Bytes) -> Scan raise SandboxError {
  if b.length() < 8 || b[0] != b'\x00' || b[1] != b'a' || b[2] != b's' || b[3] != b'm' {
    raise Failed("not a Wasm module")
  }
  let s : Scan = { functions: 0, code_bytes: 0, max_locals: 0L, locals: 0L }
  let mut p = 8
  while p < b.length() {
    let id = b[p].to_int()
    let (size, body) = leb_u32(b, p + 1)
    if body + size > b.length() {
      raise Failed("malformed module: section \{id} runs past the end")
    }
    match id {
      // Imports: count imported functions (kind 0). Entries are
      // module name, field name, kind, then a kind-specific descriptor; a
      // guest may import nothing anyway, so only the function count matters
      // and malformed entries are left to Wasmtime.
      2 => {
        let (n, q) = leb_u32(b, body)
        let mut q = q
        for _ in 0..<n {
          let (ml, q1) = leb_u32(b, q)
          let (fl, q2) = leb_u32(b, q1 + ml)
          let kind_at = q2 + fl
          if kind_at >= body + size {
            break
          }
          if b[kind_at] == b'\x00' {
            s.functions += 1
          }
          // Skip the descriptor conservatively: the remaining imports only
          // add to the count, and any import fails instantiation.
          q = body + size
        }
        ignore(q)
      }
      3 => {
        let (n, _) = leb_u32(b, body)
        s.functions += n
      }
      // Code: each body is size, then local declarations (count x (n, type)).
      10 => {
        s.code_bytes += size
        let (n, q) = leb_u32(b, body)
        let mut q = q
        for _ in 0..<n {
          let (fsize, fbody) = leb_u32(b, q)
          if fbody + fsize > body + size {
            raise Failed("malformed module: function body runs past the code section")
          }
          let (decls, d) = leb_u32(b, fbody)
          let mut d = d
          let mut count = 0L
          for _ in 0..<decls {
            let (k, t) = leb_u32(b, d)
            count += k.to_int64()
            d = t + 1 // the value type byte
            if d > fbody + fsize {
              raise Failed("malformed module: local declarations run past the body")
            }
          }
          if count > s.max_locals {
            s.max_locals = count
          }
          s.locals += count
          q = fbody + fsize
        }
      }
      _ => ()
    }
    p = body + size
  }
  s
}

///|
/// A compiled module, reusable for any number of instances.
struct Module {
  raw : RawModule
  mut freed : Bool
}

///|
/// Checks `wasm` against `limits`, then compiles it (outside fuel and the
/// deadline: the limits are what bound compilation).
pub fn Module::compile(
  wasm : Bytes,
  limits? : CompileLimits = default_compile_limits,
) -> Module raise SandboxError {
  if wasm.length() > limits.module_bytes {
    raise Failed("module is \{wasm.length()} bytes; the limit is \{limits.module_bytes}")
  }
  let s = scan(wasm)
  if s.functions > limits.functions {
    raise Failed("module has \{s.functions} functions; the limit is \{limits.functions}")
  }
  if s.code_bytes > limits.code_bytes {
    raise Failed("module has \{s.code_bytes} bytes of code; the limit is \{limits.code_bytes}")
  }
  if s.max_locals > limits.locals_per_function.to_int64() {
    raise Failed("a function declares \{s.max_locals} locals; the limit is \{limits.locals_per_function}")
  }
  if s.locals > limits.locals.to_int64() {
    raise Failed("functions declare \{s.locals} locals in all; the limit is \{limits.locals}")
  }
  let msg = FixedArray::make(512, b'\x00')
  let raw = lf_module_new(wasm, wasm.length(), msg, msg.length())
  if lf_module_is_null(raw) != 0 {
    raise Failed(message(msg))
  }
  { raw, freed: false }
}

///|
pub fn Module::free(self : Module) -> Unit {
  if !self.freed {
    self.freed = true
    lf_module_free(self.raw)
  }
}

///|
struct Sandbox {
  raw : Raw
  limits : Limits
  mut freed : Bool
}

///|
fn status(code : Int, name : String, msg : FixedArray[Byte]) -> Unit raise SandboxError {
  match code {
    0 => ()
    1 => raise Trap(message(msg))
    2 => raise OutOfFuel
    3 => raise TimedOut
    5 => raise Failed("does not return one i32")
    6 => raise NoExport(name)
    _ => raise Failed(message(msg))
  }
}

///|
/// Instantiates a compiled module; instantiation runs in the first session
/// (a start function spends its fuel and deadline).
pub fn Sandbox::new(module_ : Module, limits? : Limits = default_limits) -> Sandbox raise SandboxError {
  if module_.freed {
    raise Failed("module was freed")
  }
  let msg = FixedArray::make(512, b'\x00')
  let st = FixedArray::make(1, 4)
  let raw = lf_sandbox_new(
    module_.raw,
    limits.memory_bytes,
    limits.table_elements,
    limits.fuel,
    limits.timeout_ms,
    st,
    msg,
    msg.length(),
  )
  if lf_sandbox_is_null(raw) != 0 {
    status(st[0], "start", msg)
    raise Failed(message(msg))
  }
  { raw, limits, freed: false }
}

///|
fn Sandbox::alive(self : Sandbox) -> Unit raise SandboxError {
  if self.freed {
    raise Failed("sandbox was freed")
  }
}

///|
/// Starts a session: the limits' fuel and deadline, shared by every call
/// until the next session.
pub fn Sandbox::session(self : Sandbox) -> Unit raise SandboxError {
  self.alive()
  lf_sandbox_session(self.raw, self.limits.fuel, self.limits.timeout_ms)
}

///|
/// Fuel left in the session.
pub fn Sandbox::fuel_left(self : Sandbox) -> Int64 raise SandboxError {
  self.alive()
  lf_sandbox_fuel(self.raw)
}

///|
/// Calls export `name` with i32 arguments; it must return one i32.
pub fn Sandbox::call(self : Sandbox, name : String, args : Array[Int]) -> Int raise SandboxError {
  self.alive()
  if args.length() > 8 {
    raise Failed("at most 8 arguments")
  }
  let msg = FixedArray::make(512, b'\x00')
  let result = FixedArray::make(1, 0)
  let n = @utf8.encode(name)
  let a = FixedArray::from_array(args)
  status(lf_sandbox_call_i32(self.raw, n, n.length(), a, args.length(), result, msg, msg.length()), name, msg)
  result[0]
}

///|
/// `len` bytes at `offset` of exported memory `memory` (bounds-checked).
pub fn Sandbox::read(self : Sandbox, memory : String, offset : Int, len : Int) -> Bytes raise SandboxError {
  self.alive()
  if offset < 0 || len < 0 || len > self.limits.memory_bytes.to_int() {
    raise Failed("read of \{len} bytes at \{offset} is out of bounds")
  }
  let out = FixedArray::make(len, b'\x00')
  let n = @utf8.encode(memory)
  match lf_sandbox_read(self.raw, n, n.length(), offset, len, out) {
    0 => Bytes::makei(len, i => out[i])
    6 => raise NoExport(memory)
    _ => raise Failed("read of \{len} bytes at \{offset} is out of bounds")
  }
}

///|
pub fn Sandbox::free(self : Sandbox) -> Unit {
  if !self.freed {
    self.freed = true
    lf_sandbox_free(self.raw)
  }
}
