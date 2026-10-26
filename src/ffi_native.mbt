///|
/// Opaque WebAssembly engine type from the C API.
#external
pub type Engine

///|
/// Opaque WebAssembly store type from the C API.
#external
pub type Store

///|
/// Opaque Wasmtime store type from the C API.
#external
pub type WasmtimeStore

///|
/// Opaque Wasmtime context type from the C API.
#external
pub type Context

///|
/// Opaque WebAssembly config type from the C API.
#external
pub type Config

///|
/// Opaque Wasmtime error type from the C API.
#external
pub type WasmtimeError

///|
/// Opaque Wasmtime call future type from the C API.
#external
pub type CallFuture

///|
/// Opaque Wasmtime linker type from the C API.
#external
pub type Linker

///|
/// Opaque Wasmtime module type from the C API.
#external
pub type Module

///|
/// Opaque Wasmtime instance-pre type from the C API.
#external
pub type InstancePre

///|
/// Opaque WebAssembly function type from the C API.
#external
pub type FuncType

///|
/// Opaque WebAssembly trap type from the C API.
#external
pub type Trap

///|
/// Strategy identifiers (see wasmtime_config_strategy_set).
pub type Strategy = Int32

///|
/// Auto-select compilation strategy.
pub const STRATEGY_AUTO : Strategy = 0

///|
/// Force Cranelift compilation.
pub const STRATEGY_CRANELIFT : Strategy = 1

///|
/// Optimization level identifiers (see wasmtime_config_cranelift_opt_level_set).
pub type OptLevel = Int32

///|
/// No optimizations.
pub const OPT_LEVEL_NONE : OptLevel = 0

///|
/// Optimize for speed.
pub const OPT_LEVEL_SPEED : OptLevel = 1

///|
/// Optimize for speed and size.
pub const OPT_LEVEL_SPEED_AND_SIZE : OptLevel = 2

///|
/// Profiling strategy identifiers (see wasmtime_config_profiler_set).
pub type ProfilingStrategy = Int32

///|
/// No profiling.
pub const PROFILING_STRATEGY_NONE : ProfilingStrategy = 0

///|
/// Linux perf jitdump.
pub const PROFILING_STRATEGY_JITDUMP : ProfilingStrategy = 1

///|
/// Intel VTune profiling.
pub const PROFILING_STRATEGY_VTUNE : ProfilingStrategy = 2

///|
/// Linux perfmap.
pub const PROFILING_STRATEGY_PERFMAP : ProfilingStrategy = 3

///|
/// WebAssembly value kind identifiers (see wasm_valtype_new).
pub type ValKind = Int32

///|
/// wasm i32 value kind.
pub const VALKIND_I32 : ValKind = 0

///|
/// wasm i64 value kind.
pub const VALKIND_I64 : ValKind = 1

///|
/// wasm f32 value kind.
pub const VALKIND_F32 : ValKind = 2

///|
/// wasm f64 value kind.
pub const VALKIND_F64 : ValKind = 3

///|
/// wasm externref value kind.
pub const VALKIND_EXTERNREF : ValKind = 128

///|
/// wasm funcref value kind.
pub const VALKIND_FUNCREF : ValKind = 129

///|
/// Raw UTF-8 bytes from `wasmtime_version()`.
extern "C" fn wasmtime_version_bytes() -> Bytes = "wasmtime_version_bytes"

///|
/// Create a new WebAssembly engine.
pub extern "C" fn engine_new() -> Engine = "wasm_engine_new"

///|
/// Create a new engine with a configuration.
#owned(config)
pub extern "C" fn engine_new_with_config(config : Config) -> Engine = "wasm_engine_new_with_config"

///|
/// Destroy an engine created by `engine_new`.
#owned(engine)
pub extern "C" fn engine_delete(engine : Engine) -> Unit = "wasm_engine_delete"

///|
/// Create a new store associated with the given engine.
#borrow(engine)
pub extern "C" fn store_new(engine : Engine) -> Store = "wasm_store_new"

///|
/// Destroy a store created by `store_new`.
#owned(store)
pub extern "C" fn store_delete(store : Store) -> Unit = "wasm_store_delete"

///|
/// Create a new Wasmtime store (no data/finalizer).
#borrow(engine)
pub extern "C" fn wasmtime_store_new(engine : Engine) -> WasmtimeStore = "wasmtime_store_new_default"

///|
/// Destroy a Wasmtime store.
#owned(store)
pub extern "C" fn wasmtime_store_delete(store : WasmtimeStore) -> Unit = "wasmtime_store_delete"

///|
/// Get the Wasmtime context for a store.
#borrow(store)
pub extern "C" fn wasmtime_store_context(store : WasmtimeStore) -> Context = "wasmtime_store_context"

///|
/// Create a new configuration.
pub extern "C" fn config_new() -> Config = "wasm_config_new"

///|
/// Destroy a configuration created by `config_new`.
#owned(config)
pub extern "C" fn config_delete(config : Config) -> Unit = "wasm_config_delete"

///|
/// Enable/disable DWARF debug info.
#borrow(config)
pub extern "C" fn config_debug_info_set(config : Config, enable : Bool) -> Unit = "wasmtime_config_debug_info_set"

///|
/// Enable/disable fuel consumption.
#borrow(config)
pub extern "C" fn config_consume_fuel_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_consume_fuel_set"

///|
/// Enable/disable epoch interruption.
#borrow(config)
pub extern "C" fn config_epoch_interruption_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_epoch_interruption_set"

///|
/// Configure max wasm stack size in bytes.
#borrow(config)
pub extern "C" fn config_max_wasm_stack_set(
  config : Config,
  bytes : UInt64,
) -> Unit = "wasmtime_config_max_wasm_stack_set"

///|
/// Configure async stack size in bytes.
#borrow(config)
pub extern "C" fn config_async_stack_size_set(
  config : Config,
  bytes : UInt64,
) -> Unit = "wasmtime_config_async_stack_size_set"

///|
/// Enable/disable wasm threads.
#borrow(config)
pub extern "C" fn config_wasm_threads_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_threads_set"

///|
/// Enable/disable shared memories.
#borrow(config)
pub extern "C" fn config_shared_memory_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_shared_memory_set"

///|
/// Enable/disable tail calls.
#borrow(config)
pub extern "C" fn config_wasm_tail_call_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_tail_call_set"

///|
/// Enable/disable reference types.
#borrow(config)
pub extern "C" fn config_wasm_reference_types_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_reference_types_set"

///|
/// Enable/disable function references.
#borrow(config)
pub extern "C" fn config_wasm_function_references_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_function_references_set"

///|
/// Enable/disable GC proposal.
#borrow(config)
pub extern "C" fn config_wasm_gc_set(config : Config, enable : Bool) -> Unit = "wasmtime_config_wasm_gc_set"

///|
/// Enable/disable SIMD.
#borrow(config)
pub extern "C" fn config_wasm_simd_set(config : Config, enable : Bool) -> Unit = "wasmtime_config_wasm_simd_set"

///|
/// Enable/disable relaxed SIMD.
#borrow(config)
pub extern "C" fn config_wasm_relaxed_simd_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_relaxed_simd_set"

///|
/// Enable/disable deterministic relaxed SIMD.
#borrow(config)
pub extern "C" fn config_wasm_relaxed_simd_deterministic_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_relaxed_simd_deterministic_set"

///|
/// Enable/disable bulk memory.
#borrow(config)
pub extern "C" fn config_wasm_bulk_memory_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_bulk_memory_set"

///|
/// Enable/disable multi value.
#borrow(config)
pub extern "C" fn config_wasm_multi_value_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_multi_value_set"

///|
/// Enable/disable multi memory.
#borrow(config)
pub extern "C" fn config_wasm_multi_memory_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_multi_memory_set"

///|
/// Enable/disable memory64.
#borrow(config)
pub extern "C" fn config_wasm_memory64_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_memory64_set"

///|
/// Enable/disable wide arithmetic.
#borrow(config)
pub extern "C" fn config_wasm_wide_arithmetic_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_wide_arithmetic_set"

///|
/// Enable/disable exceptions.
#borrow(config)
pub extern "C" fn config_wasm_exceptions_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_exceptions_set"

///|
/// Enable/disable custom page sizes.
#borrow(config)
pub extern "C" fn config_wasm_custom_page_sizes_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_custom_page_sizes_set"

///|
/// Enable/disable stack switching.
#borrow(config)
pub extern "C" fn config_wasm_stack_switching_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_wasm_stack_switching_set"

///|
/// Set compilation strategy.
#borrow(config)
pub extern "C" fn config_strategy_set(
  config : Config,
  strategy : Strategy,
) -> Unit = "wasmtime_config_strategy_set"

///|
/// Enable/disable parallel compilation.
#borrow(config)
pub extern "C" fn config_parallel_compilation_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_parallel_compilation_set"

///|
/// Enable/disable Cranelift debug verifier.
#borrow(config)
pub extern "C" fn config_cranelift_debug_verifier_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_cranelift_debug_verifier_set"

///|
/// Enable/disable Cranelift NaN canonicalization.
#borrow(config)
pub extern "C" fn config_cranelift_nan_canonicalization_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_cranelift_nan_canonicalization_set"

///|
/// Set Cranelift optimization level.
#borrow(config)
pub extern "C" fn config_cranelift_opt_level_set(
  config : Config,
  level : OptLevel,
) -> Unit = "wasmtime_config_cranelift_opt_level_set"

///|
/// Configure profiling strategy.
#borrow(config)
pub extern "C" fn config_profiler_set(
  config : Config,
  strategy : ProfilingStrategy,
) -> Unit = "wasmtime_config_profiler_set"

///|
/// Configure memory movement semantics.
#borrow(config)
pub extern "C" fn config_memory_may_move_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_memory_may_move_set"

///|
/// Configure initial memory reservation size.
#borrow(config)
pub extern "C" fn config_memory_reservation_set(
  config : Config,
  bytes : UInt64,
) -> Unit = "wasmtime_config_memory_reservation_set"

///|
/// Configure memory guard size.
#borrow(config)
pub extern "C" fn config_memory_guard_size_set(
  config : Config,
  bytes : UInt64,
) -> Unit = "wasmtime_config_memory_guard_size_set"

///|
/// Configure memory reservation for growth size.
#borrow(config)
pub extern "C" fn config_memory_reservation_for_growth_set(
  config : Config,
  bytes : UInt64,
) -> Unit = "wasmtime_config_memory_reservation_for_growth_set"

///|
/// Enable/disable native unwind info.
#borrow(config)
pub extern "C" fn config_native_unwind_info_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_native_unwind_info_set"

///|
/// Enable/disable Mach ports for traps on macOS.
#borrow(config)
pub extern "C" fn config_macos_use_mach_ports_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_macos_use_mach_ports_set"

///|
/// Enable/disable signals-based traps.
#borrow(config)
pub extern "C" fn config_signals_based_traps_set(
  config : Config,
  enable : Bool,
) -> Unit = "wasmtime_config_signals_based_traps_set"

///|
/// Configure async fuel yield interval for a context.
#borrow(context)
pub extern "C" fn context_fuel_async_yield_interval(
  context : Context,
  interval : UInt64,
) -> WasmtimeError = "wasmtime_context_fuel_async_yield_interval"

///|
/// Configure async epoch deadline yield and update for a context.
#borrow(context)
pub extern "C" fn context_epoch_deadline_async_yield_and_update(
  context : Context,
  delta : UInt64,
) -> WasmtimeError = "wasmtime_context_epoch_deadline_async_yield_and_update"

///|
/// Poll an async call future. Returns true if completed.
#borrow(future)
pub extern "C" fn call_future_poll(future : CallFuture) -> Bool = "wasmtime_call_future_poll"

///|
/// Delete an async call future.
#owned(future)
pub extern "C" fn call_future_delete(future : CallFuture) -> Unit = "wasmtime_call_future_delete"

///|
/// Call a function asynchronously using bytes-backed values.
#borrow(context, func, args, results, trap_out, error_out)
pub extern "C" fn func_call_async_bytes(
  context : Context,
  func : Bytes,
  args : Bytes,
  nargs : Int32,
  results : Bytes,
  nresults : Int32,
  trap_out : Bytes,
  error_out : Bytes,
) -> CallFuture = "wasmtime_func_call_async_bytes"

///|
/// Define an async host function using raw callback pointers.
#borrow(linker, module_bytes, name, ty)
pub extern "C" fn linker_define_async_func_ptr(
  linker : Linker,
  module_bytes : Bytes,
  module_len : Int32,
  name : Bytes,
  name_len : Int32,
  ty : FuncType,
  cb_ptr : UInt64,
  data_ptr : UInt64,
  finalizer_ptr : UInt64,
) -> WasmtimeError = "wasmtime_linker_define_async_func_ptr"

///|
/// Instantiate a module asynchronously and write the instance into bytes.
#borrow(linker, context, module_val, instance_out, trap_out, error_out)
pub extern "C" fn linker_instantiate_async_bytes(
  linker : Linker,
  context : Context,
  module_val : Module,
  instance_out : Bytes,
  trap_out : Bytes,
  error_out : Bytes,
) -> CallFuture = "wasmtime_linker_instantiate_async_bytes"

///|
/// Instantiate a pre-initialized instance asynchronously.
#borrow(instance_pre, context, instance_out, trap_out, error_out)
pub extern "C" fn instance_pre_instantiate_async_bytes(
  instance_pre : InstancePre,
  context : Context,
  instance_out : Bytes,
  trap_out : Bytes,
  error_out : Bytes,
) -> CallFuture = "wasmtime_instance_pre_instantiate_async_bytes"

///|
/// Configure a custom stack creator from raw bytes.
#borrow(config, creator)
pub extern "C" fn config_host_stack_creator_set_bytes(
  config : Config,
  creator : Bytes,
) -> Unit = "wasmtime_config_host_stack_creator_set_bytes"

///|
/// Configure the target triple from UTF-8 bytes.
#borrow(config, bytes)
pub extern "C" fn config_target_set_bytes(
  config : Config,
  bytes : Bytes,
  len : Int32,
) -> WasmtimeError = "wasmtime_config_target_set_bytes"

///|
/// Configure cache from UTF-8 bytes (empty => default).
#borrow(config, bytes)
pub extern "C" fn config_cache_config_load_bytes(
  config : Config,
  bytes : Bytes,
  len : Int32,
) -> WasmtimeError = "wasmtime_config_cache_config_load_bytes"

///|
/// Enable a Cranelift flag from UTF-8 bytes.
#borrow(config, bytes)
pub extern "C" fn config_cranelift_flag_enable_bytes(
  config : Config,
  bytes : Bytes,
  len : Int32,
) -> Unit = "wasmtime_config_cranelift_flag_enable_bytes"

///|
/// Set a Cranelift flag from UTF-8 bytes.
#borrow(config, key, value)
pub extern "C" fn config_cranelift_flag_set_bytes(
  config : Config,
  key : Bytes,
  key_len : Int32,
  value : Bytes,
  value_len : Int32,
) -> Unit = "wasmtime_config_cranelift_flag_set_bytes"

///|
/// Size of a pointer in bytes.
pub extern "C" fn ptr_sizeof() -> Int32 = "moonbit_ptr_sizeof"

///|
/// Read a pointer value as UInt64 from bytes.
#borrow(bytes)
pub extern "C" fn ptr_read_u64(bytes : Bytes) -> UInt64 = "moonbit_ptr_read_u64"

///|
/// Check whether a pointer stored in bytes is null.
#borrow(bytes)
pub extern "C" fn ptr_is_null(bytes : Bytes) -> Bool = "moonbit_ptr_is_null"

///|
/// Clear a pointer stored in bytes.
#borrow(bytes)
pub extern "C" fn ptr_clear(bytes : Bytes) -> Unit = "moonbit_ptr_clear"

///|
/// Current monotonic time in nanoseconds.
pub extern "C" fn clock_now_ns() -> UInt64 = "moonbit_clock_now_ns"

///|
/// Delete a Wasmtime error pointer stored in bytes.
#borrow(bytes)
pub extern "C" fn error_delete_ptr(bytes : Bytes) -> Unit = "wasmtime_error_delete_ptr"

///|
/// Delete a trap pointer stored in bytes.
#borrow(bytes)
pub extern "C" fn trap_delete_ptr(bytes : Bytes) -> Unit = "wasm_trap_delete_ptr"

///|
/// Size of wasmtime_val_t in bytes.
pub extern "C" fn val_sizeof() -> Int32 = "wasmtime_val_sizeof"

///|
/// Size of wasmtime_instance_t in bytes.
pub extern "C" fn instance_sizeof() -> Int32 = "wasmtime_instance_sizeof"

///|
/// Size of wasmtime_func_t in bytes.
pub extern "C" fn func_sizeof() -> Int32 = "wasmtime_func_sizeof"

///|
/// Size of wasmtime_stack_creator_t in bytes.
pub extern "C" fn stack_creator_sizeof() -> Int32 = "wasmtime_stack_creator_sizeof"

///|
/// Read a wasmtime_val_t kind at index.
#borrow(vals)
pub extern "C" fn val_kind_at(vals : Bytes, index : Int32) -> Int32 = "wasmtime_val_kind_at"

///|
/// Set an i32 value at index.
#borrow(vals)
pub extern "C" fn val_set_i32_at(
  vals : Bytes,
  index : Int32,
  value : Int32,
) -> Unit = "wasmtime_val_set_i32_at"

///|
/// Set an i64 value at index.
#borrow(vals)
pub extern "C" fn val_set_i64_at(
  vals : Bytes,
  index : Int32,
  value : Int64,
) -> Unit = "wasmtime_val_set_i64_at"

///|
/// Set an f32 value at index.
#borrow(vals)
pub extern "C" fn val_set_f32_at(
  vals : Bytes,
  index : Int32,
  value : Float,
) -> Unit = "wasmtime_val_set_f32_at"

///|
/// Set an f64 value at index.
#borrow(vals)
pub extern "C" fn val_set_f64_at(
  vals : Bytes,
  index : Int32,
  value : Double,
) -> Unit = "wasmtime_val_set_f64_at"

///|
/// Get an i32 value at index.
#borrow(vals)
pub extern "C" fn val_get_i32_at(vals : Bytes, index : Int32) -> Int32 = "wasmtime_val_get_i32_at"

///|
/// Get an i64 value at index.
#borrow(vals)
pub extern "C" fn val_get_i64_at(vals : Bytes, index : Int32) -> Int64 = "wasmtime_val_get_i64_at"

///|
/// Get an f32 value at index.
#borrow(vals)
pub extern "C" fn val_get_f32_at(vals : Bytes, index : Int32) -> Float = "wasmtime_val_get_f32_at"

///|
/// Get an f64 value at index.
#borrow(vals)
pub extern "C" fn val_get_f64_at(vals : Bytes, index : Int32) -> Double = "wasmtime_val_get_f64_at"

///|
/// Unroot a value at index (for externref/anyref).
#borrow(vals)
pub extern "C" fn val_unroot_at(vals : Bytes, index : Int32) -> Unit = "wasmtime_val_unroot_at"

///|
/// Create a host function using raw callback pointers and write into bytes.
#borrow(context, ty, func_out)
pub extern "C" fn func_new_ptr_bytes(
  context : Context,
  ty : FuncType,
  cb_ptr : UInt64,
  data_ptr : UInt64,
  finalizer_ptr : UInt64,
  func_out : Bytes,
) -> Unit = "wasmtime_func_new_ptr_bytes"

///|
/// Create a function type from value kind byte arrays.
#borrow(params, results)
pub extern "C" fn functype_new_from_kinds(
  params : Bytes,
  nparams : Int32,
  results : Bytes,
  nresults : Int32,
) -> FuncType = "wasmtime_functype_new_from_kinds"

///|
/// Delete a function type.
#owned(ty)
pub extern "C" fn functype_delete(ty : FuncType) -> Unit = "wasm_functype_delete"

///|
/// Check if a functype pointer is null.
#borrow(ty)
pub extern "C" fn functype_is_null(ty : FuncType) -> Bool = "moonbit_is_null"

///|
/// Get a pointer to a no-op host function callback.
pub extern "C" fn noop_callback_ptr() -> UInt64 = "wasmtime_noop_callback_ptr"

///|
/// Delete a Wasmtime error.
#owned(error)
pub extern "C" fn error_delete(error : WasmtimeError) -> Unit = "wasmtime_error_delete"

///|
/// Check if a pointer-like error is null.
#borrow(error)
pub extern "C" fn error_is_null(error : WasmtimeError) -> Bool = "moonbit_is_null"
