///|
/// Allocate a bytes buffer sized to hold one native pointer.
pub fn make_ptr_buffer() -> Bytes {
  Bytes::make(ptr_sizeof(), 0)
}

///|
/// Read a pointer value as UInt64 from a bytes buffer.
pub fn ptr_buffer_read_u64(ptr_buf : Bytes) -> UInt64 {
  ptr_read_u64(ptr_buf)
}

///|
/// Returns true when the pointer stored in the buffer is null.
pub fn ptr_buffer_is_null(ptr_buf : Bytes) -> Bool {
  ptr_is_null(ptr_buf)
}

///|
/// Clear a pointer buffer to null.
pub fn ptr_buffer_clear(ptr_buf : Bytes) -> Unit {
  ptr_clear(ptr_buf)
}

///|
/// Delete a Wasmtime error pointer stored in bytes if not null.
pub fn error_delete_ptr_buffer(ptr_buf : Bytes) -> Unit {
  if !ptr_is_null(ptr_buf) {
    error_delete_ptr(ptr_buf)
  }
}

///|
/// Delete a trap pointer stored in bytes if not null.
pub fn trap_delete_ptr_buffer(ptr_buf : Bytes) -> Unit {
  if !ptr_is_null(ptr_buf) {
    trap_delete_ptr(ptr_buf)
  }
}

///|
/// Allocate a buffer for `n` wasmtime_val_t values.
pub fn make_val_buffer(n : Int32) -> Bytes {
  Bytes::make(n * val_sizeof(), 0)
}

///|
/// Compute the number of values in a buffer.
pub fn val_buffer_count(buf : Bytes) -> Int32 {
  let size = val_sizeof()
  if size == 0 {
    0
  } else {
    buf.length() / size
  }
}

///|
/// Validate a val buffer and return the count or an error.
pub fn val_buffer_count_result(buf : Bytes) -> Result[Int32, Error] {
  let size = val_sizeof()
  if size <= 0 {
    Err(@builtin.Failure::Failure("invalid val size"))
  } else if buf.length() % size != 0 {
    Err(@builtin.Failure::Failure("invalid val buffer length"))
  } else {
    Ok(buf.length() / size)
  }
}

///|
/// Validate a val buffer and return the count or raise.
pub fn val_buffer_count_or_raise(buf : Bytes) -> Int32 raise {
  let size = val_sizeof()
  if size <= 0 {
    fail("invalid val size")
  } else if buf.length() % size != 0 {
    fail("invalid val buffer length")
  } else {
    buf.length() / size
  }
}

///|
/// Allocate a buffer for wasmtime_instance_t.
pub fn make_instance_buffer() -> Bytes {
  Bytes::make(instance_sizeof(), 0)
}

///|
/// Allocate a buffer for wasmtime_func_t.
pub fn make_func_buffer() -> Bytes {
  Bytes::make(func_sizeof(), 0)
}

///|
/// Allocate a buffer for wasmtime_stack_creator_t.
pub fn make_stack_creator_buffer() -> Bytes {
  Bytes::make(stack_creator_sizeof(), 0)
}

///|
/// Set i32 value at index in a val buffer.
pub fn val_buffer_set_i32(buf : Bytes, index : Int32, value : Int32) -> Unit {
  val_set_i32_at(buf, index, value)
}

///|
/// Set i64 value at index in a val buffer.
pub fn val_buffer_set_i64(buf : Bytes, index : Int32, value : Int64) -> Unit {
  val_set_i64_at(buf, index, value)
}

///|
/// Set f32 value at index in a val buffer.
pub fn val_buffer_set_f32(buf : Bytes, index : Int32, value : Float) -> Unit {
  val_set_f32_at(buf, index, value)
}

///|
/// Set f64 value at index in a val buffer.
pub fn val_buffer_set_f64(buf : Bytes, index : Int32, value : Double) -> Unit {
  val_set_f64_at(buf, index, value)
}

///|
/// Get i32 value at index in a val buffer.
pub fn val_buffer_get_i32(buf : Bytes, index : Int32) -> Int32 {
  val_get_i32_at(buf, index)
}

///|
/// Get i64 value at index in a val buffer.
pub fn val_buffer_get_i64(buf : Bytes, index : Int32) -> Int64 {
  val_get_i64_at(buf, index)
}

///|
/// Get f32 value at index in a val buffer.
pub fn val_buffer_get_f32(buf : Bytes, index : Int32) -> Float {
  val_get_f32_at(buf, index)
}

///|
/// Get f64 value at index in a val buffer.
pub fn val_buffer_get_f64(buf : Bytes, index : Int32) -> Double {
  val_get_f64_at(buf, index)
}

///|
/// Unroot a value at index in a val buffer.
pub fn val_buffer_unroot_at(buf : Bytes, index : Int32) -> Unit {
  val_unroot_at(buf, index)
}
