// A small synchronous sandbox over the official Wasmtime C API (v42
// headers, linked against the prebuilt libwasmtime). Built for running
// untrusted guests that only compute and return data:
// - modules are compiled once (`lf_module_new`, after the MoonBit side has
//   capped function count, code bytes and module size: compilation itself
//   is not bounded by fuel or the deadline) and instantiated as often as
//   needed (`lf_sandbox_new`);
// - no imports are ever provided (a module that imports anything fails to
//   instantiate);
// - fuel (instructions) and an epoch deadline (milliseconds of guest
//   running time) bound execution; the caller sets both once per session,
//   so they span calls. Fuel does not price bulk operations (a 64 MB
//   memory.fill costs ~12 fuel): the deadline is the real work bound;
// - a store limiter caps linear memory, table elements, instances, tables
//   and memories; a small memory reservation keeps address space per
//   instance near the memory limit;
// - Wasm GC, exceptions, threads, shared memory, stack switching, memory64,
//   multi-memory, wide arithmetic, custom page sizes are off; relaxed SIMD
//   is deterministic and NaNs are canonicalised, so plans do not depend on
//   the host CPU.
#include <wasmtime.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Statuses returned to MoonBit.
enum {
  LF_OK = 0,
  LF_TRAP = 1,
  LF_OUT_OF_FUEL = 2,
  LF_TIMEOUT = 3,
  LF_ERROR = 4,
  LF_BAD_RESULT = 5,
  LF_NO_EXPORT = 6,
};

static wasm_engine_t *g_engine = NULL;
static int g_ticker_ok = 0;
static pthread_once_t g_once = PTHREAD_ONCE_INIT;
// Guest calls in progress: the ticker advances the epoch only while > 0,
// so an idle host does not wake 1000 times a second and the deadline
// counts guest running time.
static atomic_int g_running = 0;

static void *ticker(void *arg) {
  (void)arg;
  struct timespec ms = {0, 1000000};
  struct timespec idle = {0, 20000000};
  for (;;) {
    if (atomic_load(&g_running) > 0) {
      nanosleep(&ms, NULL);
      wasmtime_engine_increment_epoch(g_engine);
    } else {
      nanosleep(&idle, NULL);
    }
  }
  return NULL;
}

static void engine_init(void) {
  wasm_config_t *config = wasm_config_new();
  wasmtime_config_consume_fuel_set(config, true);
  wasmtime_config_epoch_interruption_set(config, true);
  wasmtime_config_wasm_gc_set(config, false);
  wasmtime_config_wasm_function_references_set(config, false);
  wasmtime_config_wasm_exceptions_set(config, false);
  wasmtime_config_wasm_threads_set(config, false);
  wasmtime_config_shared_memory_set(config, false);
  wasmtime_config_wasm_stack_switching_set(config, false);
  wasmtime_config_wasm_memory64_set(config, false);
  wasmtime_config_wasm_multi_memory_set(config, false);
  wasmtime_config_wasm_wide_arithmetic_set(config, false);
  wasmtime_config_wasm_custom_page_sizes_set(config, false);
  wasmtime_config_wasm_relaxed_simd_deterministic_set(config, true);
  wasmtime_config_cranelift_nan_canonicalization_set(config, true);
  // Explicit bounds checks within a 256 MiB reservation instead of 4 GiB of
  // reserved address space per instance.
  wasmtime_config_memory_reservation_set(config, 256ull * 1024 * 1024);
  wasmtime_config_memory_guard_size_set(config, 64ull * 1024);
  wasmtime_config_memory_reservation_for_growth_set(config, 0);
  // The calling thread needs more than this much stack (2 MiB is enough).
  wasmtime_config_max_wasm_stack_set(config, 1024 * 1024);
  wasmtime_config_parallel_compilation_set(config, false);
  g_engine = wasm_engine_new_with_config(config);
  pthread_t t;
  if (pthread_create(&t, NULL, ticker, NULL) == 0) {
    pthread_detach(t);
    g_ticker_ok = 1;
  }
}

static void copy_message(const wasm_byte_vec_t *msg, uint8_t *out, int32_t cap) {
  if (!out || cap <= 0) return;
  size_t n = msg->size < (size_t)(cap - 1) ? msg->size : (size_t)(cap - 1);
  memcpy(out, msg->data, n);
  out[n] = 0;
}

static void set_message(const char *text, uint8_t *out, int32_t cap) {
  wasm_byte_vec_t msg = {strlen(text), (wasm_byte_t *)text};
  copy_message(&msg, out, cap);
}

static void error_message(wasmtime_error_t *e, uint8_t *out, int32_t cap) {
  wasm_byte_vec_t msg;
  wasmtime_error_message(e, &msg);
  copy_message(&msg, out, cap);
  wasm_byte_vec_delete(&msg);
  wasmtime_error_delete(e);
}

static int trap_status(wasm_trap_t *trap, uint8_t *out, int32_t cap) {
  wasmtime_trap_code_t code;
  int status = LF_TRAP;
  if (wasmtime_trap_code(trap, &code)) {
    if (code == WASMTIME_TRAP_CODE_OUT_OF_FUEL) status = LF_OUT_OF_FUEL;
    if (code == WASMTIME_TRAP_CODE_INTERRUPT) status = LF_TIMEOUT;
  }
  wasm_message_t msg;
  wasm_trap_message(trap, &msg);
  copy_message(&msg, out, cap);
  wasm_byte_vec_delete(&msg);
  wasm_trap_delete(trap);
  return status;
}

// Compiles `wasm`. NULL and a message on failure. The caller caps the
// module before this: compilation runs outside fuel and the deadline.
wasmtime_module_t *lf_module_new(const uint8_t *wasm, int32_t len, uint8_t *msg, int32_t cap) {
  pthread_once(&g_once, engine_init);
  if (msg && cap > 0) msg[0] = 0;
  if (!g_ticker_ok) {
    set_message("no deadline thread: refusing to run guests without a deadline", msg, cap);
    return NULL;
  }
  if (len < 0) {
    set_message("negative module length", msg, cap);
    return NULL;
  }
  wasmtime_module_t *m = NULL;
  wasmtime_error_t *e = wasmtime_module_new(g_engine, wasm, (size_t)len, &m);
  if (e) {
    error_message(e, msg, cap);
    return NULL;
  }
  return m;
}

int32_t lf_module_is_null(wasmtime_module_t *m) { return m == NULL; }

void lf_module_free(wasmtime_module_t *m) {
  if (m) wasmtime_module_delete(m);
}

typedef struct lf_sandbox {
  wasmtime_store_t *store;
  wasmtime_context_t *context;
  wasmtime_instance_t instance;
} lf_sandbox_t;

// Instantiates a compiled module under the limits. Instantiation runs under
// `fuel` and `timeout_ms` (a start function is guest code too). NULL and a
// message on failure; `status` says why (LF_TRAP, LF_OUT_OF_FUEL, ...).
lf_sandbox_t *lf_sandbox_new(wasmtime_module_t *module, int64_t memory_bytes,
                             int64_t table_elements, int64_t fuel, int64_t timeout_ms,
                             int32_t *status, uint8_t *msg, int32_t cap) {
  if (msg && cap > 0) msg[0] = 0;
  *status = LF_ERROR;
  if (!module) {
    set_message("no module", msg, cap);
    return NULL;
  }
  lf_sandbox_t *s = calloc(1, sizeof(lf_sandbox_t));
  if (!s) {
    set_message("out of host memory", msg, cap);
    return NULL;
  }
  s->store = wasmtime_store_new(g_engine, NULL, NULL);
  s->context = wasmtime_store_context(s->store);
  // memory_size, table_elements, instances, tables, memories
  wasmtime_store_limiter(s->store, memory_bytes, table_elements, 1, 4, 1);
  wasmtime_context_set_fuel(s->context, (uint64_t)fuel);
  wasmtime_context_set_epoch_deadline(s->context, (uint64_t)timeout_ms);
  wasm_trap_t *trap = NULL;
  atomic_fetch_add(&g_running, 1);
  wasmtime_error_t *e = wasmtime_instance_new(s->context, module, NULL, 0, &s->instance, &trap);
  atomic_fetch_sub(&g_running, 1);
  if (e || trap) {
    if (e) error_message(e, msg, cap);
    else *status = trap_status(trap, msg, cap);
    wasmtime_store_delete(s->store);
    free(s);
    return NULL;
  }
  *status = LF_OK;
  return s;
}

int32_t lf_sandbox_is_null(lf_sandbox_t *s) { return s == NULL; }

void lf_sandbox_free(lf_sandbox_t *s) {
  if (!s) return;
  wasmtime_store_delete(s->store);
  free(s);
}

// A session: `fuel` instructions and `timeout_ms` of guest running time,
// for every call until the next session.
void lf_sandbox_session(lf_sandbox_t *s, int64_t fuel, int64_t timeout_ms) {
  wasmtime_context_set_fuel(s->context, (uint64_t)fuel);
  wasmtime_context_set_epoch_deadline(s->context, (uint64_t)timeout_ms);
}

// Fuel left in the session, or -1.
int64_t lf_sandbox_fuel(lf_sandbox_t *s) {
  uint64_t f = 0;
  wasmtime_error_t *e = wasmtime_context_get_fuel(s->context, &f);
  if (e) {
    wasmtime_error_delete(e);
    return -1;
  }
  return (int64_t)f;
}

// Calls export `name` with `nargs` i32 arguments; it must return one i32
// (wasmtime_func_call checks the arity and types).
int32_t lf_sandbox_call_i32(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                            const int32_t *args, int32_t nargs, int32_t *result,
                            uint8_t *msg, int32_t cap) {
  if (msg && cap > 0) msg[0] = 0;
  if (name_len < 0 || nargs < 0 || nargs > 8) return LF_ERROR;
  wasmtime_extern_t item;
  if (!wasmtime_instance_export_get(s->context, &s->instance, (const char *)name,
                                    (size_t)name_len, &item)) {
    return LF_NO_EXPORT;
  }
  if (item.kind != WASMTIME_EXTERN_FUNC) {
    wasmtime_extern_delete(&item);
    return LF_NO_EXPORT;
  }
  wasmtime_val_t argv[8];
  for (int i = 0; i < nargs; i++) {
    argv[i].kind = WASMTIME_I32;
    argv[i].of.i32 = args[i];
  }
  wasmtime_val_t res;
  wasm_trap_t *trap = NULL;
  atomic_fetch_add(&g_running, 1);
  wasmtime_error_t *e =
      wasmtime_func_call(s->context, &item.of.func, argv, (size_t)nargs, &res, 1, &trap);
  atomic_fetch_sub(&g_running, 1);
  wasmtime_extern_delete(&item);
  if (e) {
    error_message(e, msg, cap);
    return LF_ERROR;
  }
  if (trap) return trap_status(trap, msg, cap);
  if (res.kind != WASMTIME_I32) {
    wasmtime_val_unroot(&res);
    return LF_BAD_RESULT;
  }
  *result = res.of.i32;
  return LF_OK;
}

// Exported memory `name`'s bytes `offset..offset+len`, or NULL with *status
// LF_NO_EXPORT (no such memory) or LF_ERROR (out of bounds). Bounds-checked
// against the memory's current size; valid until the guest runs again.
static uint8_t *memory_range(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                             int32_t offset, int32_t len, int32_t *status) {
  *status = LF_ERROR;
  if (name_len < 0 || offset < 0 || len < 0) return NULL;
  wasmtime_extern_t item;
  if (!wasmtime_instance_export_get(s->context, &s->instance, (const char *)name,
                                    (size_t)name_len, &item)) {
    *status = LF_NO_EXPORT;
    return NULL;
  }
  if (item.kind != WASMTIME_EXTERN_MEMORY) {
    wasmtime_extern_delete(&item);
    *status = LF_NO_EXPORT;
    return NULL;
  }
  size_t size = wasmtime_memory_data_size(s->context, &item.of.memory);
  uint8_t *p = NULL;
  if ((size_t)offset + (size_t)len <= size) {
    p = wasmtime_memory_data(s->context, &item.of.memory) + offset;
    *status = LF_OK;
  }
  wasmtime_extern_delete(&item);
  return p;
}

// Copies `len` bytes at `offset` of exported memory `memory` into `out`
// from index `out_at` (the caller checked that they fit).
int32_t lf_sandbox_read(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                        int32_t offset, int32_t len, uint8_t *out, int32_t out_at) {
  int32_t status;
  uint8_t *p = memory_range(s, name, name_len, offset, len, &status);
  if (p) memcpy(out + out_at, p, (size_t)len);
  return status;
}

// Copies `len` bytes of `data` to `offset` of exported memory `memory`.
int32_t lf_sandbox_write(lf_sandbox_t *s, const uint8_t *name, int32_t name_len,
                         int32_t offset, const uint8_t *data, int32_t len) {
  int32_t status;
  uint8_t *p = memory_range(s, name, name_len, offset, len, &status);
  if (p) memcpy(p, data, (size_t)len);
  return status;
}
