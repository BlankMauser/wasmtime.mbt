///|
/// Create engine/store/context for async execution.
pub fn async_context_new(
  async_stack_size : UInt64,
) -> (Engine, WasmtimeStore, Context) {
  let config = config_new()
  config_async_stack_size_set(config, async_stack_size)
  let engine = engine_new_with_config(config)
  let store = wasmtime_store_new(engine)
  let context = wasmtime_store_context(store)
  (engine, store, context)
}

///|
/// Delete async engine/store pair.
pub fn async_context_delete(engine : Engine, store : WasmtimeStore) -> Unit {
  wasmtime_store_delete(store)
  engine_delete(engine)
}

///|
/// Call a function asynchronously with buffer-derived counts.
pub fn func_call_async(
  context : Context,
  func_bytes : Bytes,
  args : Bytes,
  results : Bytes,
  trap_ptr : Bytes,
  err_ptr : Bytes,
) -> CallFuture raise {
  let nargs = val_buffer_count_or_raise(args)
  let nresults = val_buffer_count_or_raise(results)
  func_call_async_bytes(
    context, func_bytes, args, nargs, results, nresults, trap_ptr, err_ptr,
  )
}

///|
/// Call a function asynchronously and return a Result.
pub fn func_call_async_result(
  context : Context,
  func_bytes : Bytes,
  args : Bytes,
  results : Bytes,
  trap_ptr : Bytes,
  err_ptr : Bytes,
) -> Result[CallFuture, Error] {
  let nargs = val_buffer_count_result(args)
  let nresults = val_buffer_count_result(results)
  match (nargs, nresults) {
    (Ok(nargs_val), Ok(nresults_val)) => {
      let future = func_call_async_bytes(
        context, func_bytes, args, nargs_val, results, nresults_val, trap_ptr, err_ptr,
      )
      if ptr_buffer_is_null(err_ptr) && ptr_buffer_is_null(trap_ptr) {
        Ok(future)
      } else {
        let err_present = !ptr_buffer_is_null(err_ptr)
        let trap_present = !ptr_buffer_is_null(trap_ptr)
        Err(
          @builtin.Failure::Failure(
            "func_call_async failed (error=\{err_present}, trap=\{trap_present})",
          ),
        )
      }
    }
    (Ok(_), Err(err)) => Err(err)
    (Err(err), _) => Err(err)
  }
}

///|
/// Call a function asynchronously, auto-cleaning trap/error pointers on failure.
pub fn func_call_async_result_autoclean(
  context : Context,
  func_bytes : Bytes,
  args : Bytes,
  results : Bytes,
  trap_ptr : Bytes,
  err_ptr : Bytes,
) -> Result[CallFuture, Error] {
  let res = func_call_async_result(
    context, func_bytes, args, results, trap_ptr, err_ptr,
  )
  match res {
    Ok(future) => {
      ptr_buffer_clear(err_ptr)
      ptr_buffer_clear(trap_ptr)
      Ok(future)
    }
    Err(err) => {
      error_delete_ptr_buffer(err_ptr)
      trap_delete_ptr_buffer(trap_ptr)
      Err(err)
    }
  }
}
