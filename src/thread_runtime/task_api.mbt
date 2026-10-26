///|
/// Tokio-like convenience API (experimental).
pub type JoinHandle = ThreadHandle

///|
pub fn ThreadRuntime::new(shared_pages : Int32) -> Result[ThreadRuntime, Error] {
  thread_runtime_new(shared_pages)
}

///|
pub fn ThreadRuntime::delete(self : ThreadRuntime) -> Unit {
  thread_runtime_delete(self)
}

///|
pub fn ThreadRuntime::spawn_wat(
  self : ThreadRuntime,
  wat : String,
  entry : String,
  args : Bytes,
) -> Result[JoinHandle, Error] {
  thread_runtime_spawn_wat(self, wat, entry, args)
}

///|
pub fn ThreadRuntime::spawn_wasm(
  self : ThreadRuntime,
  wasm : Bytes,
  entry : String,
  args : Bytes,
) -> Result[JoinHandle, Error] {
  thread_runtime_spawn_wasm(self, wasm, entry, args)
}

///|
pub fn ThreadRuntime::spawn_wasm_repeat(
  self : ThreadRuntime,
  wasm : Bytes,
  entry : String,
  args : Bytes,
  repeat : Int32,
) -> Result[JoinHandle, Error] {
  thread_runtime_spawn_wasm_repeat(self, wasm, entry, args, repeat)
}

///|
pub fn ThreadRuntime::precompile_cwasm(
  self : ThreadRuntime,
  wasm : Bytes,
) -> Result[Bytes, Error] {
  thread_runtime_precompile_cwasm(self, wasm)
}

///|
pub fn ThreadRuntime::spawn_cwasm(
  self : ThreadRuntime,
  cwasm : Bytes,
  entry : String,
  args : Bytes,
) -> Result[JoinHandle, Error] {
  thread_runtime_spawn_cwasm(self, cwasm, entry, args)
}

///|
pub fn ThreadRuntime::spawn_cwasm_repeat(
  self : ThreadRuntime,
  cwasm : Bytes,
  entry : String,
  args : Bytes,
  repeat : Int32,
) -> Result[JoinHandle, Error] {
  thread_runtime_spawn_cwasm_repeat(self, cwasm, entry, args, repeat)
}

///|
pub fn ThreadRuntime::wasi_preopen_dir(
  self : ThreadRuntime,
  host_path : String,
  guest_path~ : String = ".",
  dir_perms~ : WasiDirPerms = WASI_DIR_PERMS_READ,
  file_perms~ : WasiFilePerms = WASI_FILE_PERMS_READ,
) -> Result[Unit, Error] {
  thread_runtime_wasi_preopen_dir(
    self,
    host_path,
    guest_path~,
    dir_perms~,
    file_perms~,
  )
}

///|
pub fn ThreadRuntime::wasi_set_argv(
  self : ThreadRuntime,
  argv : Array[String],
) -> Result[Unit, Error] {
  thread_runtime_wasi_set_argv(self, argv)
}

///|
pub fn ThreadRuntime::wasi_inherit_argv(
  self : ThreadRuntime,
) -> Result[Unit, Error] {
  thread_runtime_wasi_inherit_argv(self)
}

///|
pub fn ThreadRuntime::wasi_inherit_stdio(
  self : ThreadRuntime,
) -> Result[Unit, Error] {
  thread_runtime_wasi_inherit_stdio(self)
}

///|
pub fn ThreadRuntime::mem_read(
  self : ThreadRuntime,
  offset : UInt64,
  len : Int32,
) -> Result[Bytes, Error] {
  thread_runtime_mem_read(self, offset, len)
}

///|
pub fn ThreadRuntime::mem_write(
  self : ThreadRuntime,
  offset : UInt64,
  bytes : Bytes,
) -> Result[Unit, Error] {
  thread_runtime_mem_write(self, offset, bytes)
}

///|
pub fn ThreadHandle::join(self : ThreadHandle) -> Result[Unit, Error] {
  thread_runtime_join(self)
}

///|
pub fn ThreadHandle::try_join(self : ThreadHandle) -> Result[Bool, Error] {
  thread_runtime_try_join(self)
}

///|
pub fn ThreadHandle::detach(self : ThreadHandle) -> Result[Unit, Error] {
  thread_runtime_detach(self)
}

///|
/// Tokio-like JoinSet for ThreadRuntime.
pub struct JoinSet {
  handles : Array[JoinHandle]
}

///|
pub fn JoinSet::new() -> JoinSet {
  { handles: [], }
}

///|
pub fn JoinSet::len(self : JoinSet) -> Int32 {
  self.handles.length()
}

///|
pub fn JoinSet::is_empty(self : JoinSet) -> Bool {
  self.handles.length() == 0
}

///|
pub fn JoinSet::push(self : JoinSet, handle : JoinHandle) -> Unit {
  self.handles.push(handle)
}

///|
pub fn JoinSet::join_all(self : JoinSet) -> Result[Unit, Error] {
  for handle in self.handles {
    let res = handle.join()
    guard res is Ok(_) else { return Err(res.unwrap_err()) }
  }
  self.handles.clear()
  Ok(())
}

///|
/// Try to join one finished task. Returns true if any handle completed.
pub fn JoinSet::try_join_next(self : JoinSet) -> Result[Bool, Error] {
  let len = self.handles.length()
  for i in 0..<len {
    let handle = self.handles[i]
    match handle.try_join() {
      Ok(done) =>
        if done {
          let _ = self.handles.remove(i)
          return Ok(true)
        }
      Err(err) => return Err(err)
    }
  }
  Ok(false)
}
