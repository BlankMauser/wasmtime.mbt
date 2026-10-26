// Synchronous sandbox over the official Wasmtime C API: run untrusted Wasm
// that imports nothing, under fuel, a wall-clock deadline and store limits,
// and get i32 results and bytes back. See sandbox_stub.c.

///|
#external
priv type Raw

///|
#borrow(wasm, msg)
extern "C" fn lf_sandbox_new(
  wasm : Bytes,
  len : Int,
  memory_bytes : Int64,
  table_elements : Int64,
  fuel : Int64,
  timeout_ms : Int64,
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
pub(all) struct Limits {
  memory_bytes : Int64
  table_elements : Int64
  /// Fuel (roughly instructions) per session.
  fuel : Int64
  /// Wall-clock milliseconds per session (epoch ticks every 1 ms).
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
struct Sandbox {
  raw : Raw
  limits : Limits
  mut freed : Bool
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
fn status(code : Int, name : String, msg : FixedArray[Byte]) -> Unit raise SandboxError {
  match code {
    0 => ()
    1 => raise Trap(message(msg))
    2 => raise OutOfFuel
    3 => raise TimedOut
    5 => raise Failed("`\{name}` did not return one i32")
    6 => raise NoExport(name)
    _ => raise Failed(message(msg))
  }
}

///|
/// Compiles and instantiates `wasm`; instantiation runs in the first
/// session (the module's start function, if any, spends its fuel).
pub fn Sandbox::new(wasm : Bytes, limits? : Limits = default_limits) -> Sandbox raise SandboxError {
  let msg = FixedArray::make(512, b'\x00')
  let raw = lf_sandbox_new(
    wasm,
    wasm.length(),
    limits.memory_bytes,
    limits.table_elements,
    limits.fuel,
    limits.timeout_ms,
    msg,
    msg.length(),
  )
  if lf_sandbox_is_null(raw) != 0 {
    raise Failed(message(msg))
  }
  { raw, limits, freed: false }
}

///|
/// Starts a session: the limits' fuel and deadline, shared by every call
/// until the next session.
pub fn Sandbox::session(self : Sandbox) -> Unit {
  lf_sandbox_session(self.raw, self.limits.fuel, self.limits.timeout_ms)
}

///|
/// Fuel left in the session.
pub fn Sandbox::fuel_left(self : Sandbox) -> Int64 {
  lf_sandbox_fuel(self.raw)
}

///|
/// Calls export `name` with i32 arguments; it must return one i32.
pub fn Sandbox::call(self : Sandbox, name : String, args : Array[Int]) -> Int raise SandboxError {
  if self.freed {
    raise Failed("sandbox was freed")
  }
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
  if self.freed {
    raise Failed("sandbox was freed")
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
